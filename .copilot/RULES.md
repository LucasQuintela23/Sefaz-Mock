# RULES - Sefaz-Mock

## 1) Objetivo
Garantir que toda automacao de codigo, testes e infraestrutura siga o contexto fiscal do projeto (NF-e com foco em IBS/CBS), com rastreabilidade, seguranca e previsibilidade.

## 2) Regras Globais
- Priorizar alteracoes pequenas, testaveis e reversiveis.
- Sempre preservar o comportamento fiscal esperado antes de otimizar performance.
- Todo fluxo novo deve produzir evidencia minima: input, output e resultado da validacao.
- Nao conectar em servicos reais da SEFAZ neste repositorio.
- Defaults de execucao devem ser locais e de baixo custo.

## 3) Politica de Contexto
- Contexto sempre presente: arquitetura alvo, convencoes fiscais e limites de seguranca.
- Contexto sob demanda: detalhes por UF, regras por CFOP, comportamento de mocks especificos.

## 4) Politica de Qualidade
- Toda regra fiscal relevante precisa de teste de sucesso e de rejeicao.
- Evitar acoplamento entre calculo fiscal e camada de transporte HTTP.
- Falhas devem retornar mensagem objetiva para diagnostico.

## 5) Politica de Delegacao
- O agente principal orquestra e decide prioridade.
- Subagentes executam tarefas especializadas e retornam resumo objetivo.
- Skills executam no contexto principal quando o custo de delegacao for maior que o ganho.

## 6) Seguranca
- Nao registrar segredos em arquivos de teste ou logs.
- Sanitizar dados sensiveis em evidencias.
- Bloquear comandos destrutivos sem necessidade explicita.

## 7) Definition of Done (DoD)
- Estrutura criada ou atualizada.
- Testes ou plano de teste definido para a mudanca.
- Evidencias de validacao descritas.
- Documentacao atualizada quando houver impacto arquitetural.
