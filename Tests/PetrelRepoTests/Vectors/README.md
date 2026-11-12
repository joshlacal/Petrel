# Repository test vectors

## Official interop vectors

Unmodified copies from <https://github.com/bluesky-social/atproto-interop-tests>
(`main`, CC0-1.0):

| Directory | Files | Loaded by |
|---|---|---|
| `mst/` | `key_heights.json`, `common_prefix.json`, `example_keys.txt` | `RepositoryInteropVectorTests.swift` |
| `data-model/` | `data-model-fixtures.json`, `data-model-valid.json`, `data-model-invalid.json` | `DataModelInteropVectorTests.swift` |
| `firehose/` | `commit-proof-fixtures.json` | `CommitProofFixtureTests.swift` |

Every file is read from disk through `Bundle.module` and every entry in it is
run. To update, replace the files with the upstream ones; do not edit them.

## `real-repo/`: a repository exported from the network

A complete, unmodified export of one public account, used as a differential
test of the reader, the signature check and the writer against data the
library did not produce. See `real-repo/README.md`.
