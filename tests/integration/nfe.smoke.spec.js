const { test, expect } = require('@playwright/test');
const { buildNfeXml } = require('../utils/xml');
const ufMatrix = require('../data/ufs.json');

function parseFilterList(value) {
  if (!value) {
    return null;
  }
  const items = value
    .split(',')
    .map((item) => item.trim().toUpperCase())
    .filter(Boolean);
  return items.length ? new Set(items) : null;
}

const ufFilter = parseFilterList(process.env.TEST_UFS);
const regimeFilter = parseFilterList(process.env.TEST_REGIMES);

const filteredRules = ufMatrix.rules.filter((rule) => {
  const ufOk = !ufFilter || ufFilter.has(rule.uf.toUpperCase());
  const regimeOk = !regimeFilter || regimeFilter.has(rule.regimeTributario.toUpperCase());
  return ufOk && regimeOk;
});

if (!filteredRules.length) {
  throw new Error('Nenhuma regra encontrada para os filtros informados (TEST_UFS/TEST_REGIMES).');
}

test.describe('NF-e piloto IBS/CBS', () => {
  for (const rule of filteredRules) {
    test(
      'deve autorizar payload valido para UF ' +
        rule.uf +
        ' CFOP ' +
        rule.cfop +
        ' regime ' +
        rule.regimeTributario,
      async ({ request, baseURL }) => {
      const xml = buildNfeXml({
        uf: rule.uf,
        cfop: rule.cfop,
        dhEmi: rule.vigenciaInicio,
        regimeTributario: rule.regimeTributario,
        vIBS: rule.vIBS,
        vCBS: rule.vCBS
      });

      const response = await request.post(baseURL + '/sefaz/autorizar', {
        data: xml,
        headers: { 'content-type': 'application/xml' }
      });

      expect([200, 201]).toContain(response.status());

      const body = await response.text();
      expect(body).toContain('AUTORIZADO');
      }
    );

    test(
      'deve rejeitar quando IBS divergir para UF ' +
        rule.uf +
        ' CFOP ' +
        rule.cfop +
        ' regime ' +
        rule.regimeTributario,
      async ({ request, baseURL }) => {
      const xml = buildNfeXml({
        uf: rule.uf,
        cfop: rule.cfop,
        dhEmi: rule.vigenciaInicio,
        regimeTributario: rule.regimeTributario,
        vIBS: '999.99',
        vCBS: rule.vCBS
      });

      const response = await request.post(baseURL + '/sefaz/autorizar', {
        data: xml,
        headers: { 'content-type': 'application/xml' }
      });

      expect(response.status()).toBe(422);

      const body = await response.text();
      expect(body).toContain('REJEICAO_IBUT_422');
      expect(body).toContain('<uf>' + rule.uf + '</uf>');
      expect(body).toContain('<cfop>' + rule.cfop + '</cfop>');
      expect(body).toContain('<regimeTributario>' + rule.regimeTributario + '</regimeTributario>');
      }
    );

    test(
      'deve rejeitar quando data estiver fora da vigencia para UF ' +
        rule.uf +
        ' CFOP ' +
        rule.cfop +
        ' regime ' +
        rule.regimeTributario,
      async ({ request, baseURL }) => {
      const xml = buildNfeXml({
        uf: rule.uf,
        cfop: rule.cfop,
        dhEmi: '2027-01-01',
        regimeTributario: rule.regimeTributario,
        vIBS: rule.vIBS,
        vCBS: rule.vCBS
      });

      const response = await request.post(baseURL + '/sefaz/autorizar', {
        data: xml,
        headers: { 'content-type': 'application/xml' }
      });

      expect(response.status()).toBe(422);

      const body = await response.text();
      expect(body).toContain('REJEICAO_REGRA_NAO_ENCONTRADA');
      expect(body).toContain('<uf>' + rule.uf + '</uf>');
      expect(body).toContain('<cfop>' + rule.cfop + '</cfop>');
      expect(body).toContain('<regimeTributario>' + rule.regimeTributario + '</regimeTributario>');
      }
    );
  }
});
