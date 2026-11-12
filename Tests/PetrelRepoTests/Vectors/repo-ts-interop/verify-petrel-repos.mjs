// Verifies repositories written by Petrel with the TypeScript reference
// implementation (@atproto/repo), and writes what it said.
//
// Usage (see README.md in this directory):
//
//   cd <directory holding node_modules with @atproto/repo, @atproto/crypto, @atproto/lex-data>
//   node <this file> <petrel-repos.json> <output.json>
//
// For each case Petrel provides a full repository export, the export before
// its last commit, that commit's diff CAR and operations, and record proofs.
// The reference must accept all of them, and must refuse each one under a
// key the account does not hold. Exit status is 0 only if every check passed.

import { createRequire } from 'node:module'
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

const [inputPath, outputPath] = process.argv.slice(2)
if (!inputPath || !outputPath) {
  console.error('usage: node verify-petrel-repos.mjs <input.json> <output.json>')
  process.exit(64)
}

const repo = await load('@atproto/repo')
const crypto = await load('@atproto/crypto')
const { parseCid } = await load('@atproto/lex-data')

const input = JSON.parse(fs.readFileSync(inputPath, 'utf8'))
const bytes = (base64) => new Uint8Array(Buffer.from(base64, 'base64'))
const split = (key) => {
  const slash = key.indexOf('/')
  return { collection: key.slice(0, slash), rkey: key.slice(slash + 1) }
}
const sameSet = (a, b) => a.length === b.length && [...a].sort().join('\n') === [...b].sort().join('\n')

const output = {
  reference: {
    '@atproto/repo': version('@atproto/repo'),
    '@atproto/crypto': version('@atproto/crypto'),
    node: process.version,
  },
  cases: [],
}
console.log(`reference: @atproto/repo ${output.reference['@atproto/repo']}, @atproto/crypto ${output.reference['@atproto/crypto']} (node ${process.version})`)

let failures = 0
for (const c of input.cases) {
  const checks = []
  const check = (name, ok, detail) => {
    checks.push({ name, ok, detail: detail ?? null })
    if (!ok) failures += 1
    console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ` (${detail})` : ''}`)
  }
  const attempt = async (name, body) => {
    try {
      await body()
    } catch (error) {
      check(name, false, String(error?.message ?? error))
    }
  }
  const refused = async (name, body) => {
    try {
      await body()
      check(name, false, 'accepted')
    } catch (error) {
      check(name, true, String(error?.message ?? error))
    }
  }
  console.log(`\n== ${c.label}: ${c.did}, key ${c.didKey} ==`)
  console.log(`  commit ${c.commitCID} rev ${c.revision} data ${c.dataCID}`)

  // 1. The full export: commit signature, DID, every record.
  await attempt('full export verifies (verifyRepoCar)', async () => {
    const verified = await repo.verifyRepoCar(bytes(c.repositoryCAR), c.did, c.didKey)
    check('full export verifies (verifyRepoCar)', true)
    check('head commit is the one Petrel signed', verified.commit.cid.toString() === c.commitCID, verified.commit.cid.toString())
    check('revision matches', verified.commit.rev === c.revision, verified.commit.rev)
    const got = verified.creates.map((w) => `${w.collection}/${w.rkey} ${w.cid.toString()}`)
    const want = c.records.map((r) => `${r.path} ${r.cid}`)
    check(`every record is read back (${want.length})`, sameSet(got, want), sameSet(got, want) ? null : got.join(', '))
  })

  // 2. The reference builds its own tree from the same records: same root.
  await attempt('independent MST root equals the commit data', async () => {
    let mst = await repo.MST.create(new repo.MemoryBlockstore())
    for (const r of c.records) mst = await mst.add(r.path, parseCid(r.cid))
    const root = (await mst.getPointer()).toString()
    check('independent MST root equals the commit data', root === c.dataCID, root)
  })

  // 3. The last commit's diff, applied to the repository before it.
  await attempt('diff verifies against the previous repository (verifyDiffCar)', async () => {
    const previous = await repo.readCarWithRoot(bytes(c.previousRepositoryCAR))
    const previousRepo = await repo.Repo.load(new repo.MemoryBlockstore(previous.blocks), previous.root)
    const diff = await repo.verifyDiffCar(previousRepo, bytes(c.diffCAR), c.did, c.didKey)
    check('diff verifies against the previous repository (verifyDiffCar)', true)
    check('diff head is the commit', diff.commit.cid.toString() === c.commitCID)
    const got = diff.writes.map((w) => `${w.action} ${w.collection}/${w.rkey} ${w.cid.toString()}`)
    const want = c.operations.map((o) => `${o.action} ${o.path} ${o.action === 'delete' ? o.prev : o.cid}`)
    check(`diff writes are Petrel's operations (${want.length})`, sameSet(got, want), sameSet(got, want) ? null : got.join(', '))
  })

  // 4. Record proofs, present and absent.
  for (const proof of c.proofs) {
    const claim = { ...split(proof.path), cid: proof.cid == null ? null : parseCid(proof.cid) }
    const name = `${proof.cid == null ? 'absence' : 'inclusion'} proof for ${proof.path} (verifyProofs)`
    await attempt(name, async () => {
      const result = await repo.verifyProofs(bytes(proof.car), [claim], c.did, c.didKey)
      check(name, result.verified.length === 1 && result.unverified.length === 0)
    })
  }

  // 5. Controls: the same bytes under a key the account does not hold.
  const stranger = await crypto.Secp256k1Keypair.create()
  await refused('full export refused under another key', () => repo.verifyRepoCar(bytes(c.repositoryCAR), c.did, stranger.did()))
  await refused('full export refused for another DID', () => repo.verifyRepoCar(bytes(c.repositoryCAR), 'did:plc:aaaaaaaaaaaaaaaaaaaaaaaa', c.didKey))

  output.cases.push({ label: c.label, commitCID: c.commitCID, checks })
}

fs.writeFileSync(outputPath, JSON.stringify(output, null, 2))
console.log(`\n${failures === 0 ? 'all checks passed' : `${failures} check(s) failed`}`)
process.exit(failures === 0 ? 0 : 1)
