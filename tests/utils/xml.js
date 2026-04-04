function buildNfeXml({ uf = 'SP', cfop = '6101', dhEmi = '2026-04-01', vIBS = '10.00', vCBS = '5.00' } = {}) {
  return [
    '<NFe>',
    '  <infNFe>',
    '    <ide>',
    '      <CFOP>' + cfop + '</CFOP>',
    '      <dhEmi>' + dhEmi + '</dhEmi>',
    '    </ide>',
    '    <dest><UF>' + uf + '</UF></dest>',
    '    <imposto>',
    '      <IBSCBS>',
    '        <vIBS>' + vIBS + '</vIBS>',
    '        <vCBS>' + vCBS + '</vCBS>',
    '      </IBSCBS>',
    '    </imposto>',
    '  </infNFe>',
    '</NFe>'
  ].join('');
}

module.exports = {
  buildNfeXml
};
