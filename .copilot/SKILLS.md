# SKILLS - Sefaz-Mock

## Skill: fiscal-validation
Quando usar:
- Validar consistencia de tags XML fiscais.
- Comparar regra de aliquota por UF com resultado calculado.

Entrada minima:
- UF destino, versao da regra, valores esperados (IBS/CBS), payload XML.

Saida minima:
- Resultado (ok/rejeitado), motivo, evidencia tecnica.

## Skill: playwright-integration
Quando usar:
- Criar ou ajustar testes de API/integracao.
- Organizar matriz por UF e particionamento de execucao.

Saida minima:
- Caso de teste, assertions e fixture de dados.

## Skill: wiremock-scenarios
Quando usar:
- Definir stubs e regras dinamicas de validacao.
- Simular autorizacao, rejeicao e indisponibilidade.

Saida minima:
- Mapeamento de request/response com codigo de retorno coerente.

## Skill: local-infra-bootstrap
Quando usar:
- Levantar ambiente local em Kind/Kubernetes.
- Preparar mocks e servicos para execucao dos testes.

Saida minima:
- Checklist de bootstrap e comando de verificacao.

## Skill: ci-pipeline-guardrails
Quando usar:
- Ajustar pipeline para Build -> Deploy -> Test -> Report.
- Garantir evidencias e artefatos minimos na execucao.

Saida minima:
- Etapas da pipeline e criterio de falha por etapa.
