const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.env.SEFAZ_MOCK_PORT || 18080);
const matrixPath = process.env.UF_MATRIX_PATH || path.join(__dirname, '..', 'tests', 'data', 'ufs.v2026-04-01.json');
const ufMatrix = JSON.parse(fs.readFileSync(matrixPath, 'utf8'));

function extractTag(xml, tag) {
  const match = xml.match(new RegExp('<' + tag + '>([^<]+)</' + tag + '>'));
  return match ? match[1] : null;
}

function findRuleByUf(uf) {
  return ufMatrix.rules.find((rule) => rule.uf === uf);
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  if (req.method !== 'POST' || req.url !== '/sefaz/autorizar') {
    res.writeHead(404, { 'content-type': 'application/xml' });
    res.end('<error>NOT_FOUND</error>');
    return;
  }

  let body = '';
  req.on('data', (chunk) => {
    body += chunk.toString();
  });

  req.on('end', () => {
    const uf = extractTag(body, 'UF');
    const vIBS = extractTag(body, 'vIBS');
    const vCBS = extractTag(body, 'vCBS');
    const rule = findRuleByUf(uf);

    if (!uf || !vIBS || !vCBS) {
      res.writeHead(422, { 'content-type': 'application/xml' });
      res.end('<retEnviNFe><cStat>422</cStat><xMotivo>REJEICAO_XML_INVALIDO</xMotivo></retEnviNFe>');
      return;
    }

    if (!rule) {
      res.writeHead(422, { 'content-type': 'application/xml' });
      res.end('<retEnviNFe><cStat>422</cStat><xMotivo>REJEICAO_UF_NAO_MAPEADA</xMotivo><uf>' + uf + '</uf></retEnviNFe>');
      return;
    }

    if (vIBS !== rule.vIBS || vCBS !== rule.vCBS) {
      res.writeHead(422, { 'content-type': 'application/xml' });
      res.end(
        '<retEnviNFe><cStat>422</cStat><xMotivo>REJEICAO_IBUT_422</xMotivo><uf>' +
          uf +
          '</uf><esperadoIBS>' +
          rule.vIBS +
          '</esperadoIBS><informadoIBS>' +
          vIBS +
          '</informadoIBS></retEnviNFe>'
      );
      return;
    }

    res.writeHead(200, { 'content-type': 'application/xml' });
    res.end('<retEnviNFe><cStat>100</cStat><xMotivo>AUTORIZADO</xMotivo></retEnviNFe>');
  });
});

server.listen(port, () => {
  // Log simples para facilitar troubleshooting em CI/local.
  console.log('SEFAZ mock server listening on port ' + port);
});
