# PLC directory sample

Operations recorded from the public PLC directory, `https://plc.directory`, on
**2026-11-11**. `PLCCorpusTests` uses them to prove that `PetrelPLC` reads,
hashes and verifies what the directory actually serves.

Everything here was fetched with unauthenticated `GET` requests. No operation,
CID or signature in these files was produced by Petrel.

## Whose identities are here

The PLC operation log is public, but it is also a list of people's handles
and hosting providers. This repository vendors operations of two kinds of
identity only:

1. **Organisations and services.** The handle is an organisation's own
   domain, or the identity is operated by a service and names no person.
2. **Test identities.** Created by someone's test script against the public
   directory: the handle and the PDS are reserved or unresolvable names
   (`example.test`, `*.test`, `localhost`, a single-label host).

Nothing else is vendored. In particular there are no bulk export pages here:
a page of the export is a thousand arbitrary accounts. The bulk run exists,
but as a download at test time; see "Bulk sample" below.

| DID | Kind | What it is | Shapes it provides |
|---|---|---|---|
| `did:plc:z72i7hdynmk6r22z27h6tvur` | organisation | `bsky.app` | regular genesis and updates, K-256 |
| `did:plc:ewvi7nxzyoun6zhxrhs64oiz` | organisation | `atproto.com`, the specification's own example | regular genesis and updates, K-256 |
| `did:plc:ar7c4by46qjdydhdevvrndac` | organisation | `moderation.bsky.app`, a labeler | two verification methods, two services |
| `did:plc:eon2iu7v3x2ukgxkqaf7e5np` | organisation | `safety.bsky.app` | regular genesis and updates |
| `did:plc:oc6vwdlmk2kqyida5i74d3p5` | organisation | `support.bsky.team` | legacy `create` genesis (January 2023, K-256) followed by regular updates |
| `did:plc:4dtbz2ivhp5app3sbntcccxc` | organisation | `status.bsky.app` | regular genesis and update |
| `did:plc:hymtrrab3tb62ktcluou37ce` | service | a repository identity on `knot1.tangled.sh`; no handle | first operation has empty `verificationMethods` and no `atproto_pds` service |
| `did:plc:5qepwfemd2p3ts3phpzjvmsi` | test | alias `tombstone`, PDS `https://localhost` | ends in a `plc_tombstone` |
| `did:plc:n7eilcz7ouze6kj5hwvyt4ju` | test | `example.test` | recovery: a tombstone signed by the second rotation key, nullified within 72 hours by an operation the first rotation key signed from the same predecessor |
| `did:plc:xgj5yvayzto5fx3qq2o7ichg` | test | `example.test` | the same recovery, another identity |
| `did:plc:k525d5my7ob3divsqd5ogf7b` | test | `testman.test`, PDS `localhost:4989` | legacy `create` with P-256 keys and a `service` that has no URL scheme |
| `did:plc:nlkuhfcmtu7jluphj37j5o4f` | test | alias is a data URI of zero bytes, PDS `https://uwu` | a 7.3 kB operation (over the reference server's current 4,000-byte limit, under the specification's 7,500), P-256 rotation key |

## Files

| File | Contents |
|---|---|
| `audit/did_plc_….json` | The complete audit log of each identity above, the body of `GET /:did/log/audit`. 12 logs, 34 operations. |
| `export-legacy.jsonl` | The same 34 operations as `GET /export` returns them in the legacy format, one request per operation (`count` small, `after` just before the operation's timestamp), keeping the line with the matching CID. |
| `export-sequenced.jsonl` | 14 of those operations (four identities) as `GET /export` returns them in the `sequenced_op` format. |
| `manifest.json` | The identities and line counts, written by the download. |
| `fetch-export-sample.sh` | Downloads the bulk sample described below. |

## Coverage by shape

"Real" means recorded from the directory, so produced and accepted by other
software. "Synthetic" means built and signed by Petrel in the test itself:
it exercises the code path but is **not** cross-implementation evidence.

| Shape | Source | Vendored operations |
|---|---|---|
| Regular `plc_operation` genesis | real, organisation / service / test | 10 |
| Regular update | real, organisation / service / test | 19 |
| Legacy `create` genesis, K-256 | real, organisation (`support.bsky.team`) | 1 |
| Legacy `create` genesis, P-256, scheme-less `service` | real, test identity | 1 |
| Update following a legacy `create` | real, organisation | 1 |
| `plc_tombstone` | real, test identities | 3 |
| Recovery (nullified operation) | real, test identities | 2 logs |
| K-256 signature verified | real | 32 |
| P-256 signature verified | real, test identities | 2 |
| Empty `verificationMethods` | real, service | 1 |
| Several verification methods and services | real, organisation | 3 |
| Operation larger than 4,000 DAG-CBOR bytes | real, test identity | 1 |
| Sequenced export format | real | 14 lines |
| Legacy export format, including `nullified: true` | real | 34 lines |
| Duplicate rotation keys | synthetic (`PLCAuditVerifierTests`, `PLCReadWriteRulesTests`) | — |
| More than five rotation keys | synthetic (`PLCReadWriteRulesTests`) | — |
| Ed25519 or other non-ECDSA verification method | synthetic (`PLCReadWriteRulesTests`) | — |
| Recovery outside 72 hours, lower-authority fork, operation after a tombstone, high-S signatures | synthetic negatives (`PLCAuditVerifierTests`, `PLCOperationSigningTests`) | — |

The three synthetic positive shapes do exist in the directory, but only on
identities of individuals, which are not vendored. The bulk sample below
contains real instances of each (10 operations with duplicate rotation keys,
one Ed25519 verification method), so the bulk run covers them with real data.

## Bulk sample

`PLCCorpusTests.externalCorpus` runs over any directory of export pages named
by `PETREL_PLC_CORPUS_DIR`: every line must decode and hash to its CID, every
genesis operation must hash to its DID and carry a valid signature, and every
update whose predecessor is in the sample must carry a valid signature.

```sh
Tests/PetrelPLCTests/Vectors/plc-directory/fetch-export-sample.sh /tmp/plc-sample
PETREL_PLC_CORPUS_DIR=/tmp/plc-sample swift test --filter PLCCorpusTests
```

The script requests 62 pages of 1,000 operations from 32 starting points
between November 2022 and November 2026, in both export formats. The log is
append-only, so the requests return the same operations whenever they are
made. Result on 2026-11-11:

| | |
|---|---|
| Operations | 62,000 |
| Rejected | 0 |
| Genesis operations whose DID and signature verified | 55,872 |
| Updates whose signature verified (predecessor earlier in the sample) | 4,211 |
| Signatures by K-256 keys / P-256 keys | 45,414 / 14,669 |

The decoder this replaced refused 6,977 of the same 62,000 operations: 6,255
legacy `create` operations, 709 with an alias longer than 2,048 bytes, 10 with
duplicate rotation keys, 6 with empty `verificationMethods` and one with an
Ed25519 verification method.
