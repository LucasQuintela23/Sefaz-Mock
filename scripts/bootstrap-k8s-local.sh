#!/usr/bin/env bash
set -euo pipefail

# Script de bootstrap completo: clusters Kind + Terraform + WireMock + Playwright

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
ALLURE_AUTO_OPEN="${ALLURE_AUTO_OPEN:-true}"
CLUSTER_NAME="${CLUSTER_NAME:-sefaz-mock}"
NAMESPACE="${NAMESPACE:-sefaz-mock}"
WIREMOCK_PORT="${WIREMOCK_PORT:-18080}"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
ACTION="${1:-up}"
LOGS_PID=""

log_info() {
  echo "[bootstrap] $*"
}

log_error() {
  echo "[bootstrap] ERROR: $*" >&2
}

log_success() {
  echo "[bootstrap] ✓ $*"
}

# Verifica pré-requisitos
check_requirements() {
  local missing=0
  local cmd_path
  
  for cmd in kind kubectl terraform npm; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Comando '$cmd' não encontrado. Instale antes de continuar."
      missing=1
      continue
    fi

    cmd_path="$(command -v "$cmd")"
    if [ ! -x "$cmd_path" ]; then
      log_info "Ajustando permissão de execução para '$cmd' em $cmd_path..."
      if ! chmod +x "$cmd_path" 2>/dev/null; then
        log_error "Sem permissão para executar '$cmd' em $cmd_path. Rode: chmod +x $cmd_path"
        missing=1
      fi
    fi
  done
  
  if [ $missing -eq 1 ]; then
    exit 1
  fi
  
  log_success "Pré-requisitos OK"
}

# Cria cluster Kind se não existir
create_kind_cluster() {
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    log_info "Cluster Kind '${CLUSTER_NAME}' já existe."
    return
  fi
  
  log_info "Criando cluster Kind '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --kubeconfig="${KUBECONFIG}"
  log_success "Cluster Kind '${CLUSTER_NAME}' criado"
}

# Gera dados e mappings do WireMock
generate_test_data() {
  log_info "Gerando matriz de dados e mappings do WireMock..."
  cd "$ROOT_DIR"
  npm run matrix:generate >/dev/null
  npm run wiremock:mappings:generate >/dev/null
  log_success "Dados e mappings gerados"
}

# Inicializa e aplica Terraform
apply_terraform() {
  log_info "Inicializando Terraform..."
  cd "$ROOT_DIR/infra/terraform"
  
  terraform init
  
  log_info "Aplicando recursos Kubernetes..."
  terraform apply -auto-approve \
    -var="kubeconfig_path=${KUBECONFIG}" \
    -var="namespace=${NAMESPACE}" \
    -var="mappings_dir=../../mocks/mappings"
  
  log_success "Recursos Kubernetes provisionados"
}

# Aguarda readiness do WireMock
wait_for_wiremock() {
  log_info "Aguardando WireMock estar ready..."
  for i in {1..120}; do
    if kubectl -n "${NAMESPACE}" wait --for=condition=available deploy/wiremock --timeout=1s 2>/dev/null; then
      log_success "WireMock ready em $i segundos"
      return
    fi
    sleep 1
  done
  
  log_error "WireMock não ficou ready em 120 segundos"
  exit 1
}

