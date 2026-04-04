const fs = require('node:fs');
const path = require('node:path');

const OUT_PATH = path.join(__dirname, '..', 'tests', 'data', 'ufs.v2026-04-01.json');
const VIGENCIA_INICIO = '2026-04-01';
const VIGENCIA_FIM = '2026-12-31';

const UFS = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
  'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
  'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
];

const CFOPS = ['6101', '6102', '6108'];

const REGIMES = [
  { nome: 'SIMPLES_NACIONAL', ibsDelta: 0, cbsDelta: 0 },
  { nome: 'LUCRO_REAL', ibsDelta: 0.75, cbsDelta: 0.25 }
];

function formatMoney(n) {
  return n.toFixed(2);
}

function buildRules() {
  const rules = [];

  UFS.forEach((uf, idx) => {
    const baseIbs = 9.5 + (idx % 7) * 0.4;
    const baseCbs = 4.5 + (idx % 5) * 0.2;
    const cfop = CFOPS[idx % CFOPS.length];

    REGIMES.forEach((regime) => {
      rules.push({
        uf,
        cfop,
        regimeTributario: regime.nome,
        vigenciaInicio: VIGENCIA_INICIO,
        vigenciaFim: VIGENCIA_FIM,
        vIBS: formatMoney(baseIbs + regime.ibsDelta),
        vCBS: formatMoney(baseCbs + regime.cbsDelta)
      });
    });
  });

  return rules;
}

function main() {
  const payload = {
    version: VIGENCIA_INICIO,
    generatedAt: new Date().toISOString(),
    totalUFs: UFS.length,
    totalRules: UFS.length * REGIMES.length,
    rules: buildRules()
  };

  fs.writeFileSync(OUT_PATH, JSON.stringify(payload, null, 2) + '\n');
  console.log('Matriz fiscal gerada em: ' + OUT_PATH);
  console.log('Total de regras: ' + payload.totalRules);
}

main();
