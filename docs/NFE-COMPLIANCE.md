# Guia de Compliance Fiscal (Projeto)

## Premissas
- Este repositorio simula validacoes fiscais para testes.
- Nao substitui validacoes legais oficiais.
- Regras devem ser versionadas por vigencia.

## Estrutura de regra (referencia)
- UF destino.
- Data de vigencia.
- Aliquota esperada (IBS/CBS).
- Condicoes adicionais (quando aplicavel).

## Criterios minimos de validacao
- Tag de UF destino presente.
- Valores monetarios em formato valido.
- Consistencia entre calculo esperado e valor informado.
- Resposta de rejeicao com codigo e mensagem explicita em caso de divergencia.

## Politica de mudanca
- Toda alteracao de regra deve indicar motivo e vigencia.
- Toda alteracao de regra exige atualizacao de testes relacionados.
