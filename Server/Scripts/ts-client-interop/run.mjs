// Drives the reference TypeScript OAuth client (@atproto/oauth-client-node)
// against petrel-oauth-server-example, with no browser: the Authorization
// Interface forms are submitted with plain HTTP requests.
//
// For each client it performs:
//   discovery -> PAR -> sign-in -> consent -> callback (iss + state check)
//   -> code exchange -> DPoP resource request -> forced refresh
//   -> resource request -> revocation -> proof the session is dead
//
// Usage:
//   node run.mjs                                   build and start the example, run, stop it
//   node run.mjs --server-bin <path>               same, with an already built binary
//   node run.mjs --prepare <dir>                   only write the confidential client's key + metadata
//   node run.mjs --origin <url> --client-dir <dir> run against a server that is already listening and
//                                                  has <dir>/client-metadata.json registered
//   --discovery                                    with --origin: instead of the registered confidential
//                                                  client, run the clients the server must discover over
//                                                  https (the documents in <dir>/discovery/, served by the
//                                                  caller at https://ts-interop.example.test/)
//   --commit <id>                                  record the commit under test in the transcript
//   --log <file>                                   also write the transcript to a file
//
// Clients: a public http://localhost development client; then either a
// pre-registered confidential private_key_jwt client (inline jwks), or, with
// --discovery, a discoverable public https client and a discoverable
// confidential client whose keys are at its jwks_uri.

import { spawn } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync, appendFileSync } from 'node:fs'
import { createServer } from 'node:http'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { JoseKey } from '@atproto/jwk-jose'
import { NodeOAuthClient, atprotoLoopbackClientMetadata } from '@atproto/oauth-client-node'

const here = dirname(fileURLToPath(import.meta.url))
const DEMO_DID = 'did:plc:petrelexampledemoaccount'
const DEMO_HANDLE = 'demo.test'
const DEMO_PASSWORD = 'petrel-demo'
const SCOPE = 'atproto transition:generic'
const CONFIDENTIAL_CLIENT_ID = 'https://ts-interop.example.test/client-metadata.json'
const CONFIDENTIAL_REDIRECT = 'https://ts-interop.example.test/callback'
const DISCOVERY_ORIGIN = 'https://ts-interop.example.test'
const LOOPBACK_REDIRECT = 'http://127.0.0.1:53124/callback'

const args = parseArgs(process.argv.slice(2))
const logFile = args.log ? resolve(args.log) : null
if (logFile) writeFileSync(logFile, '')

function parseArgs(argv) {
  const out = {}
  for (let i = 0; i < argv.length; i++) {
    const name = argv[i].replace(/^--/, '')
    out[name] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true
  }
  return out
}

function log(line = '') {
  console.log(line)
  if (logFile) appendFileSync(logFile, line + '\n')
}

function check(condition, message) {
  if (!condition) throw new Error(`CHECK FAILED: ${message}`)
  log(`  ok  ${message}`)
}

// --- the confidential client's key and metadata -----------------------------

async function prepare(dir) {
  mkdirSync(dir, { recursive: true })
  const key = await JoseKey.generate(['ES256'], 'ts-interop-key-1')
  const { kty, crv, x, y, kid } = key.publicJwk
  const metadata = {
    client_id: CONFIDENTIAL_CLIENT_ID,
    client_name: 'TS interop confidential client',
    application_type: 'web',
    grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'],
    redirect_uris: [CONFIDENTIAL_REDIRECT],
    scope: SCOPE,
    token_endpoint_auth_method: 'private_key_jwt',
    token_endpoint_auth_signing_alg: 'ES256',
    dpop_bound_access_tokens: true,
    jwks: { keys: [{ kty, crv, x, y, kid, use: 'sig', alg: 'ES256' }] },
  }
  writeFileSync(join(dir, 'client-metadata.json'), JSON.stringify(metadata, null, 2))
  writeFileSync(join(dir, 'private-key.jwk.json'), JSON.stringify(key.privateJwk))

  // The documents for --discovery, which the server fetches itself.
  const discovery = join(dir, 'discovery')
  mkdirSync(discovery, { recursive: true })
  const { jwks, ...withoutKeys } = metadata
  writeFileSync(join(discovery, 'confidential-client-metadata.json'), JSON.stringify({
    ...withoutKeys,
    client_id: `${DISCOVERY_ORIGIN}/confidential-client-metadata.json`,
    client_name: 'TS interop confidential client (jwks_uri)',
    jwks_uri: `${DISCOVERY_ORIGIN}/jwks.json`,
  }, null, 2))
  writeFileSync(join(discovery, 'jwks.json'), JSON.stringify(jwks, null, 2))
  writeFileSync(join(discovery, 'public-client-metadata.json'), JSON.stringify(publicDiscoverableMetadata(), null, 2))
  return dir
}

