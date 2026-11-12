// Generates service-jwt-vectors.json: service-auth JWTs minted by the
// TypeScript reference implementation (and by other JOSE signers), each
// labelled with what the reference `verifyJwt` does with it.
//
// Usage (see README.md in this directory):
//
//   mkdir /tmp/ts-interop && cd /tmp/ts-interop
//   npm init -y && npm install @atproto/xrpc-server @atproto/crypto jose
//   NODE_PATH=$PWD/node_modules node <this file> <output.json>
//
// Run it from the directory holding node_modules (ES module resolution is
// relative to the working directory through the createRequire below).

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

const out = process.argv[2]
if (!out) throw new Error('usage: generate-ts-vectors.mjs <output.json>')

// ---------------------------------------------------------------------------
// Pinned clock. verifyJwt reads Date.now(); everything below runs at NOW.
// ---------------------------------------------------------------------------
const NOW = 1_700_000_000
Date.now = () => NOW * 1000

// ---------------------------------------------------------------------------
// Fixed test keys: SHA-256 of a label. Never used anywhere else.
// ---------------------------------------------------------------------------
const curves = { k256: secp256k1, p256 }
const keys = {}
const keypairs = {}
for (const [name, curve] of [
  ['k256', 'k256'],
  ['k256Rotated', 'k256'],
  ['p256', 'p256'],
  ['p256Rotated', 'p256'],
]) {
  const priv = nodeCrypto.createHash('sha256').update(`petrel service-auth interop vector key: ${name}`).digest()
  const keypair =
    curve === 'k256'
      ? await atcrypto.Secp256k1Keypair.import(priv, { exportable: true })
      : await atcrypto.P256Keypair.import(priv, { exportable: true })
  keypairs[name] = keypair
  keys[name] = { curve, privateKeyHex: priv.toString('hex'), didKey: keypair.did() }
}

const b64url = (value) => Buffer.from(value).toString('base64url')
const jsonB64 = (value) => b64url(typeof value === 'string' ? value : JSON.stringify(value))

const ISS = 'did:plc:abcdefghijklmnopqrstuvwx'
const AUD = 'did:web:feed.example.com'
const AUD_FRAGMENT = 'did:web:feed.example.com#bsky_fg'
const FEED_LXM = 'app.bsky.feed.getFeedSkeleton'

/** Signs header.payload with the reference keypair (low-S, compact). */
const signCompact = async (keyName, header, payload) => {
  const input = `${jsonB64(header)}.${jsonB64(payload)}`
  const sig = await keypairs[keyName].sign(Buffer.from(input, 'utf8'))
  return `${input}.${b64url(sig)}`
}

/** Rewrites a token's signature from (r, s) to (r, n - s). */
const flipS = (token, curveName) => {
  const [h, p, s] = token.split('.')
  const sig = Buffer.from(s, 'base64url')
  const n = curves[curveName].CURVE.n
  const sValue = BigInt('0x' + sig.subarray(32).toString('hex'))
  const flipped = (n - sValue).toString(16).padStart(64, '0')
  return `${h}.${p}.${b64url(Buffer.concat([sig.subarray(0, 32), Buffer.from(flipped, 'hex')]))}`
}

const isHighS = (token, curveName) => {
  const segment = token.split('.')[2]
  if (segment === undefined) return null
  const sig = Buffer.from(segment, 'base64url')
  if (sig.length !== 64) return null
  const n = curves[curveName].CURVE.n
  return BigInt('0x' + sig.subarray(32).toString('hex')) > n / 2n
}

/** Re-encodes a token's compact signature as ASN.1 DER. */
const toDER = (token, curveName) => {
  const [h, p, s] = token.split('.')
  const sig = curves[curveName].Signature.fromCompact(Buffer.from(s, 'base64url'))
  return `${h}.${p}.${b64url(sig.toDERRawBytes())}`
}

/** A node:crypto (OpenSSL) private key for one of the fixed keys. */
const opensslKey = (keyName) => {
  const { curve, privateKeyHex } = keys[keyName]
  const priv = Buffer.from(privateKeyHex, 'hex')
  const pub = Buffer.from(curves[curve].getPublicKey(priv, false))
  return nodeCrypto.createPrivateKey({
    format: 'jwk',
    key: {
      kty: 'EC',
      crv: curve === 'k256' ? 'secp256k1' : 'P-256',
      d: b64url(priv),
      x: b64url(pub.subarray(1, 33)),
      y: b64url(pub.subarray(33, 65)),
    },
  })
}

