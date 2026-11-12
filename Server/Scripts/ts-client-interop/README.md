# Reference TypeScript client interop

`run.mjs` drives `@atproto/oauth-client-node`, the reference AT Protocol OAuth client, against `petrel-oauth-server-example`. It is the check that a client this project did not write accepts the server.

For each client it runs: discovery from the resource server, the pushed authorization request, sign-in and consent (the forms are submitted with plain HTTP requests, no browser), the callback with its `state` and `iss` checks, the code exchange, a DPoP-protected resource request, a forced refresh, revocation, and then proof from a second client instance that the revoked refresh token and access token are refused.

## Run it

```
cd Server
swift build --product petrel-oauth-server-example
cd Scripts/ts-client-interop
npm install
node run.mjs --log transcript.log
```

The script starts the example on `http://127.0.0.1:18787` (`--port` to change it), runs two clients, prints one line per check, and exits non-zero on the first failure: a public `http://localhost` development client, and a confidential `private_key_jwt` client that the example pre-registers.

To run it from the Swift test suite instead, which starts the example in-process and also covers client discovery:

```
cd Server
PETREL_TS_INTEROP_DIR=$PWD/Scripts/ts-client-interop \
PETREL_INTEROP_COMMIT=$(jj log --no-graph -r @ -T commit_id) \
PETREL_TS_INTEROP_TRANSCRIPT=$PWD/transcript.log \
swift test --filter typeScriptClientInterop
```

The test is skipped unless `PETREL_TS_INTEROP_DIR` names a directory containing `run.mjs` and an installed `node_modules`. It runs three clients, none of them registered:
- the public `http://localhost` client;
- a public https client;
- a confidential `private_key_jwt` client whose keys are at its `jwks_uri`.

The example fetches the two https clients' metadata documents and the JWKS itself (`run.mjs --discovery`). The transcript records the commit under test (`PETREL_INTEROP_COMMIT`, or `GITHUB_SHA` in CI). The nightly `OAuth server` workflow runs this test.

## How it is wired

- **Transport.** The example listens on plain http on loopback, and the client is constructed with `allowHttp: true`. No TLS listener is involved.
- **Identity.** After the code exchange the client resolves the DID in `sub` and checks that its PDS is served by the issuer that issued the token. The demo account is `did:plc:petrelexampledemoaccount`, so the script runs a one-document PLC directory on loopback and passes it as `plcDirectoryUrl`.
- **Client discovery (Swift test).** An https `client_id` must be fetchable, and it has no port. The test serves the documents `run.mjs --prepare` writes to `discovery/` from a TLS listener on loopback, with a certificate for `ts-interop.example.test` issued by a certificate authority made for the run. The example fetches them through `PinnedNIOOAuthRemoteTransport` trusting only that authority. A test resolver answers 127.0.0.1 for the name, and a test wrapper sends the connection to the listener's port. The TLS name check, the address pinning and the fetch policy are the production ones.
- **Standalone script.** Without the Swift test there is no TLS host, so `node run.mjs` uses a confidential client the example pre-registers with `--register-client` (public key inline as `jwks`). The script generates the ES256 key into a temporary directory, and the private key never leaves it.

Versions are pinned in `package.json`. `node_modules` is not committed.
