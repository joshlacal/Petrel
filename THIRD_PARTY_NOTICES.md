# Third-party notices

Petrel is licensed under the terms in `LICENSE`. Parts of it are derived from,
or test against, the work of others. Those parts and their licenses are listed
here.

## bluesky-social/atproto

<https://github.com/bluesky-social/atproto>, dual-licensed MIT OR Apache-2.0.

The Merkle Search Tree algorithms in `Sources/PetrelRepo` are a Swift
adaptation of the TypeScript reference implementation in
`packages/repo/src` (commit `3f6c96d5d2d25438bd40fa89d6ecc37865f8e354`):

| Petrel | Reference |
|---|---|
| `RepositoryMST.swift` (insert, update, delete, split, merge, trim) | `mst/mst.ts`, `mst/util.ts` |
| `RepositoryMSTCodec.swift` (node layout, key depth, prefix compression) | `mst/util.ts` |
| `RepositoryMSTValidation.swift`, `RepositoryMSTWalker.swift` (tree invariants) | `mst/mst.ts`, `mst/util.ts` |
| `RepositoryMSTProof.swift` (key lookup, `cidsForPath`, `getCoveringProof`) | `mst/mst.ts` |
| `PublicRepositoryCAR.swift` (CAR framing, full-repository block order) | `car.ts`, `sync/provider.ts` |
| `PublicRepositoryEngine.swift` (commit formation, relevant blocks) | `repo.ts` |

Copyright (c) 2022-2026 Bluesky Social PBC, and Contributors.

Used under the MIT License:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## bluesky-social/atproto-interop-tests

<https://github.com/bluesky-social/atproto-interop-tests>, CC0-1.0.

Unmodified test vectors are vendored under `Tests/PetrelTests/Vectors/crypto`
and `Tests/PetrelRepoTests/Vectors/{mst,data-model,firehose}`.

## Repository fixture

`Tests/PetrelRepoTests/Vectors/real-repo` holds an unmodified public export of
one account's repository, its DID document, and two record proofs, fetched
without credentials from public endpoints. Provenance is recorded in that
directory's `README.md`. The records are the account holder's content and are
included only as protocol test data.