/** Signs with OpenSSL (no S normalization) until S has the wanted height. */
const signOpenSSL = (keyName, header, payload, wantHighS) => {
  const input = `${jsonB64(header)}.${jsonB64(payload)}`
  const key = opensslKey(keyName)
  for (let attempt = 0; attempt < 512; attempt++) {
    const sig = nodeCrypto.sign('sha256', Buffer.from(input, 'utf8'), { key, dsaEncoding: 'ieee-p1363' })
    const token = `${input}.${b64url(sig)}`
    if (isHighS(token, keys[keyName].curve) === wantHighS) return token
  }
  throw new Error('could not produce the wanted S height')
}

/** Signs with jose (WebCrypto), as the reference test "interoperates with jwts signed by other libraries". */
const signJose = async (keyName, header, payload, wantHighS) => {
  const key = opensslKey(keyName)
  for (let attempt = 0; attempt < 512; attempt++) {
    const token = await new jose.SignJWT(payload).setProtectedHeader(header).sign(key)
    if (isHighS(token, keys[keyName].curve) === wantHighS) return token
  }
  throw new Error('could not produce the wanted S height')
}

const vectors = []

/**
 * Records a vector and what the reference verifier does with it.
 *
 * `verifier` is what a receiving service is configured with:
 *   audience  own DID passed to verifyJwt (null skips the check)
 *   lxm       lexicon method passed to verifyJwt (null skips the check)
 *   key       name of the key the issuer's DID document currently lists
 *   refreshedKey  name of the key a forced refresh returns (default: same)
 */
const add = async ({ name, description, source, token, verifier, petrel }) => {
  const curve = keys[verifier.key].curve
  const refreshed = verifier.refreshedKey ?? verifier.key
  const calls = []
  let ts
  try {
    const payload = await xrpcServer.verifyJwt(token, verifier.audience, verifier.lxm, async (iss, forceRefresh) => {
      calls.push({ iss, forceRefresh })
      return keys[forceRefresh ? refreshed : verifier.key].didKey
    })
    ts = { ok: true, payload }
  } catch (err) {
    ts = { ok: false, error: err.customErrorName ?? err.error ?? err.name, message: err.message }
  }
  vectors.push({
    name,
    description,
    source,
    token,
    highS: isHighS(token, curve),
    verifier: { audience: verifier.audience, lxm: verifier.lxm, key: verifier.key, refreshedKey: refreshed },
    ts: { ...ts, keyLookups: calls },
    ...(petrel ? { petrel } : {}),
  })
}

const ts = (params) => xrpcServer.createServiceJwt({ iat: NOW, ...params })