function publicDiscoverableMetadata() {
  return {
    client_id: `${DISCOVERY_ORIGIN}/public-client-metadata.json`,
    client_name: 'TS interop public client',
    application_type: 'web',
    grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'],
    redirect_uris: [CONFIDENTIAL_REDIRECT],
    scope: SCOPE,
    token_endpoint_auth_method: 'none',
    dpop_bound_access_tokens: true,
  }
}

// --- a one-account PLC directory, so the client can verify `sub` -------------
//
// After the code exchange the reference client resolves the DID in `sub` and
// checks that its PDS is served by the issuer that issued the token. The demo
// account is a did:plc, so this stands in for plc.directory.

function startPlcDirectory(origin) {
  const document = {
    '@context': ['https://www.w3.org/ns/did/v1'],
    id: DEMO_DID,
    alsoKnownAs: [`at://${DEMO_HANDLE}`],
    service: [{ id: '#atproto_pds', type: 'AtprotoPersonalDataServer', serviceEndpoint: origin }],
  }
  return new Promise((done) => {
    const server = createServer((req, res) => {
      if (decodeURIComponent(req.url ?? '') === `/${DEMO_DID}`) {
        res.writeHead(200, { 'content-type': 'application/did+ld+json' })
        res.end(JSON.stringify(document))
      } else {
        res.writeHead(404, { 'content-type': 'application/json' })
        res.end('{"message":"not found"}')
      }
    })
    server.listen(0, '127.0.0.1', () => done({ server, url: `http://127.0.0.1:${server.address().port}` }))
  })
}

// --- the reference client -----------------------------------------------------

function memoryStore(map = new Map()) {
  return {
    map,
    set: async (key, value) => void map.set(key, value),
    get: async (key) => map.get(key),
    del: async (key) => void map.delete(key),
  }
}

function makeClient({ clientMetadata, keyset, plcDirectoryUrl, sessions }) {
  const sessionStore = sessions ?? memoryStore()
  const client = new NodeOAuthClient({
    clientMetadata,
    keyset,
    // The example listens on http loopback; the client refuses http issuers and
    // resources unless told otherwise.
    allowHttp: true,
    plcDirectoryUrl,
    stateStore: memoryStore(),
    sessionStore,
    requestLock: async (_name, fn) => fn(),
  })
  return { client, sessionStore }
}

// --- the browser: a cookie jar and three requests -----------------------------

async function approveInBrowser(origin, authorizeUrl) {
  const jar = new Map()
  const absorb = (res) => {
    for (const cookie of res.headers.getSetCookie()) {
      const [pair] = cookie.split(';')
      const index = pair.indexOf('=')
      const name = pair.slice(0, index)
      const value = pair.slice(index + 1)
      if (value === '' || /Max-Age=0/.test(cookie)) jar.delete(name)
      else jar.set(name, value)
    }
  }
  const cookieHeader = () => [...jar].map(([k, v]) => `${k}=${v}`).join('; ')
  const csrfOf = (html) => {
    const match = html.match(/name="csrf" value="([^"]+)"/)
    if (!match) throw new Error('no csrf field in page')
    return match[1]
  }
  const post = async (path, fields, html) => {
    const res = await fetch(origin + path, {
      method: 'POST',
      redirect: 'manual',
      headers: { 'content-type': 'application/x-www-form-urlencoded', cookie: cookieHeader(), origin },
      body: new URLSearchParams({ csrf: csrfOf(html), ...fields }),
    })
    absorb(res)
    return res
  }

  const page = await fetch(authorizeUrl, { redirect: 'manual' })
  check(page.status === 200, `authorization page: 200 (got ${page.status})`)
  check(page.headers.get('x-frame-options') === 'DENY', 'authorization page forbids framing')
  absorb(page)
  const signInHtml = await page.text()

  const consent = await post('/oauth/authorize/sign-in', { identifier: DEMO_HANDLE, password: DEMO_PASSWORD }, signInHtml)
  check(consent.status === 200, `sign-in accepted: 200 (got ${consent.status})`)
  const consentHtml = await consent.text()
  check(consentHtml.includes('name="decision"'), 'consent page shown')

  const approved = await post('/oauth/authorize/consent', { decision: 'approve' }, consentHtml)
  check(approved.status === 303, `consent redirects with 303 (got ${approved.status})`)
  return approved.headers.get('location')
}

