# Setup Kubernetes - Status de Instalação

## ✓ Ferramentas Instaladas

As seguintes ferramentas foram instaladas em `~/.local/bin`:
- ✓ `kind` - Kubernetes em Docker (v0.20.0)
- ✓ `kubectl` - CLI do Kubernetes (v1.28.0)
- ⏳ `terraform` - IaC (v1.6.0) - em progresso

## Próximo Passo

Para garantir que as ferramentas sejam encontradas, adicione ao seu `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Depois recarregue o shell:
```bash
source ~/.zshrc
```

## Verificar Instalação

```bash
kind version
kubectl version --client --short
terraform version
```

Se alguma ferramenta não for encontrada, instale manualmente:

### Se kubectl não estiver em ~/.local/bin:
```bash
curl -sL https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl -o ~/.local/bin/kubectl
chmod +x ~/.local/bin/kubectl
```

### Se terraform não estiver em ~/.local/bin:
```bash
cd /tmp
curl -sL https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip -o tf.zip
unzip tf.zip
mv terraform ~/.local/bin/
rm tf.zip
chmod +x ~/.local/bin/terraform
```

## Rodar Bootstrap

Depois de adicionar o PATH, rode:

```bash
cd /home/quintela/projetos/osf-pocs/Sefaz-Mock
bash scripts/bootstrap-k8s-local.sh up
```

Ou via npm:
```bash
npm run k8s:up
```

## Troubleshooting

Se ainda tiver erro de "comando não encontrado":

1. Abra novo terminal (para ler o ~/.zshrc atualizado)
2. Verifique o PATH:
   ```bash
   echo $PATH | grep local/bin
   ```
3. Se ~/.local/bin não aparecer, execute manualmente antes de rodar bootstrap:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   bash scripts/bootstrap-k8s-local.sh up
   ```

## Suporte

Para mais detalhes sobre Kubernetes no projeto:
- [infra/README.md](../infra/README.md)
- [docs/SPRINT-C.md](../docs/SPRINT-C.md)
