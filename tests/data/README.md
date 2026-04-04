# Test Data

Matriz de dados fiscais por UF.

Conteudo esperado:
- Arquivos por UF com regra de vigencia.
- Casos positivos e negativos.
- Metadados de rastreabilidade da regra usada.

Automacao atual:
- Matriz principal gerada por script: `ufs.v2026-04-01.json`.
- Gerador: `scripts/generate-uf-matrix.js`.
- Comando: `npm run matrix:generate`.
