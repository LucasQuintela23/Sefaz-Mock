# Sprint C - Kubernetes & Terraform Provisionamento

## Objetivo
Evoluir de Docker Compose local para provisioning declarativo no Kubernetes (Kind), usando Terraform como IaC, de forma reproduzível e escalável.

## Implementação

### 1. Terraform - Kubernetes Resources
- **main.tf**: Provider, Namespace, ConfigMap (mapeamentos), Deployment (WireMock), Service (ClusterIP)
- **variables.tf**: Entrada de kubeconfig, namespace, wiremock_image, mappings_dir
- **outputs.tf**: Namespace, service DNS, deployment name, next steps

Recursos provisionados:
- Namespace `sefaz-mock` para isolamento
- ConfigMap carregando mapeamentos JSON automaticamente
- Deployment de WireMock com probes de readiness
- Service ClusterIP expondo porta 8080

### 2. Script de Orquestração
- **scripts/bootstrap-k8s-local.sh** com 4 modos de operação:
  - `up`: Criar cluster + gerar dados + Terraform apply + port-forward
  - `test`: Rodar Playwright contra WireMock já provisionado
  - `logs`: Stream logs do WireMock
  - `down`: Terraform destroy (manter cluster Kind)

### 3. Integração npm
Novos scripts adicionados ao `package.json`:
- `npm run k8s:up` → `bash scripts/bootstrap-k8s-local.sh up`
- `npm run test:k8s` → `bash scripts/bootstrap-k8s-local.sh test`
- `npm run k8s:logs` → `bash scripts/bootstrap-k8s-local.sh logs`
- `npm run k8s:down` → `bash scripts/bootstrap-k8s-local.sh down`

### 4. Documentação
- [infra/README.md](../infra/README.md) - Guia completo de infraestrutura
- [README.md](../README.md) - Seção de fluxo Kubernetes integrada

## Features

### Determinismo
- ConfigMap carrega mapeamentos versionados
- Mesma entrada (UF, CFOP, regime) → sempre mesmo resultado
- Port-forward determinístico em 127.0.0.1:18080

### Escalabilidade
- Fácil de adaptar para Kind (local), minikube, ou clusters reais
- Terraform reutilizável com mínimas mudanças de provider
- Namespace isolado facilita múltiplos ambientes

### Observabilidade
- Readiness probe no Deployment monitora saúde
- Logs via `kubectl logs` integrados ao bootstrap
- Output de Terraform exibe next steps automáticos

## Fluxo de Uso

Modo "tudo junto" em um livro de receita:
```bash
# Terminal 1
bash scripts/bootstrap-k8s-local.sh up

# Terminal 2
bash scripts/bootstrap-k8s-local.sh test

# Terminal 3 (optional)
bash scripts/bootstrap-k8s-local.sh logs

# Terminal 1 (after tests)
bash scripts/bootstrap-k8s-local.sh down
```

## Pré-requisitos para usar

- `kind` ≥ 0.20.0
- `kubectl` ≥ 1.28
- `terraform` ≥ 1.5.0
- `npm` ≥ 18.x

## Benefícios vs Docker Compose

| Aspecto | Docker Compose | Kubernetes |
|---------|----------------|-----------|
| Portabilidade | Linux/Mac/Win | Qualquer cluster K8s |
| IaC | Não (imperatif) | Sim (declarativo) |
| Health/Readiness | Básico | Nativo (probes) |
| Isolamento | Container apenas | Namespace + RBAC |
| Scaling | Manual | Horizontal automático |
| Observabilidade | Docker logs | kubectl + etcd history |

## Integração CI/CD (futura)

Essa estrutura permite fácil integração em GitHub Actions:
1. Setup Kind no runner
2. Realizar Terraform apply (já com kubeconfig auto)
3. Rodar `npm test:k8s` contra WireMock no pod
4. Coletar artefatos (reports, logs) via kubectl
5. Terraform destroy para cleanup

## Próximos passos opcionais

1. **Terraform Backend**: Usar `s3` ou `azurerm` para estado compartilhado em equipe
2. **Helm Chart**: Empacotar recursos Terraform em um chart reutilizável
3. **ArgoCD**: Gitops para sincronizar aplicação com repositório
4. **Monitoring**: Prometheus + Grafana pour métriques de WireMock
5. **Multi-cluster**: Estender para ambientes staging/prod autênticos

## Validação

- [x] Terraform plan retorna zero erros
- [x] Deployment fica ready em <60s
- [x] Port-forward estável em 127.0.0.1:18080
- [x] Playwright conecta e executa contra WireMock no pod
- [x] Logs capturados via kubectl
- [x] Cleanup via terraform destroy não deixa resíduos
