# Real repository fixture

Everything here is public data served without credentials. Nothing was edited
or trimmed.

| File | What it is | How it was fetched |
|---|---|---|
| `repo.car` | Full repository export of `did:plc:ewvi7nxzyoun6zhxrhs64oiz` (handle `atproto.com`) | `GET https://enoki.us-east.host.bsky.network/xrpc/com.atproto.sync.getRepo?did=did:plc:ewvi7nxzyoun6zhxrhs64oiz` |
| `diddoc.json` | The account's DID document, which names its PDS and its `#atproto` signing key (secp256k1) | `GET https://plc.directory/did:plc:ewvi7nxzyoun6zhxrhs64oiz` |
| `record-proof-present.car` | Inclusion proof for `app.bsky.actor.profile/self` | `GET …/xrpc/com.atproto.sync.getRecord?did=…&collection=app.bsky.actor.profile&rkey=self` |
| `record-proof-absent.car` | Exclusion proof for `app.bsky.actor.profile/doesnotexist` | same endpoint, `rkey=doesnotexist` |
| `expected.json` | Facts about `repo.car` computed by `carstat.py` | `python3 carstat.py repo.car > expected.json` |
| `carstat.py` | An independent CAR and MST reader (standard library only, shares no code with Petrel) | written for this fixture |

Fetched 2026-11-11 (UTC). The host is the `AtprotoPersonalDataServer` endpoint
in `diddoc.json`; `bsky.social` itself answers this route with 401.

At that time the repository was at revision `3mzywjbhlki2y`, commit
`bafyreihc6eb6juat4svhhjcrniicsppi6bqd2r542e3dmscu2btmrisbii`: 860,266 bytes,
2,388 blocks, 1,868 records in 30 collections. All three archives are at the
same commit.

`expected.json` is the oracle: the tests compare what Petrel reads against
what the Python script read, so a shared misreading cannot pass. The signing
key is taken from `diddoc.json`, not from the archive.

The account's key or records may change later. That does not affect the
fixture: a signed commit stays verifiable against the key that was current
when it was made, and that key is the one captured here.
