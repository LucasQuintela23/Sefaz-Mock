# Estrategia de Testes

## Escopo inicial
- Validacao de regras IBS/CBS por UF.
- Cenarios de sucesso (autorizado) e rejeicao (422).
- Cenarios minimos de instabilidade simulada.

## Tipos de teste
- Integracao API: envio de XML e assert de resposta.
- Contrato mock: request esperado vs response configurada.
- Regressao de calculo: comparacao de valores esperados por matriz de dados.

## Particionamento recomendado
- Por UF (26 + DF).
- Por familia de regra (aliquota, base de calculo, rejeicao).

## Evidencias obrigatorias
- XML de entrada (mascarado quando necessario).
- Resposta retornada pelo mock.
- Resultado de assertions.
- Sumario de execucao por lote.
