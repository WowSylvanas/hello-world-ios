const test = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

test('Buffer resolves the same Base64 implementation as native autolinking', () => {
  const nativePackage = require.resolve('react-native-quick-base64/package.json')
  const bufferDirectory = path.dirname(require.resolve('@craftzdog/react-native-buffer/package.json'))
  const bufferPackage = require.resolve('react-native-quick-base64/package.json', { paths: [bufferDirectory] })
  assert.equal(bufferPackage, nativePackage, 'Duplicate Base64 versions produce incompatible native calls')
})
