# Reference TypeScript client interop

`run.mjs` drives `@atproto/oauth-client-node`, the reference AT Protocol OAuth client, against `petrel-oauth-server-example`. It is the check that a client this project did not write accepts the server.

For a public `http://localhost` development client and for a confidential `private_key_jwt` client it runs: discovery from the resource server, the pushed authorization request, sign-in and consent (the forms are submitted with plain HTTP requests, no browser), the callback with its `state` and `iss` checks, the code exchange, a DPoP-protected resource request, a forced refresh, revocation, and then proof from a second client instance that the revoked refresh token and access token are refused.

## Run it

```
cd Server
swift build --product petrel-oauth-server-example
cd Scripts/ts-client-interop
npm install
node run.mjs --log transcript.log
```

The script starts the example on `http://127.0.0.1:18787` (`--port` to change it), runs both flows, prints one line per check, and exits non-zero on the first failure.

To run it from the Swift test suite instead, which starts the example in-process:

```
cd Server
PETREL_TS_INTEROP_DIR=$PWD/Scripts/ts-client-interop swift test --filter typeScriptClientInterop
```

The test is skipped unless `PETREL_TS_INTEROP_DIR` names a directory containing `run.mjs` and an installed `node_modules`.

## How it is wired

- **Transport.** The example listens on plain http on loopback, and the client is constructed with `allowHttp: true`. No TLS listener is involved.
- **Identity.** After the code exchange the client resolves the DID in `sub` and checks that its PDS is served by the issuer that issued the token. The demo account is `did:plc:petrelexampledemoaccount`, so the script runs a one-document PLC directory on loopback and passes it as `plcDirectoryUrl`.
- **Confidential client.** A confidential client's `client_id` must be an https URL the server can fetch, which a loopback test cannot provide. The script generates an ES256 key, writes the client metadata (with the public key inline as `jwks`) to a temporary directory, and the example pre-registers it with `--register-client`. The private key never leaves that directory.

Versions are pinned in `package.json`. `node_modules` is not committed.
