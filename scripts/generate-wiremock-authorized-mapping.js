const fs = require('node:fs');
const path = require('node:path');

const outputPath = path.join(__dirname, '..', 'mocks', 'mappings', 'nfe-authorized.json');

function main() {
  const mapping = {
    name: 'nfe-authorized',
    priority: 20,
    request: {
      method: 'POST',
      urlPath: '/sefaz/autorizar'
    },
    response: {
      status: 200,
      headers: {
        'Content-Type': 'application/xml'
      },
      body: '<retEnviNFe><cStat>100</cStat><xMotivo>AUTORIZADO</xMotivo></retEnviNFe>'
    }
  };

  fs.writeFileSync(outputPath, JSON.stringify(mapping, null, 2) + '\n');
  console.log('WireMock mapping generated: ' + outputPath);
}

main();