# Inicia port-forward
start_port_forward() {
  log_info "Iniciando port-forward para ${WIREMOCK_PORT}:8080..."
  
  # Mata port-forward existente e libera a porta
  pkill -f "kubectl.*port-forward.*${WIREMOCK_PORT}" 2>/dev/null || true
  # Garante que a porta está liberada no SO
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${WIREMOCK_PORT}/tcp" 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    local port_pid
    port_pid=$(lsof -ti tcp:"${WIREMOCK_PORT}" 2>/dev/null) && kill "$port_pid" 2>/dev/null || true
  fi
  sleep 1
  
  kubectl -n "${NAMESPACE}" port-forward svc/wiremock "${WIREMOCK_PORT}:8080" &
  PORT_FORWARD_PID=$!
  
  # Aguarda port-forward ficar pronto
  for i in {1..30}; do
    if curl -fsS "http://127.0.0.1:${WIREMOCK_PORT}/__admin/health" >/dev/null 2>&1; then
      log_success "Port-forward ativo em 127.0.0.1:${WIREMOCK_PORT}"
      echo "$PORT_FORWARD_PID" > "$ROOT_DIR/.port-forward.pid"
      return
    fi
    sleep 1
  done
  
  log_error "Port-forward não respondeu em 30 segundos"
  kill "$PORT_FORWARD_PID" 2>/dev/null || true
  exit 1
}

# Executa testes Playwright
run_tests() {
  log_info "Executando testes Playwright..."
  cd "$ROOT_DIR"
  
  export SEFAZ_API_URL="http://127.0.0.1:${WIREMOCK_PORT}"
  export TEST_UFS="${TEST_UFS:-SP,RJ}"
  export TEST_REGIMES="${TEST_REGIMES:-SIMPLES_NACIONAL}"
  export ALLURE_RESULTS_DIR="${ALLURE_RESULTS_DIR:-$ROOT_DIR/allure-results}"

  if [ -n "${TESTS_LOG_FILE:-}" ]; then
    npx playwright test 2>&1 | tee "$TESTS_LOG_FILE"
  else
    npx playwright test
  fi
  
  log_success "Testes concluído"
}

# Mostra logs do WireMock
show_logs() {
  log_info "Logs do WireMock (últimas 50 linhas):"
  local attempt
  for attempt in 1 2 3; do
    if kubectl -n "${NAMESPACE}" logs -f deploy/wiremock --tail=50; then
      return 0
    fi
    log_info "Falha ao executar kubectl logs (tentativa ${attempt}/3). Repetindo..."
    sleep 1
  done

  log_error "Nao foi possivel executar kubectl logs."
  log_error "Tente reinstalar o kubectl:"
  log_error "  curl -fsSL https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl -o ~/.local/bin/kubectl.new && chmod +x ~/.local/bin/kubectl.new && mv -f ~/.local/bin/kubectl.new ~/.local/bin/kubectl"
  return 1
}

generate_allure_report() {
  local allure_results_dir="$1"
  local allure_report_dir="$2"
  local allure_index="$allure_report_dir/index.html"

  if ! command -v npx >/dev/null 2>&1; then
    log_error "npx não encontrado. Não foi possível gerar relatório Allure."
    return 1
  fi

  if [ ! -d "$allure_results_dir" ]; then
    log_error "Diretório de resultados Allure não encontrado: $allure_results_dir"
    return 1
  fi

  log_info "Gerando dashboard Allure..."
  npx allure generate "$allure_results_dir" --clean -o "$allure_report_dir" >/dev/null
  log_success "Dashboard Allure gerado em: $allure_report_dir"

  if [ "$ALLURE_AUTO_OPEN" = "true" ] && command -v xdg-open >/dev/null 2>&1; then
    log_info "Abrindo dashboard Allure no navegador..."
    xdg-open "$allure_index" >/dev/null 2>&1 || true
  fi
}

