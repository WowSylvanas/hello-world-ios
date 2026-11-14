const crypto = require('node:crypto')
const fs = require('node:fs')
const plain = 'Hello, iPhone! 你好'
const key = Buffer.from('0123456789abcdef')
const iv = Buffer.from('abcdef0123456789')
const encrypt = (algorithm, value, noPadding = false) => {
  const cipher = crypto.createCipheriv(algorithm, key, algorithm.includes('cbc') ? iv : null)
  cipher.setAutoPadding(!noPadding)
  return Buffer.concat([cipher.update(value), cipher.final()]).toString('base64')
}
const pair = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'der' },
  privateKeyEncoding: { type: 'pkcs8', format: 'der' },
})
const publicKey = crypto.createPublicKey({ key: pair.publicKey, format: 'der', type: 'spki' })
const rawInput = Buffer.alloc(256)
Buffer.from(plain).copy(rawInput, 256 - Buffer.byteLength(plain))
fs.mkdirSync('build', { recursive: true })
fs.writeFileSync('build/crypto-vectors.json', JSON.stringify({
  plain, input: Buffer.from(plain).toString('base64'), key: key.toString('base64'), iv: iv.toString('base64'),
  cbc: encrypt('aes-128-cbc', plain), ecb: encrypt('aes-128-ecb', plain),
  rawInput: key.toString('base64'), ecbRaw: encrypt('aes-128-ecb', key, true),
  publicKey: pair.publicKey.toString('base64'), privateKey: pair.privateKey.toString('base64'),
  rsa: crypto.publicEncrypt({ key: publicKey, oaepHash: 'sha1' }, Buffer.from(plain)).toString('base64'),
  rsaRaw: crypto.publicEncrypt({ key: publicKey, padding: crypto.constants.RSA_NO_PADDING }, rawInput).toString('base64'),
  md5: crypto.createHash('md5').update(plain).digest('hex'), sha1: crypto.createHash('sha1').update(plain).digest('hex'),
}))
