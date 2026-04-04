const { test, expect } = require('@playwright/test');
const { buildNfeXml } = require('../utils/xml');

test.describe('NF-e piloto IBS/CBS', () => {
  test('deve retornar autorizado para payload valido', async ({ request, baseURL }) => {
    const xml = buildNfeXml({ uf: 'SP', vIBS: '10.00', vCBS: '5.00' });

    const response = await request.post(baseURL + '/sefaz/autorizar', {
      data: xml,
      headers: { 'content-type': 'application/xml' }
    });

    expect([200, 201]).toContain(response.status());

    const body = await response.text();
    expect(body).toContain('AUTORIZADO');
  });

  test('deve retornar rejeicao quando valor IBS divergir', async ({ request, baseURL }) => {
    const xml = buildNfeXml({ uf: 'SP', vIBS: '999.99', vCBS: '5.00' });

    const response = await request.post(baseURL + '/sefaz/autorizar', {
      data: xml,
      headers: { 'content-type': 'application/xml' }
    });

    expect(response.status()).toBe(422);

    const body = await response.text();
    expect(body).toContain('REJEICAO_IBUT_422');
  });
});
