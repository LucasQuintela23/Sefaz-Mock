const fs = require('node:fs');
const path = require('node:path');

const matrixPath = process.env.UF_MATRIX_PATH || path.join(__dirname, '..', 'tests', 'data', 'ufs.json');
const outputDir = process.env.BATCH_SUMMARY_DIR || path.join(__dirname, '..', 'artifacts');
const batchName = process.env.BATCH_NAME || 'local';
const testUfsRaw = process.env.TEST_UFS || '';
const testRegimesRaw = process.env.TEST_REGIMES || '';

function parseCsv(raw) {
  if (!raw) {
    return null;
  }
  const list = raw
    .split(',')
    .map((item) => item.trim().toUpperCase())
    .filter(Boolean);
  return list.length ? new Set(list) : null;
}

function unique(list) {
  return [...new Set(list)];
}

function main() {
  const matrix = JSON.parse(fs.readFileSync(matrixPath, 'utf8'));
  const ufFilter = parseCsv(testUfsRaw);
  const regimeFilter = parseCsv(testRegimesRaw);

  const rules = matrix.rules.filter((rule) => {
    const ufOk = !ufFilter || ufFilter.has(rule.uf.toUpperCase());
    const regimeOk = !regimeFilter || regimeFilter.has(rule.regimeTributario.toUpperCase());
    return ufOk && regimeOk;
  });

  const ufs = unique(rules.map((rule) => rule.uf));
  const regimes = unique(rules.map((rule) => rule.regimeTributario));
  const cfops = unique(rules.map((rule) => rule.cfop));

  const summary = {
    batchName,
    generatedAt: new Date().toISOString(),
    matrixVersion: matrix.version,
    totalRulesInMatrix: matrix.totalRules || matrix.rules.length,
    filters: {
      testUfs: testUfsRaw || null,
      testRegimes: testRegimesRaw || null
    },
    selected: {
      ruleCount: rules.length,
      ufCount: ufs.length,
      regimeCount: regimes.length,
      cfopCount: cfops.length,
      expectedTests: rules.length * 3,
      ufs,
      regimes,
      cfops
    }
  };

  fs.mkdirSync(outputDir, { recursive: true });

  const jsonOut = path.join(outputDir, `batch-summary-${batchName}.json`);
  const mdOut = path.join(outputDir, `batch-summary-${batchName}.md`);

  fs.writeFileSync(jsonOut, JSON.stringify(summary, null, 2) + '\n');

  const md = [
    '# Batch Summary',
    '',
    `- Batch: ${summary.batchName}`,
    `- Generated at: ${summary.generatedAt}`,
    `- Matrix version: ${summary.matrixVersion}`,
    `- Selected rules: ${summary.selected.ruleCount}`,
    `- Expected tests (3 per rule): ${summary.selected.expectedTests}`,
    `- UFs (${summary.selected.ufCount}): ${summary.selected.ufs.join(', ')}`,
    `- Regimes (${summary.selected.regimeCount}): ${summary.selected.regimes.join(', ')}`,
    `- CFOPs (${summary.selected.cfopCount}): ${summary.selected.cfops.join(', ')}`,
    '',
    '## Filters',
    '',
    `- TEST_UFS: ${summary.filters.testUfs || 'ALL'}`,
    `- TEST_REGIMES: ${summary.filters.testRegimes || 'ALL'}`,
    ''
  ].join('\n');

  fs.writeFileSync(mdOut, md);

  console.log('Batch summary generated:');
  console.log('- ' + jsonOut);
  console.log('- ' + mdOut);
}

main();