run_all() {
  LOGS_PID=""
  local run_id
  run_id="$(date +%Y%m%d-%H%M%S)"
  local run_log_dir="$LOG_DIR/$run_id"
  local all_log_file="$run_log_dir/all.log"
  local wiremock_log_file="$run_log_dir/wiremock.log"
  local tests_log_file="$run_log_dir/tests.log"
  local allure_results_dir="$run_log_dir/allure-results"
  local allure_report_dir="$run_log_dir/allure-report"

  mkdir -p "$run_log_dir"
  log_info "Salvando logs desta execucao em: $run_log_dir"

  # Captura toda saida do bootstrap all no arquivo all.log e mantém no terminal.
  exec > >(tee -a "$all_log_file") 2>&1

  check_requirements
  create_kind_cluster
  generate_test_data
  apply_terraform
  wait_for_wiremock
  start_port_forward

  log_info "Iniciando stream de logs do WireMock em background..."
  kubectl -n "${NAMESPACE}" logs -f deploy/wiremock --tail=200 2>&1 | tee "$wiremock_log_file" &
  LOGS_PID=$!

  export TESTS_LOG_FILE="$tests_log_file"
  export ALLURE_RESULTS_DIR="$allure_results_dir"

  cleanup_all() {
    if [ -n "${LOGS_PID}" ] && kill -0 "${LOGS_PID}" 2>/dev/null; then
      kill "${LOGS_PID}" 2>/dev/null || true
    fi
  }
  trap cleanup_all EXIT

  run_tests
  generate_allure_report "$allure_results_dir" "$allure_report_dir"
  cleanup_all
  trap - EXIT

  log_success "Fluxo all concluido (ambiente mantido ativo)."
  log_info "Use 'bash scripts/bootstrap-k8s-local.sh down' para destruir a infraestrutura."
  log_info "Relatorios gerados:"
  log_info "  - $all_log_file"
  log_info "  - $wiremock_log_file"
  log_info "  - $tests_log_file"
  log_info "  - $allure_report_dir/index.html"
}

# Destrui infraestrutura
destroy_infrastructure() {
  log_info "Destruindo infraestrutura..."
  
  # Para port-forward
  if [ -f "$ROOT_DIR/.port-forward.pid" ]; then
    PID=$(cat "$ROOT_DIR/.port-forward.pid")
    kill "$PID" 2>/dev/null || true
    rm "$ROOT_DIR/.port-forward.pid"
  fi
  
  # Destroy Terraform
  cd "$ROOT_DIR/infra/terraform"
  terraform destroy -auto-approve \
    -var="kubeconfig_path=${KUBECONFIG}" \
    -var="namespace=${NAMESPACE}" \
    -var="mappings_dir=../../mocks/mappings"
  
  log_success "Infraestrutura destruída"
}

# Main function
main() {
  case "${ACTION}" in
    up)
      log_info "=== BOOTSTRAP UP ==="
      check_requirements
      create_kind_cluster
      generate_test_data
      apply_terraform
      wait_for_wiremock
      start_port_forward
      log_success "Ambiente pronto! WireMock em http://127.0.0.1:${WIREMOCK_PORT}"
      log_info "Para rodar testes em outro terminal: bash scripts/bootstrap-k8s-local.sh test"
      log_info "Para ver logs: bash scripts/bootstrap-k8s-local.sh logs"
      ;;
    test)
      run_tests
      ;;
    logs)
      show_logs
      ;;
    all)
      log_info "=== BOOTSTRAP ALL ==="
      run_all
      ;;
    down)
      log_info "=== BOOTSTRAP DOWN ==="
      destroy_infrastructure
      ;;
    *)
      cat << 'HELP'
Uso: bash scripts/bootstrap-k8s-local.sh [comando]

Comandos:
  up    - Cria cluster, provisiona infra e aguarda WireMock (padrão)
  test  - Executa testes Playwright contra WireMock já subido
  logs  - Exibe logs da stream do WireMock
  all   - Executa up + logs + testes + dashboard Allure em um unico comando
  down  - Destrui infraestrutura (keep cluster Kind)

Exemplo ponta a ponta:
  1. bash scripts/bootstrap-k8s-local.sh up
  2. (em outro terminal) bash scripts/bootstrap-k8s-local.sh test
  3. bash scripts/bootstrap-k8s-local.sh logs (opcional, em outro terminal)
  4. bash scripts/bootstrap-k8s-local.sh down
HELP
      exit 1
      ;;
  esac
}

main
