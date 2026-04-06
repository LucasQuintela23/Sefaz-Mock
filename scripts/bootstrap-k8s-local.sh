#!/usr/bin/env bash
set -euo pipefail

# Script de bootstrap completo: clusters Kind + Terraform + WireMock + Playwright

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
ALLURE_AUTO_OPEN="${ALLURE_AUTO_OPEN:-true}"
CHROME_CMD="${CHROME_CMD:-google-chrome}"
ALLURE_SERVER_PORT="${ALLURE_SERVER_PORT:-5252}"
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
  cd "$ROOT_DIR/infra/terraform"

  if [ "${FORCE_TERRAFORM_INIT:-false}" = "true" ] || [ ! -d ".terraform/providers" ]; then
    log_info "Inicializando Terraform..."
    terraform init
  else
    log_info "Terraform ja inicializado localmente. Pulando init. Use FORCE_TERRAFORM_INIT=true para forcar reinit."
  fi
  
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
  # Sem filtros por padrão: executa todos os casos da matriz.
  export TEST_UFS="${TEST_UFS:-}"
  export TEST_REGIMES="${TEST_REGIMES:-}"

  # Permite usar ALL como alias para "sem filtro".
  if [ "${TEST_UFS}" = "ALL" ]; then
    TEST_UFS=""
  fi
  if [ "${TEST_REGIMES}" = "ALL" ]; then
    TEST_REGIMES=""
  fi

  if [ -n "${TEST_UFS}" ]; then
    log_info "Filtro ativo TEST_UFS=${TEST_UFS}"
  else
    log_info "Filtro ativo TEST_UFS=ALL"
  fi

  if [ -n "${TEST_REGIMES}" ]; then
    log_info "Filtro ativo TEST_REGIMES=${TEST_REGIMES}"
  else
    log_info "Filtro ativo TEST_REGIMES=ALL"
  fi

  export ALLURE_RESULTS_DIR="${ALLURE_RESULTS_DIR:-$ROOT_DIR/allure-results}"

  if [ -n "${TESTS_LOG_FILE:-}" ]; then
    npx playwright test 2>&1 | tee "$TESTS_LOG_FILE"
  else
    npx playwright test
  fi
  
  log_success "Testes concluído"
}

prepare_allure_template() {
  local allure_results_dir="$1"

  mkdir -p "$allure_results_dir"

  cat > "$allure_results_dir/categories.json" << 'EOF'
[
  {
    "name": "Regra fiscal nao encontrada",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*REJEICAO_REGRA_NAO_ENCONTRADA.*"
  },
  {
    "name": "Divergencia de IBS/CBS",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*REJEICAO_IBUT_422.*"
  }
]
EOF

  cat > "$allure_results_dir/environment.properties" << EOF
Ambiente=Local Kubernetes (Kind)
Namespace=${NAMESPACE}
WireMock URL=http://127.0.0.1:${WIREMOCK_PORT}
Projeto=SEFAZ Mock
EOF

  cat > "$allure_results_dir/executor.json" << EOF
{
  "name": "Bootstrap Local",
  "type": "local",
  "buildName": "Execucao local",
  "buildUrl": "http://127.0.0.1:${ALLURE_SERVER_PORT}/index.html",
  "reportName": "SEFAZ Mock - Allure Report"
}
EOF
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
  customize_allure_report_ui "$allure_report_dir"
  log_success "Dashboard Allure gerado em: $allure_report_dir"

  if [ "$ALLURE_AUTO_OPEN" = "true" ]; then
    local report_url
    local server_port="${ALLURE_SERVER_PORT}"
    report_url="http://127.0.0.1:${server_port}/index.html"

    # Allure não carrega corretamente via file:// em alguns navegadores.
    # Sobe um servidor HTTP local para garantir carregamento dos dados.
    if command -v fuser >/dev/null 2>&1; then
      fuser -k "${server_port}/tcp" 2>/dev/null || true
    fi

    if command -v python3 >/dev/null 2>&1; then
      python3 -m http.server "${server_port}" --bind 127.0.0.1 --directory "$allure_report_dir" >/dev/null 2>&1 &
      sleep 1
      log_info "Dashboard Allure servido em: ${report_url}"
    else
      log_info "python3 não encontrado; tentando abrir arquivo local (pode ficar em loading)."
      report_url="$allure_index"
    fi

    # Forca abertura no Chrome para evitar abrir em apps associadas ao xdg-open (ex: Bruno).
    local chrome_exec=""

    if command -v "${CHROME_CMD}" >/dev/null 2>&1; then
      chrome_exec="${CHROME_CMD}"
    else
      for candidate in google-chrome google-chrome-stable chromium-browser chromium; do
        if command -v "$candidate" >/dev/null 2>&1; then
          chrome_exec="$candidate"
          break
        fi
      done
    fi

    if [ -n "$chrome_exec" ]; then
      log_info "Abrindo dashboard Allure no Google Chrome..."
      "$chrome_exec" "$report_url" >/dev/null 2>&1 || true
    elif command -v xdg-open >/dev/null 2>&1; then
      log_info "Chrome não encontrado. Abrindo com xdg-open..."
      xdg-open "$report_url" >/dev/null 2>&1 || true
    else
      log_info "Não foi possível abrir automaticamente. Acesse: $report_url"
    fi
  fi
}

