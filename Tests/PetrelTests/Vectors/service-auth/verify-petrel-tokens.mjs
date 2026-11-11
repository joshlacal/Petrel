// Verifies Petrel-minted service-auth JWTs with the TypeScript reference
// implementation and with an independent ECDSA library, and writes what
// each said.
//
// Usage (see README.md in this directory):
//
//   cd <directory holding node_modules with @atproto/xrpc-server, @atproto/crypto, jose>
//   node <this file> <petrel-minted-tokens.json> <output.json>
//
// Exit status is 0 only if every token verified everywhere.

import { createRequire } from 'node:module'
import nodeCrypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const require = createRequire(path.join(process.cwd(), 'noop.js'))
const load = async (name) => import(pathToFileURL(require.resolve(name)).href)
const version = (name) => {
  let dir = path.dirname(require.resolve(name))
  for (;;) {
    const candidate = path.join(dir, 'package.json')
    if (fs.existsSync(candidate)) {
      const pkg = JSON.parse(fs.readFileSync(candidate, 'utf8'))
      if (pkg.name === name) return pkg.version
    }
    const parent = path.dirname(dir)
    if (parent === dir) throw new Error(`no package.json for ${name}`)
    dir = parent
  }
}

const xrpcServer = await load('@atproto/xrpc-server')
const atcrypto = await load('@atproto/crypto')
const jose = await load('jose')
const { secp256k1 } = await load('@noble/curves/secp256k1')
const { p256 } = await load('@noble/curves/p256')

const [input, output] = process.argv.slice(2)
if (!input || !output) throw new Error('usage: verify-petrel-tokens.mjs <input.json> <output.json>')

const document = JSON.parse(fs.readFileSync(input, 'utf8'))
Date.now = () => document.now * 1000

const b64url = (value) => Buffer.from(value).toString('base64url')

/** The did:key as a node:crypto (OpenSSL) public key. */
const opensslPublicKey = (didKey) => {
  const { jwtAlg, keyBytes } = atcrypto.parseDidKey(didKey)
  const curve = jwtAlg === 'ES256K' ? secp256k1 : p256
  const point = curve.ProjectivePoint.fromHex(keyBytes).toRawBytes(false)
  return nodeCrypto.createPublicKey({
    format: 'jwk',
    key: {
      kty: 'EC',
      crv: jwtAlg === 'ES256K' ? 'secp256k1' : 'P-256',
      x: b64url(point.subarray(1, 33)),
      y: b64url(point.subarray(33, 65)),
    },
  })
}

const results = []
let failures = 0
for (const entry of document.tokens) {
  const result = { name: entry.name, token: entry.token }

  // 1. The reference verifier, configured as the receiving service.
  try {
    const lookups = []
    const payload = await xrpcServer.verifyJwt(entry.token, entry.audience, entry.lxm, async (iss, forceRefresh) => {
      lookups.push({ iss, forceRefresh })
      return entry.didKey
    })
    result.verifyJwt = { ok: true, payload, keyLookups: lookups }
  } catch (err) {
    result.verifyJwt = { ok: false, error: err.customErrorName ?? err.name, message: err.message }
  }

  // 2. Strict @atproto/crypto verification: compact encoding, low-S only.
  //    This is the rule for commits; minted tokens satisfy it too.
  const [header, payload, signature] = entry.token.split('.')
  const signingInput = Buffer.from(`${header}.${payload}`, 'utf8')
  const signatureBytes = Buffer.from(signature, 'base64url')
  const alg = JSON.parse(Buffer.from(header, 'base64url').toString('utf8')).alg
  try {
    result.strictLowS = await atcrypto.verifySignature(entry.didKey, signingInput, signatureBytes, { jwtAlg: alg })
  } catch (err) {
    result.strictLowS = false
  }

  // 3. OpenSSL through node:crypto, which shares no code with noble.
  result.openssl = nodeCrypto.verify(
    'sha256',
    signingInput,
    { key: opensslPublicKey(entry.didKey), dsaEncoding: 'ieee-p1363' },
    signatureBytes,
  )

  // 4. jose (WebCrypto) for ES256; jose 6 does not implement ES256K.
  if (alg === 'ES256') {
    try {
      await jose.jwtVerify(entry.token, opensslPublicKey(entry.didKey), {
        currentDate: new Date(document.now * 1000),
        audience: entry.audience ?? undefined,
        issuer: result.verifyJwt.payload?.iss,
      })
      result.jose = true
    } catch (err) {
      result.jose = false
      result.joseError = err.message
    }
  }

  const ok = result.verifyJwt.ok && result.strictLowS && result.openssl && result.jose !== false
  if (!ok) failures += 1
  results.push(result)
}

fs.writeFileSync(
  output,
  JSON.stringify(
    {
      description:
        'What the TypeScript reference implementation and independent ECDSA libraries said about the tokens in the input file.',
      generator: {
        script: 'verify-petrel-tokens.mjs',
        node: process.version,
        '@atproto/xrpc-server': version('@atproto/xrpc-server'),
        '@atproto/crypto': version('@atproto/crypto'),
        jose: version('jose'),
      },
      now: document.now,
      results,
    },
    null,
    2,
  ) + '\n',
)
process.stdout.write(`${results.length - failures}/${results.length} Petrel-minted tokens verified -> ${output}\n`)
process.exit(failures === 0 ? 0 : 1)
