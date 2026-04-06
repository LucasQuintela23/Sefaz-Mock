// Configuracao inicial de testes de API para o piloto fiscal.
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/integration',
  timeout: 30_000,
  fullyParallel: true,
  reporter: [
    ['list'],
    ['html', { open: 'never' }],
    ['allure-playwright', { resultsDir: process.env.ALLURE_RESULTS_DIR || 'allure-results' }]
  ],
  use: {
    baseURL: process.env.SEFAZ_API_URL || 'http://localhost:8080',
    extraHTTPHeaders: {
      'content-type': 'application/xml'
    }
  }
});
