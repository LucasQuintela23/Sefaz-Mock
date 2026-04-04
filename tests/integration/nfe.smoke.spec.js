const { test, expect } = require('@playwright/test');
const { buildNfeXml } = require('../utils/xml');
const ufMatrix = require('../data/ufs.v2026-04-01.json');

test.describe('NF-e piloto IBS/CBS', () => {
  for (const rule of ufMatrix.rules) {
    test('deve autorizar payload valido para UF ' + rule.uf, async ({ request, baseURL }) => {
      const xml = buildNfeXml({ uf: rule.uf, vIBS: rule.vIBS, vCBS: rule.vCBS });

      const response = await request.post(baseURL + '/sefaz/autorizar', {
        data: xml,
        headers: { 'content-type': 'application/xml' }
      });

      expect([200, 201]).toContain(response.status());

      const body = await response.text();
      expect(body).toContain('AUTORIZADO');
    });

    test('deve rejeitar quando IBS divergir para UF ' + rule.uf, async ({ request, baseURL }) => {
      const xml = buildNfeXml({ uf: rule.uf, vIBS: '999.99', vCBS: rule.vCBS });

      const response = await request.post(baseURL + '/sefaz/autorizar', {
        data: xml,
        headers: { 'content-type': 'application/xml' }
      });

      expect(response.status()).toBe(422);

      const body = await response.text();
      expect(body).toContain('REJEICAO_IBUT_422');
      expect(body).toContain('<uf>' + rule.uf + '</uf>');
    });
  }
});