// --- Tokens from createServiceJwt, both curves -----------------------------
for (const keyName of ['k256', 'p256']) {
  const keypair = keypairs[keyName]
  const curve = keys[keyName].curve

  const withLxm = await ts({ iss: ISS, aud: AUD_FRAGMENT, lxm: FEED_LXM, keypair })
  await add({
    name: `ts-${curve}-lxm`,
    description: 'createServiceJwt, 60 s, lxm bound, aud with service fragment',
    source: 'createServiceJwt',
    token: withLxm,
    verifier: { audience: AUD_FRAGMENT, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-lxm-highS`,
    description: 'the same token with S replaced by n - S; the reference verifies JWTs with allowMalleableSig',
    source: 'createServiceJwt, signature rewritten to high-S',
    token: flipS(withLxm, curve),
    verifier: { audience: AUD_FRAGMENT, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-lxm-der`,
    description: 'the same token with the signature re-encoded as ASN.1 DER; not a JWS signature (RFC 7518 3.4)',
    source: 'createServiceJwt, signature rewritten to DER',
    token: toDER(withLxm, curve),
    verifier: { audience: AUD_FRAGMENT, lxm: FEED_LXM, key: keyName },
    petrel: {
      ok: false,
      error: 'BadJwt',
      reason:
        'Petrel requires the 64-byte JWS encoding by default; DER is accepted only with signatureOptions .allowMalleable',
      okWith: 'allowMalleable',
    },
  })

  const noLxm = await ts({ iss: ISS, aud: AUD, lxm: null, keypair })
  await add({
    name: `ts-${curve}-no-lxm`,
    description: 'createServiceJwt without lxm, bare-DID aud; receiver does not check lxm',
    source: 'createServiceJwt',
    token: noLxm,
    verifier: { audience: AUD, lxm: null, key: keyName },
  })
  await add({
    name: `ts-${curve}-no-lxm-but-required`,
    description: 'the lxm-less token presented to an endpoint that requires a method binding',
    source: 'createServiceJwt',
    token: noLxm,
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })

  await add({
    name: `ts-${curve}-upload-30min`,
    description:
      'what the official app requests for video upload: lxm com.atproto.repo.uploadBlob, 30 minute lifetime',
    source: 'createServiceJwt',
    token: await ts({
      iss: ISS,
      aud: 'did:web:pds.example.com',
      lxm: 'com.atproto.repo.uploadBlob',
      exp: NOW + 30 * 60,
      keypair,
    }),
    verifier: { audience: 'did:web:pds.example.com', lxm: 'com.atproto.repo.uploadBlob', key: keyName },
  })
  await add({
    name: `ts-${curve}-1h`,
    description: 'the longest lifetime the reference PDS issues from getServiceAuth: one hour',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: AUD, lxm: FEED_LXM, exp: NOW + 60 * 60, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-2h`,
    description: 'a two hour token: longer than any reference PDS issues',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: AUD, lxm: FEED_LXM, exp: NOW + 2 * 60 * 60, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
    petrel: {
      ok: false,
      error: 'BadJwt',
      reason: 'exceeds the default one hour lifetime ceiling; accepted when the ceiling is raised',
      okWith: 'maximumLifetime=3h',
    },
  })

  await add({
    name: `ts-${curve}-expired`,
    description: 'expired one minute before the pinned clock',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: AUD, lxm: FEED_LXM, iat: NOW - 120, exp: NOW - 60, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-wrong-audience`,
    description: 'minted for another service',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: 'did:web:other.example.com', lxm: FEED_LXM, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-bare-audience-for-fragment-service`,
    description: 'bare-DID aud presented to a service that expects its DID with a service fragment',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: AUD, lxm: FEED_LXM, keypair }),
    verifier: { audience: AUD_FRAGMENT, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-wrong-lxm`,
    description: 'minted for another endpoint',
    source: 'createServiceJwt',
    token: await ts({ iss: ISS, aud: AUD, lxm: 'com.atproto.repo.createRecord', keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })

  const rotatedName = `${keyName}Rotated`
  const rotatedToken = await ts({ iss: ISS, aud: AUD, lxm: FEED_LXM, keypair: keypairs[rotatedName] })
  await add({
    name: `ts-${curve}-rotated-key`,
    description: 'signed with the new key after a rotation; the cached key fails, a forced refresh returns the new one',
    source: 'createServiceJwt',
    token: rotatedToken,
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName, refreshedKey: rotatedName },
  })
  await add({
    name: `ts-${curve}-wrong-key`,
    description: 'signed with a key the issuer never published; refresh returns the same key',
    source: 'createServiceJwt',
    token: rotatedToken,
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })

  await add({
    name: `ts-${curve}-issuer-with-service-fragment`,
    description: 'legacy issuer form did#service (pre Spring 2026), as labelers sent',
    source: 'createServiceJwt',
    token: await ts({ iss: `${ISS}#atproto_labeler`, aud: AUD, lxm: FEED_LXM, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `ts-${curve}-did-web-issuer`,
    description: 'did:web issuer',
    source: 'createServiceJwt',
    token: await ts({ iss: 'did:web:labeler.example.com', aud: AUD, lxm: FEED_LXM, keypair }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })

  // --- Other signers -------------------------------------------------------
  const alg = keypair.jwtAlg
  const fullPayload = { iat: NOW, iss: ISS, aud: AUD, exp: NOW + 60, lxm: FEED_LXM, jti: `openssl-${curve}` }
  for (const high of [false, true]) {
    await add({
      name: `openssl-${curve}-${high ? 'highS' : 'lowS'}`,
      description: `signed by node:crypto (OpenSSL), which does not normalize S; this sample is ${high ? 'high' : 'low'}-S`,
      source: 'node:crypto sign, dsaEncoding ieee-p1363',
      token: signOpenSSL(keyName, { typ: 'JWT', alg }, fullPayload, high),
      verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
    })
  }

  // --- Hand-built headers and payloads, signed with the reference keypair ---
  for (const typ of ['at+jwt', 'refresh+jwt', 'dpop+jwt']) {
    await add({
      name: `handbuilt-${curve}-typ-${typ.replace('+', '-')}`,
      description: `header typ ${typ}: a token of another kind, validly signed`,
      source: 'hand-built header, reference keypair',
      token: await signCompact(keyName, { typ, alg }, fullPayload),
      verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
    })
  }
  await add({
    name: `handbuilt-${curve}-no-typ-no-iat-no-jti`,
    description: 'only the claims the reference verifier requires: iss, aud, exp',
    source: 'hand-built payload, reference keypair',
    token: await signCompact(keyName, { alg }, { iss: ISS, aud: AUD, exp: NOW + 60 }),
    verifier: { audience: AUD, lxm: null, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-kid-atproto`,
    description: 'kid header naming the default key, as the Spring 2026 specification allows',
    source: 'hand-built header, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg, kid: '#atproto' }, fullPayload),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-kid-other`,
    description: 'kid header naming a key the receiving service does not accept',
    source: 'hand-built header, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg, kid: '#atproto_label' }, fullPayload),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
    petrel: {
      ok: false,
      error: 'BadJwt',
      reason:
        'the specification says receivers must only accept specific key ids; the reference verifier does not read kid yet',
      okWith: 'acceptedKeyIDs=#atproto_label',
    },
  })
  await add({
    name: `handbuilt-${curve}-wrong-alg-for-key`,
    description: 'header alg names the other curve',
    source: 'hand-built header, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg: alg === 'ES256' ? 'ES256K' : 'ES256' }, fullPayload),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-alg-none`,
    description: 'header alg none',
    source: 'hand-built header, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg: 'none' }, fullPayload),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-issuer-not-a-did`,
    description: 'iss is a handle',
    source: 'hand-built payload, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg }, { ...fullPayload, iss: 'alice.example.com' }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-missing-exp`,
    description: 'no exp claim',
    source: 'hand-built payload, reference keypair',
    token: await signCompact(keyName, { typ: 'JWT', alg }, { iss: ISS, aud: AUD, lxm: FEED_LXM, jti: 'x' }),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
  })
  await add({
    name: `handbuilt-${curve}-duplicate-claim`,
    description: 'payload JSON repeats aud; JSON.parse keeps the last value',
    source: 'hand-built payload, reference keypair',
    token: await signCompact(
      keyName,
      { typ: 'JWT', alg },
      `{"iat":${NOW},"iss":"${ISS}","aud":"did:web:other.example.com","aud":"${AUD}","exp":${NOW + 60},"lxm":"${FEED_LXM}","jti":"dup"}`,
    ),
    verifier: { audience: AUD, lxm: FEED_LXM, key: keyName },
    petrel: {
      ok: false,
      error: 'BadJwt',
      reason: 'Petrel rejects JSON with duplicate members instead of picking one',
    },
  })

  const tamperedParts = withLxm.split('.')
  const tamperedPayload = JSON.parse(Buffer.from(tamperedParts[1], 'base64url').toString('utf8'))
  tamperedPayload.iss = 'did:plc:zzzzzzzzzzzzzzzzzzzzzzzz'
  await add({
    name: `ts-${curve}-tampered-issuer`,
    description: 'payload rewritten to another issuer, signature kept',
    source: 'createServiceJwt, payload rewritten',
    token: `${tamperedParts[0]}.${jsonB64(tamperedPayload)}.${tamperedParts[2]}`,
    verifier: { audience: AUD_FRAGMENT, lxm: FEED_LXM, key: keyName },
  })
}

// --- jose, as in the reference test (P-256 only: jose 6 has no ES256K) ------
for (const high of [false, true]) {
  await add({
    name: `jose-p256-minimal-${high ? 'highS' : 'lowS'}`,
    description: `jose SignJWT with only aud, iss and exp, as xrpc-server auth.test.ts "interoperates with jwts signed by other libraries"; this sample is ${high ? 'high' : 'low'}-S`,
    source: 'jose SignJWT (WebCrypto)',
    token: await signJose('p256', { typ: 'JWT', alg: 'ES256' }, { aud: AUD, iss: ISS, exp: NOW + 60 }, high),
    verifier: { audience: AUD, lxm: null, key: 'p256' },
  })
}

// --- Structurally broken input ----------------------------------------------
await add({
  name: 'malformed-two-segments',
  description: 'not a compact JWS',
  source: 'literal',
  token: 'eyJhbGciOiJFUzI1NksifQ.eyJpc3MiOiJkaWQ6cGxjOmFiYyJ9',
  verifier: { audience: AUD, lxm: null, key: 'k256' },
})

const document = {
  description:
    'Service-auth JWT interop vectors. Each token was produced by the TypeScript reference implementation or another JOSE signer, and `ts` records what @atproto/xrpc-server verifyJwt did with it at the pinned clock. `petrel`, where present, documents a deliberate difference.',
  generator: {
    script: 'generate-ts-vectors.mjs',
    node: process.version,
    '@atproto/xrpc-server': version('@atproto/xrpc-server'),
    '@atproto/crypto': version('@atproto/crypto'),
    jose: version('jose'),
  },
  now: NOW,
  keys,
  vectors,
}
fs.writeFileSync(out, JSON.stringify(document, null, 2) + '\n')
const accepted = vectors.filter((v) => v.ts.ok).length
process.stdout.write(`${vectors.length} vectors (${accepted} accepted by the reference) -> ${out}\n`)
