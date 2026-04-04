function buildNfeXml({ uf = 'SP', vIBS = '10.00', vCBS = '5.00' } = {}) {
  return [
    '<NFe>',
    '  <infNFe>',
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
