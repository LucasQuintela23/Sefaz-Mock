# AGENTS - Sefaz-Mock

## Agente Principal (Orquestrador)
Responsabilidades:
- Receber objetivo de negocio/tecnico.
- Consultar RULES e documentacao de arquitetura.
- Quebrar trabalho em tarefas menores.
- Decidir quando usar Skills e quando delegar para subagentes.

Nao deve:
- Pular validacao de impacto fiscal.
- Ignorar riscos de regressao em calculo de imposto.

## Subagente Fiscal
Foco:
- Regras IBS/CBS, tags XML, validacoes por UF e cenarios de rejeicao.

Entradas:
- Massa de dados por UF, regra de vigencia, XML de referencia.

Saida esperada:
- Resumo tecnico com riscos, casos faltantes e sugestao de teste.

## Subagente de Testes
Foco:
- Estrategia Playwright para API/integracao.
- Paralelismo por matriz de cenarios.

Saida esperada:
- Plano de execucao e organizacao dos testes por dominio.

## Subagente de Infra
Foco:
- Kind/Kubernetes, mocks, pipeline local e CI.

Saida esperada:
- Passos de provisionamento e diagnostico de falhas de ambiente.

## Criterios de Delegacao
Delegar quando:
- A tarefa exige pesquisa ampla e consolidacao de contexto.
- Ha ambiguidade em regras de dominio.
- O custo de erro for alto (fiscal ou infraestrutura).

Nao delegar quando:
- Ajuste simples e local em um unico arquivo.
- Mudanca de baixo risco e de escopo claro.
