# Infra

Infraestrutura como Código para provisionar ambiente local de testes (Kind + WireMock + Kubernetes).

## Estrutura

- `terraform/` - Declaração de recursos Kubernetes via Terraform
  - `main.tf` - Provider, Namespace, ConfigMap, Deployment e Service
  - `variables.tf` - Variáveis de entrada (kubeconfig, namespace, wiremock_image, mappings_dir)
  - `outputs.tf` - Outputs úteis (FQDN, próximos passos)

## Quick Start

### Pré-requisitos
- `kind` (Kubernetes em Docker) instalado
- `kubectl` instalado e configurado
- `terraform` >= 1.5.0 instalado
- `npm` para gerar dados de teste

### Provisionar ambiente Kubernetes + WireMock
```bash
cd /home/quintela/projetos/osf-pocs/Sefaz-Mock

# Uma única linha:
bash scripts/bootstrap-k8s-local.sh up
```

Isso automaticamente:
1. Cria cluster Kind
2. Gera matriz e mappings
3. Executa Terraform (namespace, configmap, deployment, service)
4. Aguarda WireMock ficar ready
5. Inicia port-forward para 127.0.0.1:18080

### Rodar testes contra WireMock no Kubernetes
```bash
# Em outro terminal:
cd /home/quintela/projetos/osf-pocs/Sefaz-Mock
bash scripts/bootstrap-k8s-local.sh test
```

### Ver logs do WireMock
```bash
bash scripts/bootstrap-k8s-local.sh logs
```

### Destruir infraestrutura (manter cluster Kind)
```bash
bash scripts/bootstrap-k8s-local.sh down
```

## Fluxo completo manual (para referência)
```bash
# 1. Criar cluster Kind
kind create cluster --name sefaz-mock

# 2. Gerar dados
npm run matrix:generate
npm run wiremock:mappings:generate

# 3. Provisionar com Terraform
cd infra/terraform
terraform init
terraform apply -auto-approve \
  -var="kubeconfig_path=$HOME/.kube/config" \
  -var="namespace=sefaz-mock" \
  -var="mappings_dir=../../mocks/mappings"

# 4. Aguardar readiness
kubectl -n sefaz-mock wait --for=condition=available deploy/wiremock --timeout=120s

# 5. Port-forward
kubectl -n sefaz-mock port-forward svc/wiremock 18080:8080 &

# 6. Testes
SEFAZ_API_URL=http://127.0.0.1:18080 npx playwright test

# 7. Cleanup
terraform destroy -auto-approve
# (cluster Kind fica vivo para reutilizar)
```

## Variáveis Terraform

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `kubeconfig_path` | Caminho para kubeconfig local | `~/.kube/config` |
| `namespace` | Namespace Kubernetes | `sefaz-mock` |
| `wiremock_image` | Imagem Docker do WireMock | `wiremock/wiremock:3.10.0` |
| `mappings_dir` | Diretório com mapeamentos JSON | `../../mocks/mappings` |

## Troubleshooting

### WireMock não fica ready
```bash
# Ver logs detalhados
kubectl -n sefaz-mock logs deploy/wiremock

# Descrever pod
kubectl -n sefaz-mock describe pod -l app=wiremock

# Testar saúde manualmente
kubectl -n sefaz-mock port-forward svc/wiremock 18080:8080
curl -v http://127.0.0.1:18080/__admin/health
```

### Port-forward não funciona
```bash
# Matar processo hanging
pkill -f "kubectl.*port-forward.*18080"

# Tentar novamente
kubectl -n sefaz-mock port-forward svc/wiremock 18080:8080
```

### Resetar cluster
```bash
kind delete cluster --name sefaz-mock
kind create cluster --name sefaz-mock
```

## Estado do Terraform

O estado fica em `infra/terraform/terraform.tfstate`. Para ambientes multi-dev, considere usar:
```bash
terraform backend "local" {
  path = "terraform.tfstate.local"
}
```
