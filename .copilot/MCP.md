# MCP CONTRACT - Sefaz-Mock

## Objetivo
Definir como conectores externos podem ser usados de forma segura e previsivel durante automacao.

## Escopo Permitido
- Leitura de documentacao tecnica e artefatos de configuracao.
- Consulta de metadados de execucao e diagnostico de ambiente.

## Escopo Restrito
- Escrita em sistemas externos sem aprovacao explicita.
- Uso de credenciais reais de orgaos fiscais.

## Politica de Timeout e Retry
- Timeout padrao por chamada: 30s.
- Maximo de retries: 2.
- Backoff incremental para falhas transientes.

## Tratamento de Erros
- Classificar erro como: configuracao, dependencia externa, dados invalidos, timeout.
- Retornar mensagem objetiva com acao recomendada.
- Registrar contexto tecnico minimo para reproduzir falha.

## Observabilidade Minima
- Correlation id por fluxo.
- Timestamp de inicio/fim.
- Status final da chamada e motivo da falha (quando houver).
