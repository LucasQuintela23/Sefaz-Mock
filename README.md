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

1. Instalar dependencias:
	npm install
2. Rodar smoke sem Docker (recomendado para ambiente local simples):
	npm run test:smoke:local

Fluxo opcional com WireMock via Docker:
1. Subir WireMock:
	docker compose up -d wiremock
2. Rodar smoke:
	npm run test:smoke
3. Derrubar ambiente:
	docker compose down

## Matriz fiscal piloto (Sprint B)

- Arquivo versionado: `tests/data/ufs.v2026-04-01.json`
- UFs cobertas no piloto: SP e RJ
- Cenarios automatizados:
	- autorizacao com IBS/CBS aderente a regra por UF
	- rejeicao 422 quando IBS diverge da regra esperada
