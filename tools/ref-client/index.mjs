import { performance } from 'node:perf_hooks'
import { toDpopKeyStore } from '@atproto/oauth-client-node/src/node-dpop-store.js'
import { dpopFetchWrapper } from '@atproto/oauth-client/src/fetch-dpop.js'
import { SimpleStore } from '@atproto-labs/simple-store'

function parseArgs() {
  const args = {}
  const argv = process.argv.slice(2)
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i]
    if (k.startsWith('--')) {
      const name = k.slice(2)
      if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        args[name] = argv[i + 1]
        i++
      } else {
        args[name] = 'true'
      }
    }
  }
  return args
}

const args = parseArgs()
const baseUrl = args['base-url']
const endpoint = args['endpoint']
const method = (args['method'] || 'GET').toUpperCase()
const total = Number(args['requests'] || 100)
const concurrency = Math.max(1, Number(args['concurrency'] || 10))
const targetRps = Number(args['target-rps'] || 0)

if (!baseUrl || !endpoint) {
  console.error('Usage: node index.mjs --base-url <url> --endpoint <xrpc or absolute> [--method GET|POST] [--requests N] [--concurrency N] [--target-rps R]')
  process.exit(2)
}

// In-memory nonce store
const nonces = new SimpleStore()

// Minimal key material for dpopFetchWrapper is expected from oauth flow normally.
// For pure fetch comparison, generate a key via jose Key if needed.
// Here we stub a throw to highlight this requirement.
if (!process.env.ATPROTO_DPOP_JWK) {
  console.error('Set ATPROTO_DPOP_JWK (private JWK JSON) to sign DPoP proofs for reference client.')
  process.exit(1)
}

const jwk = JSON.parse(process.env.ATPROTO_DPOP_JWK)
// Lazy import to convert JWK to Key
const { JoseKey } = await import('@atproto/jwk-jose')
const key = await JoseKey.fromJWK(jwk)

const fetch = dpopFetchWrapper({ key, nonces })

function toUrl(base, ep) {
  if (/^https?:/i.test(ep)) return ep
  const p = ep.startsWith('/') ? `xrpc${ep}` : `xrpc/${ep}`
  return new URL(p, base).toString()
}

const url = toUrl(baseUrl, endpoint)

const perWorker = Math.max(1, Math.floor(total / concurrency))
const rema = total % concurrency
const workDist = Array.from({ length: concurrency }, (_, i) => perWorker + (i < rema ? 1 : 0))

const interval = targetRps > 0 ? 1000 / targetRps : 0
let nextSlot = performance.now()
let shapedSleepMs = 0

async function beforeRequest() {
  if (interval <= 0) return
  const now = performance.now()
  if (now >= nextSlot) {
    nextSlot = now + interval
  } else {
    const delay = nextSlot - now
    shapedSleepMs += delay
    await new Promise((r) => setTimeout(r, delay))
    nextSlot += interval
  }
}

function nowSeconds() { return performance.now() / 1000 }

async function runWorker(n) {
  let ok = 0, ko = 0
  const status = new Map()
  const times = []
  for (let i = 0; i < n; i++) {
    try {
      await beforeRequest()
      const t0 = nowSeconds()
      const res = await fetch(url, { method })
      const dt = nowSeconds() - t0
      times.push(dt)
      status.set(res.status, (status.get(res.status) || 0) + 1)
      if (res.ok) ok++
      else ko++
      // Consume body to allow retry in wrapper
      await res.text()
    } catch (e) {
      ko++
    }
  }
  return { ok, ko, status, times }
}

const tStart = nowSeconds()
const results = await Promise.all(workDist.map(runWorker))
const elapsed = nowSeconds() - tStart

let ok = 0, ko = 0
const status = new Map()
let times = []
for (const r of results) {
  ok += r.ok; ko += r.ko
  for (const [k, v] of r.status) status.set(k, (status.get(k) || 0) + v)
  times = times.concat(r.times)
}

times.sort((a, b) => a - b)
const sent = ok + ko
const rps = sent / Math.max(0.001, elapsed)
function pct(p) {
  if (times.length === 0) return 0
  const idx = Math.max(0, Math.min(times.length - 1, Math.floor((times.length - 1) * p)))
  return times[idx]
}

console.log('=== atproto-ref Summary ===')
console.log(`endpoint=${endpoint} method=${method} base=${baseUrl}`)
if (interval > 0) console.log(`targetRps=${(1000/interval).toFixed(2)} shapedSleep=${(shapedSleepMs/1000).toFixed(3)}s`)
console.log(`elapsed=${elapsed.toFixed(3)}s rps=${rps.toFixed(1)}`)
console.log(`success=${ok} failures=${ko} status=${Array.from(status.entries()).sort((a,b)=>a[0]-b[0]).map(([k,v])=>`${k}:${v}`).join(', ')}`)
if (times.length) console.log(`latency p50=${pct(0.50).toFixed(3)}s p95=${pct(0.95).toFixed(3)}s p99=${pct(0.99).toFixed(3)}s max=${(times[times.length-1]).toFixed(3)}s`)