customize_allure_report_ui() {
  local allure_report_dir="$1"
  local allure_index="$allure_report_dir/index.html"
  local custom_js="$allure_report_dir/copilot-duration-widget.js"
  local custom_css="$allure_report_dir/copilot-duration-widget.css"

  cat > "$custom_css" << 'EOF'
.copilot-duration-trend {
  padding: 16px 18px 20px;
  font-family: Arial, sans-serif;
}

.copilot-duration-trend__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}

.copilot-duration-trend__stat {
  border: 1px solid #e6e6e6;
  border-radius: 8px;
  padding: 10px 12px;
  background: #fafafa;
}

.copilot-duration-trend__label {
  font-size: 11px;
  color: #777;
  text-transform: uppercase;
}

.copilot-duration-trend__value {
  font-size: 24px;
  line-height: 1.2;
  color: #222;
  margin-top: 6px;
}

.copilot-duration-trend__chart {
  border: 1px solid #e6e6e6;
  border-radius: 8px;
  padding: 10px;
  background: #fff;
  position: relative;
}

.copilot-duration-trend__svg {
  width: 100%;
  height: 220px;
  display: block;
  cursor: crosshair;
}

.copilot-duration-trend__axis-label {
  font-size: 12px;
  color: #666;
}

.copilot-duration-trend__top {
  margin-top: 14px;
}

.copilot-duration-trend__top-title {
  font-size: 12px;
  color: #555;
  margin-bottom: 8px;
  text-transform: uppercase;
}

.copilot-duration-trend__top-item {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 4px 0;
  border-bottom: 1px dashed #eee;
}

.copilot-duration-trend__top-name {
  font-size: 12px;
  color: #333;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.copilot-duration-trend__top-time {
  font-size: 12px;
  color: #222;
  min-width: 52px;
  text-align: right;
}

.copilot-duration-trend__hint {
  margin-top: 14px;
  font-size: 12px;
  color: #666;
}

.copilot-duration-trend__tooltip {
  position: absolute;
  z-index: 8;
  min-width: 240px;
  max-width: 320px;
  background: rgba(28, 33, 39, 0.94);
  color: #fff;
  border-radius: 8px;
  padding: 8px 10px;
  box-shadow: 0 8px 22px rgba(0, 0, 0, 0.22);
  pointer-events: none;
  display: none;
}

.copilot-duration-trend__tooltip-title {
  font-size: 12px;
  line-height: 1.35;
  margin-bottom: 4px;
}

.copilot-duration-trend__tooltip-meta {
  font-size: 11px;
  color: #b9ffcf;
}