// --- one full flow -------------------------------------------------------------

async function runFlow({ label, origin, plcDirectoryUrl, clientMetadata, keyset, redirectUri }) {
  log(`\n== ${label} ==`)
  log(`  client_id: ${clientMetadata.client_id}`)
  const { client, sessionStore } = makeClient({ clientMetadata, keyset, plcDirectoryUrl })
  const appState = `state-${label.replace(/\W+/g, '-')}`

  // Discovery from the resource server, then PAR. The client validates the
  // protected-resource and authorization-server metadata here.
  const authorizeUrl = await client.authorize(origin, { scope: SCOPE, state: appState })
  check(authorizeUrl.origin === origin && authorizeUrl.pathname === '/oauth/authorize', 'authorize() returned the authorization endpoint')
  check(authorizeUrl.searchParams.get('request_uri')?.startsWith('urn:ietf:params:oauth:request_uri:'), 'PAR returned a request_uri')
  check([...authorizeUrl.searchParams.keys()].sort().join(',') === 'client_id,request_uri', 'authorization URL carries only client_id and request_uri')

  const location = await approveInBrowser(origin, authorizeUrl)
  check(location?.startsWith(redirectUri + '?'), `redirected to the registered redirect_uri`)
  const callbackParams = new URL(location).searchParams
  check(callbackParams.get('iss') === origin, 'redirect carries iss')

  // callback() checks state and iss, exchanges the code with DPoP (retrying for
  // the server nonce), validates the token response, and verifies `sub` by
  // resolving the DID back to this issuer.
  const { session, state } = await client.callback(callbackParams)
  check(state === appState, 'callback returned the application state')
  check(session.did === DEMO_DID, `session subject is the demo account (${session.did})`)
  const info = await session.getTokenInfo(false)
  check(info.iss === origin, 'token issuer is the example server')
  check(info.scope === SCOPE, `granted scope is "${info.scope}"`)
  const firstAccessToken = (await sessionStore.get(DEMO_DID)).tokenSet.access_token

  // A DPoP-bound resource request (the client adds ath and handles the nonce).
  const who = await session.fetchHandler('/xrpc/com.atproto.server.getSession')
  check(who.status === 200, `resource request: 200 (got ${who.status})`)
  const body = await who.json()
  check(body.did === DEMO_DID && body.handle === DEMO_HANDLE, 'resource server identified the account')
  check(body.canPost === true, 'resource server sees the granted scope')

  // Forced refresh: single-use rotation.
  await session.getTokenInfo(true)
  const rotated = (await sessionStore.get(DEMO_DID)).tokenSet
  check(rotated.access_token !== firstAccessToken, 'refresh issued a new access token')
  check(typeof rotated.refresh_token === 'string', 'refresh issued a new refresh token')
  const again = await session.fetchHandler('/xrpc/com.atproto.server.getSession')
  check(again.status === 200, 'resource request with the refreshed token: 200')

  // Keep a copy of the live session, revoke, then show the copy is dead.
  const snapshot = structuredClone(await sessionStore.get(DEMO_DID))
  await session.signOut()
  check((await sessionStore.get(DEMO_DID)) === undefined, 'signOut() revoked and cleared the session')

  const ghost = () =>
    makeClient({
      clientMetadata,
      keyset,
      plcDirectoryUrl,
      sessions: memoryStore(new Map([[DEMO_DID, structuredClone(snapshot)]])),
    }).client

  // A second client instance holding the revoked tokens asks the token
  // endpoint for a refresh: the server must answer invalid_grant.
  let refreshRefused = false
  try {
    await ghost().restore(DEMO_DID, true)
  } catch (error) {
    const text = `${error?.name}: ${error?.message} ${error?.cause?.message ?? ''}`
    refreshRefused = /invalid_grant|TokenRefreshError/.test(text)
    log(`      (token endpoint said: ${text.slice(0, 160)})`)
  }
  check(refreshRefused, 'revoked refresh token is refused by the token endpoint (invalid_grant)')

  // And a third presents the revoked access token to the resource server.
  let resourceRefused = false
  try {
    const ghostSession = await ghost().restore(DEMO_DID, false)
    const res = await ghostSession.fetchHandler('/xrpc/com.atproto.server.getSession')
    resourceRefused = res.status === 401
    log(`      (resource server said: ${res.status} ${res.headers.get('www-authenticate') ?? ''})`)
  } catch (error) {
    resourceRefused = true
    log(`      (client refused to continue: ${error?.name}: ${String(error?.message).slice(0, 120)})`)
  }
  check(resourceRefused, 'revoked access token is refused by the resource server')
}

