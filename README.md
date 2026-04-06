# Sefaz-Mock

Framework tecnico para automacao de testes de NF-e com foco na reforma tributaria (IBS/CBS), usando Playwright, WireMock e Kubernetes local.

## Objetivo

Garantir validacao deterministica de regras fiscais por UF em ambiente local e reproduzivel, com base em:
- testes de integracao orientados a dados,
- simulacao de comportamento de SEFAZ via WireMock,
- execucao rastreavel em fluxo local e CI/CD.

## Stack alvo

- Playwright (JS) para testes
- WireMock para mocks e validacao de request/response
- Kind/Kubernetes para ambiente local isolado
- Terraform para provisionamento de infraestrutura
- GitHub Actions para pipeline de automacao

## Governanca de IA (Copilot)

A governanca foi implementada em pasta dedicada:

- `.copilot/RULES.md`: regras globais de qualidade, seguranca e delegacao
- `.copilot/AGENTS.md`: papeis do agente principal e subagentes
- `.copilot/SKILLS.md`: catalogo de skills por dominio
- `.copilot/MCP.md`: contrato de uso de conectores e limites operacionais

## Estrutura inicial do repositorio

```text
.
├── .copilot/
│   ├── AGENTS.md
│   ├── MCP.md
│   ├── RULES.md
│   └── SKILLS.md
├── .github/
│   └── workflows/
│       └── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── NFE-COMPLIANCE.md
│   └── TESTING-STRATEGY.md
├── infra/
│   └── README.md
├── mocks/
│   └── README.md
└── tests/
	├── data/
	│   └── README.md
	├── integration/
	│   └── README.md
	└── utils/
		└── README.md
```

## Proximo marco tecnico

1. Criar esqueleto de projeto Node.js para Playwright.
2. Materializar primeiros stubs WireMock (autorizado e rejeitado).
3. Implementar matriz piloto para 1-2 UFs.
4. Fechar primeiro fluxo ponta a ponta com evidencia de execucao.

## Execucao rapida

Fluxo principal recomendado: Kubernetes local com Terraform (Sprint C).

Para ambiente reproduzivel com Kubernetes local (Kind) e provisionamento declarativo:

1. Instalar dependencias:
	npm install
2. Executar o fluxo completo em um comando:
	bash scripts/bootstrap-k8s-local.sh all

Esse fluxo automaticamente:
- Cria/valida cluster Kind
- Gera dados de teste
- Provisiona namespace, configmap, deployment e service via Terraform
- Aguarda WireMock estar ready
- Inicia port-forward para 127.0.0.1:18080
- Exibe logs do WireMock durante a execução
- Executa todos os testes Playwright
- Gera o relatório final no Allure Report
- Abre o relatório no navegador

Fluxo manual por etapas:
1. Subir ambiente:
	bash scripts/bootstrap-k8s-local.sh up
2. Rodar testes:
	bash scripts/bootstrap-k8s-local.sh test
3. Ver logs:
	bash scripts/bootstrap-k8s-local.sh logs
4. Encerrar:
	bash scripts/bootstrap-k8s-local.sh down

Alternativa via npm scripts:
	npm run k8s:up
	npm run test:k8s
	npm run k8s:logs
	npm run k8s:down
	npm run k8s:all

Para detalhes completos, ver [infra/README.md](infra/README.md).

## Matriz fiscal piloto (Sprint B)

- Arquivo de matriz: `tests/data/ufs.json`
- Matriz expandida: 27 UFs x 2 regimes tributarios (54 regras)
- Regimes cobertos: SIMPLES_NACIONAL e LUCRO_REAL
- CFOP utilizados: 6101, 6102 e 6108
- Vigencia: 2026-04-01 ate 2026-12-31
- Cenarios automatizados:
	- autorizacao com IBS/CBS aderente a regra por UF + CFOP + data
	- rejeicao 422 quando IBS diverge da regra esperada
	- rejeicao 422 quando data de emissao estiver fora da vigencia da regra

Geracao automatica da matriz (sem manutencao manual):
1. Executar:
	npm run matrix:generate
2. Arquivo gerado:
	tests/data/ufs.json