@media (max-width: 1200px) {
  .copilot-duration-trend__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
EOF

  cat > "$custom_js" << 'EOF'
(function () {
  function normalize(value) {
    return (value || '').replace(/\s+/g, ' ').trim().toUpperCase();
  }

  function formatMs(value) {
    return value >= 1000 ? (value / 1000).toFixed(2) + 's' : Math.round(value) + 'ms';
  }

  function percentile(values, fraction) {
    if (!values.length) {
      return 0;
    }

    var sorted = values.slice().sort(function (left, right) {
      return left - right;
    });
    var index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(sorted.length * fraction) - 1));
    return sorted[index];
  }

  function findTrendCard() {
    var elements = Array.prototype.slice.call(document.querySelectorAll('div, span, h1, h2, h3, h4, h5'));
    var trendTitle = elements.find(function (element) {
      return normalize(element.textContent) === 'TREND';
    });

    if (!trendTitle) {
      return null;
    }

    var current = trendTitle;
    for (var depth = 0; current && depth < 8; depth += 1) {
      if ((current.innerText || '').indexOf('There is nothing to show') !== -1) {
        return current;
      }
      current = current.parentElement;
    }

    return trendTitle.parentElement || null;
  }

  function clearPlaceholder(card) {
    var nodes = Array.prototype.slice.call(card.querySelectorAll('*'));
    nodes.forEach(function (node) {
      if (normalize(node.textContent) === 'THERE IS NOTHING TO SHOW') {
        node.style.display = 'none';
      }
    });
  }

  function render(card, results) {
    if (!card || card.querySelector('.copilot-duration-trend')) {
      return;
    }

    clearPlaceholder(card);

    var durations = results.map(function (item) {
      return item.time && typeof item.time.duration === 'number' ? item.time.duration : 0;
    });

    var totalDuration = durations.reduce(function (sum, value) {
      return sum + value;
    }, 0);
    var average = durations.length ? totalDuration / durations.length : 0;
    var max = durations.length ? Math.max.apply(null, durations) : 0;
    var ordered = results
      .slice()
      .sort(function (left, right) {
        return (left.time.start || 0) - (right.time.start || 0);
      });

    var slowest = results
      .slice()
      .sort(function (left, right) {
        return (right.time.duration || 0) - (left.time.duration || 0);
      })
      .slice(0, 5);

    var container = document.createElement('div');
    container.className = 'copilot-duration-trend';

    var stats = document.createElement('div');
    stats.className = 'copilot-duration-trend__stats';

    [
      { label: 'Tempo total', value: formatMs(totalDuration) },
      { label: 'Media por teste', value: formatMs(average) },
      { label: 'P95', value: formatMs(percentile(durations, 0.95)) },
      { label: 'Mais lento', value: formatMs(max) }
    ].forEach(function (item) {
      var stat = document.createElement('div');
      stat.className = 'copilot-duration-trend__stat';

      var label = document.createElement('div');
      label.className = 'copilot-duration-trend__label';
      label.textContent = item.label;

      var value = document.createElement('div');
      value.className = 'copilot-duration-trend__value';
      value.textContent = item.value;

      stat.appendChild(label);
      stat.appendChild(value);
      stats.appendChild(stat);
    });

    var chart = document.createElement('div');
    chart.className = 'copilot-duration-trend__chart';

    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 760 220');
    svg.setAttribute('class', 'copilot-duration-trend__svg');

    var yMax = max > 0 ? max : 1;
    var leftPad = 44;
    var rightPad = 14;
    var topPad = 14;
    var bottomPad = 26;
    var chartWidth = 760 - leftPad - rightPad;
    var chartHeight = 220 - topPad - bottomPad;

    var baseline = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    baseline.setAttribute('x1', String(leftPad));
    baseline.setAttribute('y1', String(topPad + chartHeight));
    baseline.setAttribute('x2', String(leftPad + chartWidth));
    baseline.setAttribute('y2', String(topPad + chartHeight));
    baseline.setAttribute('stroke', '#d9d9d9');
    baseline.setAttribute('stroke-width', '1');
    svg.appendChild(baseline);

    var midline = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    midline.setAttribute('x1', String(leftPad));
    midline.setAttribute('y1', String(topPad + chartHeight / 2));
    midline.setAttribute('x2', String(leftPad + chartWidth));
    midline.setAttribute('y2', String(topPad + chartHeight / 2));
    midline.setAttribute('stroke', '#efefef');
    midline.setAttribute('stroke-width', '1');
    svg.appendChild(midline);

    var points = ordered.map(function (item, index) {
      var x = leftPad + (ordered.length > 1 ? (index / (ordered.length - 1)) * chartWidth : chartWidth / 2);
      var y = topPad + chartHeight - ((item.time.duration || 0) / yMax) * chartHeight;
      return {
        x: x,
        y: y,
        index: index,
        duration: item.time.duration || 0,
        name: item.name,
        uid: item.uid || ''
      };
    });

    var polyline = document.createElementNS('http://www.w3.org/2000/svg', 'polyline');
    polyline.setAttribute('fill', 'none');
    polyline.setAttribute('stroke', '#2f8f57');
    polyline.setAttribute('stroke-width', '2');
    polyline.setAttribute(
      'points',
      points
        .map(function (point) {
          return point.x.toFixed(1) + ',' + point.y.toFixed(1);
        })
        .join(' ')
    );
    svg.appendChild(polyline);

    points.forEach(function (point, index) {
      if (index % Math.ceil(points.length / 18) !== 0 && index !== points.length - 1) {
        return;
      }

      var dot = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      dot.setAttribute('cx', point.x.toFixed(1));
      dot.setAttribute('cy', point.y.toFixed(1));
      dot.setAttribute('r', '2.8');
      dot.setAttribute('fill', '#7ecb5a');
      svg.appendChild(dot);
    });

    var maxLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    maxLabel.setAttribute('x', '8');
    maxLabel.setAttribute('y', String(topPad + 4));
    maxLabel.setAttribute('font-size', '11');
    maxLabel.setAttribute('fill', '#666');
    maxLabel.textContent = formatMs(max);
    svg.appendChild(maxLabel);

    var avgLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    avgLabel.setAttribute('x', '8');
    avgLabel.setAttribute('y', String(topPad + chartHeight / 2 + 4));
    avgLabel.setAttribute('font-size', '11');
    avgLabel.setAttribute('fill', '#666');
    avgLabel.textContent = formatMs(average);
    svg.appendChild(avgLabel);

    var minLabel = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    minLabel.setAttribute('x', '8');
    minLabel.setAttribute('y', String(topPad + chartHeight + 4));
    minLabel.setAttribute('font-size', '11');
    minLabel.setAttribute('fill', '#666');
    minLabel.textContent = '0ms';
    svg.appendChild(minLabel);

    chart.appendChild(svg);

    var tooltip = document.createElement('div');
    tooltip.className = 'copilot-duration-trend__tooltip';
    chart.appendChild(tooltip);

    function showTooltip(point, clientX, clientY) {
      if (!point) {
        return;
      }

      tooltip.innerHTML =
        '<div class="copilot-duration-trend__tooltip-title">' +
        point.name +
        '</div>' +
        '<div class="copilot-duration-trend__tooltip-meta">Tempo: ' +
        formatMs(point.duration) +
        ' | Teste #' +
        (point.index + 1) +
        '</div>';

      tooltip.style.display = 'block';

      var rect = chart.getBoundingClientRect();
      var left = clientX - rect.left + 12;
      var top = clientY - rect.top - 12;

      if (left + 320 > rect.width) {
        left = rect.width - 330;
      }
      if (top < 8) {
        top = 8;
      }

      tooltip.style.left = left + 'px';
      tooltip.style.top = top + 'px';
    }

    function hideTooltip() {
      tooltip.style.display = 'none';
    }

    function nearestPointByClientX(clientX) {
      var rect = svg.getBoundingClientRect();
      var relativeX = ((clientX - rect.left) / rect.width) * 760;
      var nearest = null;
      var nearestDistance = Number.POSITIVE_INFINITY;

      points.forEach(function (point) {
        var distance = Math.abs(point.x - relativeX);
        if (distance < nearestDistance) {
          nearest = point;
          nearestDistance = distance;
        }
      });

      return nearest;
    }

    function openTestDetails(point) {
      if (!point || !point.uid) {
        return;
      }

      window.location.href = 'index.html#testresult/' + point.uid;
    }

    svg.addEventListener('mousemove', function (event) {
      var point = nearestPointByClientX(event.clientX);
      showTooltip(point, event.clientX, event.clientY);
    });

    svg.addEventListener('mouseleave', function () {
      hideTooltip();
    });

    svg.addEventListener('click', function (event) {
      var point = nearestPointByClientX(event.clientX);
      openTestDetails(point);
    });

    var axisLabel = document.createElement('div');
    axisLabel.className = 'copilot-duration-trend__axis-label';
    axisLabel.textContent = 'Linha temporal por ordem de execução dos testes';
    chart.appendChild(axisLabel);

    var topList = document.createElement('div');
    topList.className = 'copilot-duration-trend__top';

    var topTitle = document.createElement('div');
    topTitle.className = 'copilot-duration-trend__top-title';
    topTitle.textContent = 'Testes mais lentos';
    topList.appendChild(topTitle);

    slowest.forEach(function (item) {
      var topItem = document.createElement('div');
      topItem.className = 'copilot-duration-trend__top-item';

      var topName = document.createElement('div');
      topName.className = 'copilot-duration-trend__top-name';
      topName.title = item.name;
      topName.textContent = item.name;

      var topTime = document.createElement('div');
      topTime.className = 'copilot-duration-trend__top-time';
      topTime.textContent = formatMs(item.time.duration || 0);

      topItem.appendChild(topName);
      topItem.appendChild(topTime);
      topList.appendChild(topItem);
    });

    var hint = document.createElement('div');
    hint.className = 'copilot-duration-trend__hint';
    hint.textContent = 'Passe o mouse para ver o teste e clique no ponto para abrir os detalhes do log no Allure.';

    container.appendChild(stats);
    container.appendChild(chart);
    container.appendChild(topList);
    container.appendChild(hint);
    card.appendChild(container);
  }

  function mount() {
    fetch('widgets/duration.json')
      .then(function (response) {
        return response.json();
      })
      .then(function (results) {
        if (!Array.isArray(results) || !results.length) {
          return;
        }

        var card = findTrendCard();
        if (!card) {
          return;
        }

        render(card, results);
      })
      .catch(function () {
        return undefined;
      });
  }

  function boot() {
    mount();
    setTimeout(mount, 500);
    setTimeout(mount, 1500);
    setTimeout(mount, 3000);

    if (typeof MutationObserver !== 'undefined') {
      var observer = new MutationObserver(function () {
        mount();
      });
      observer.observe(document.body, { childList: true, subtree: true });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
EOF

  if ! grep -q 'copilot-duration-widget.css' "$allure_index"; then
    perl -0pi -e 's#</head>#    <link rel="stylesheet" type="text/css" href="copilot-duration-widget.css">\n</head>#' "$allure_index"
  fi

  if ! grep -q 'copilot-duration-widget.js' "$allure_index"; then
    perl -0pi -e 's#</body>#    <script src="copilot-duration-widget.js"></script>\n</body>#' "$allure_index"
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

  mkdir -p "$run_log_dir" "$allure_results_dir"
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
  prepare_allure_template "$allure_results_dir"

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
  log_info "  - http://127.0.0.1:${ALLURE_SERVER_PORT}/index.html"
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
