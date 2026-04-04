# Arquitetura de Referencia - Framework IBS/CBS

## Objetivo
Validar emissao de NF-e com foco em regras da reforma tributaria (IBS/CBS), mantendo ambiente local, isolado e reproduzivel.

## Camadas
1. Orquestracao (local e CI)
- Executa bootstrap de ambiente.
- Dispara deploy de mocks/servicos.
- Inicia execucao de testes.

2. Infraestrutura (Kind/Kubernetes)
- WireMock como simulador de SEFAZ.
- ConfigMaps para regras e parametros.
- Service interno para endpoint alvo dos testes.

3. Execucao de testes (Playwright)
- Envia XML de NF-e para endpoint mockado.
- Valida sucesso/rejeicao e mensagens retornadas.
- Consolida evidencias e relatorio.

## Principios
- Determinismo: mesma entrada deve gerar mesmo resultado.
- Isolamento: sem dependencia de servico fiscal real.
- Rastreabilidade: logs e artefatos por cenario.
- Escalabilidade de teste: matriz por UF com paralelismo controlado.

## Fluxo resumido
1. Provisionar ambiente local.
2. Subir WireMock e configuracoes de regra.
3. Executar matriz de testes fiscais.
4. Publicar artefatos e relatorio.
