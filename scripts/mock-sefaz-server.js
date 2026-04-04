const http = require('http');

const port = Number(process.env.SEFAZ_MOCK_PORT || 18080);

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
    if (body.includes('<vIBS>999.99</vIBS>')) {
      res.writeHead(422, { 'content-type': 'application/xml' });
      res.end('<retEnviNFe><cStat>422</cStat><xMotivo>REJEICAO_IBUT_422</xMotivo></retEnviNFe>');
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
