# Test Data

Matriz de dados fiscais por UF.

Conteudo esperado:
- Arquivos por UF com regra de vigencia.
- Casos positivos e negativos.
- Metadados de rastreabilidade da regra usada.

Automacao atual:
- Arquivo unico de dados gerado por script: `ufs.json`.
- Gerador: `scripts/generate-uf-matrix.js`.
- Comando: `npm run matrix:generate`.
