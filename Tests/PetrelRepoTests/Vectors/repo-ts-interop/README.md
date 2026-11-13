# Petrel-written repositories, checked by the TypeScript reference

`verify-petrel-repos.mjs` hands repositories that Petrel wrote to `@atproto/repo`, the reference implementation, so that Petrel's writes are not only checked by Petrel.

`RepositoryTypeScriptInteropTests` builds one repository per curve (secp256k1 and P-256): 50 records across two collections, then a commit with an update, two deletes and a create. For each, the reference must:

- verify the full export (`verifyRepoCar`): the commit signature against the account's `did:key`, the DID, the revision, and every record;
- build its own MST from the same records and arrive at the commit's `data` root;
- apply the last commit's diff CAR to the export from before it (`verifyDiffCar`) and report exactly Petrel's operations;
- accept two inclusion proofs and one absence proof (`verifyProofs`);
- refuse the export under another key and for another DID.

## Run it

```
mkdir /tmp/repo-ts-interop && cp package.json /tmp/repo-ts-interop/ && (cd /tmp/repo-ts-interop && npm install)
PETREL_TS_INTEROP_DIR=/tmp/repo-ts-interop swift test --filter RepositoryTypeScriptInteropTests
```

The test is skipped unless `PETREL_TS_INTEROP_DIR` is set. `PETREL_TS_INTEROP_NODE` picks another `node`, and `PETREL_REPO_TS_INTEROP_TRANSCRIPT=<file>` keeps the script's transcript (one line per check). Versions are pinned in `package.json`; `node_modules` is not committed.