// --- starting the example -------------------------------------------------------

async function startExample(clientDir) {
  const port = Number(args.port ?? 18787)
  const origin = `http://127.0.0.1:${port}`
  const serverPackage = resolve(here, '..', '..')
  const bin = args['server-bin'] ? resolve(args['server-bin']) : join(serverPackage, '.build', 'debug', 'petrel-oauth-server-example')
  if (!existsSync(bin)) {
    throw new Error(`example binary not found at ${bin}; run "swift build --product petrel-oauth-server-example" in ${serverPackage}`)
  }
  const child = spawn(bin, ['--port', String(port), '--register-client', join(clientDir, 'client-metadata.json')], {
    stdio: ['ignore', 'ignore', 'inherit'],
  })
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      if ((await fetch(origin + '/health')).ok) return { origin, stop: () => child.kill() }
    } catch {
      await new Promise((r) => setTimeout(r, 100))
    }
  }
  child.kill()
  throw new Error('example server did not start')
}

async function waitForHealth(origin) {
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      if ((await fetch(origin + '/health')).ok) return
    } catch {
      // not listening yet
    }
    await new Promise((r) => setTimeout(r, 100))
  }
  throw new Error(`no server answered at ${origin}/health`)
}

// --- main ------------------------------------------------------------------------

async function main() {
  if (typeof args.prepare === 'string') {
    await prepare(resolve(args.prepare))
    return
  }

  let stop = () => {}
  let origin = typeof args.origin === 'string' ? args.origin.replace(/\/$/, '') : null
  let clientDir = typeof args['client-dir'] === 'string' ? resolve(args['client-dir']) : null
  if (!origin) {
    clientDir = await prepare(mkdtempSync(join(tmpdir(), 'petrel-ts-interop-')))
    ;({ origin, stop } = await startExample(clientDir))
  }
  if (!clientDir) throw new Error('--origin needs --client-dir (the directory given to --prepare)')

  await waitForHealth(origin)
  const plc = await startPlcDirectory(origin)
  const versions = JSON.parse(readFileSync(join(here, 'package.json'), 'utf8')).dependencies
  log(`reference client: @atproto/oauth-client-node ${versions['@atproto/oauth-client-node']} (node ${process.version})`)
  log(`server under test: ${origin}`)
  if (typeof args.commit === 'string') log(`commit under test: ${args.commit}`)
  log(`transport: plain http on loopback, client option allowHttp: true`)

  try {
    const loopbackClientId =
      `http://localhost?redirect_uri=${encodeURIComponent(LOOPBACK_REDIRECT)}&scope=${encodeURIComponent(SCOPE)}`
    await runFlow({
      label: 'public loopback client',
      origin,
      plcDirectoryUrl: plc.url,
      clientMetadata: atprotoLoopbackClientMetadata(loopbackClientId),
      redirectUri: LOOPBACK_REDIRECT,
    })

    const privateJwk = JSON.parse(readFileSync(join(clientDir, 'private-key.jwk.json'), 'utf8'))
    if (args.discovery) {
      // The server has no registration for these: it fetches each client's
      // metadata (and the confidential client's jwks_uri) over https.
      await runFlow({
        label: 'public https client (discovered)',
        origin,
        plcDirectoryUrl: plc.url,
        clientMetadata: publicDiscoverableMetadata(),
        redirectUri: CONFIDENTIAL_REDIRECT,
      })
      await runFlow({
        label: 'confidential client, private_key_jwt with jwks_uri (discovered)',
        origin,
        plcDirectoryUrl: plc.url,
        clientMetadata: JSON.parse(readFileSync(join(clientDir, 'discovery', 'confidential-client-metadata.json'), 'utf8')),
        keyset: [await JoseKey.fromJWK(privateJwk)],
        redirectUri: CONFIDENTIAL_REDIRECT,
      })
    } else {
      await runFlow({
        label: 'confidential client (private_key_jwt, registered)',
        origin,
        plcDirectoryUrl: plc.url,
        clientMetadata: JSON.parse(readFileSync(join(clientDir, 'client-metadata.json'), 'utf8')),
        keyset: [await JoseKey.fromJWK(privateJwk)],
        redirectUri: CONFIDENTIAL_REDIRECT,
      })
    }
    log('\nINTEROP PASS')
  } finally {
    plc.server.close()
    stop()
  }
}

main().then(
  () => process.exit(0),
  (error) => {
    log(`\nINTEROP FAIL: ${error?.stack ?? error}`)
    process.exit(1)
  },
)
