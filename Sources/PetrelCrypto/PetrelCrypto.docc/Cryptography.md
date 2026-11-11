# Keys, Signing and Verification

Generate keys, sign data and verify signatures on both AT Protocol curves.

## Overview

Every signature in AT Protocol is made the same way: hash the bytes with
SHA-256, sign the hash with ECDSA, and encode the result as 64 bytes
(`r || s`, not DER) with the "low-S" value. The same rules apply to `p256`
and `k256`. ``ATProtoSigner`` produces such signatures and
``ATProtoPublicKey`` checks them, whichever curve the key is on.

Each example below is compiled and run by
`Tests/PetrelCryptoTests/CryptographyDocumentationTests.swift`.

### Generate a key and sign

``ATProtoCrypto/generateKeypair(curve:)`` defaults to K-256, as the reference
implementation does for new keys. Pass `.p256` for the other curve.

```swift
import PetrelCrypto

let keypair = ATProtoCrypto.generateKeypair()          // K-256
let message = Data("hello world".utf8)

let signature = try await keypair.sign(message)        // 64 bytes, low-S
let didKey = keypair.didKey                            // "did:key:zQ3sh…"
```

`sign` takes the bytes to be signed, not their hash; hashing is part of the
operation. When you have a concrete ``K256Keypair`` or ``P256Keypair`` rather
than `any ATProtoSigner`, `sign` is synchronous.

### Verify a signature

```swift
let valid = try ATProtoCrypto.verifySignature(
    didKey: didKey,
    data: message,
    signature: signature
)
```

The curve comes from the `did:key`. The call returns `false` for a wrong or
malformed signature and throws only when the key itself is unusable.

If you already hold the key, verify with it directly:

```swift
let publicKey = try ATProtoPublicKey(didKey: didKey)
let alsoValid = publicKey.isValidSignature(signature, for: message)
```

### Strict by default, lax on request

ECDSA signatures are malleable: `(r, n - s)` verifies whenever `(r, s)` does.
The specification requires verifiers to reject the high-S form, and the DER
encoding, for repository commits, labels and every other signature over a
CBOR object. That is ``ATProtoSignatureVerificationOptions/strict``, and it
is the default.

The same section of the specification exempts JWTs, whose signers (WebCrypto,
Secure Enclave, HSMs) do not normalize S. Use
``ATProtoSignatureVerificationOptions/jwt`` for those:

```swift
// `highS` is the same signature with s replaced by n - s.
publicKey.isValidSignature(highS, for: message)                  // false
publicKey.isValidSignature(highS, for: message, options: .jwt)   // true
```

``ATProtoSignatureVerificationOptions/allowMalleable`` additionally accepts
DER, matching `allowMalleableSig` in `@atproto/crypto`.

### Import and export private keys

The specification does not mandate a private-key encoding. Raw bytes, hex and
a self-describing multibase form are supported.

```swift
let imported = try K256Keypair(
    hex: "9085d2bef69286a6cbb51623c8fa258629945cd55ca705cc4e66700396894e0c"
)
// imported.didKey == "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"

let raw = imported.exportRawRepresentation()           // 32 bytes
let multibase = try imported.exportMultibase()         // "z…", names its curve
let restored = try ATProtoCrypto.importKeypair(privateMultibase: multibase)
```

Importing rejects anything that is not a scalar in `1 ..< n`.

### Public key encodings

A public key is written as a Multikey: the compressed curve point behind a
multicodec prefix, base58btc-encoded with a `z`. A `did:key` is the same
string with a `did:key:` prefix. Older DID documents use a legacy form with
no prefix and an uncompressed point, where the curve is named by the
verification method's `type`.

```swift
let key = try ATProtoPublicKey(multikey: "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")
key.curve                                              // .k256
key.didKey                                             // "did:key:zQ3shXjH…"

// The same key as an older DID document wrote it.
let legacy = try ATProtoPublicKey(
    verificationMethodType: "EcdsaSecp256k1VerificationKey2019",
    publicKeyMultibase: "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
)
legacy == key                                          // true
```

Every initializer checks that the point is on its curve. A key is stored in
one form, so equal keys compare equal regardless of how they were written.

### Keys that live somewhere else

Anything that can produce a signature can be an ``ATProtoSigner``. Wrap a
remote key service, HSM or hardware token in ``ATProtoExternalSigner``. It
accepts compact or DER output with either S value, converts it to the wire
form, and verifies it against the declared public key before returning, so a
misconfigured backend fails immediately.

```swift
let remote = ATProtoExternalSigner(publicKey: rotationKey) { request in
    // `request.message` is the bytes; `request.sha256Digest` is their hash.
    try await keyService.sign(digest: request.sha256Digest)
}
let operationSignature = try await remote.sign(operationBytes)
```

On Apple devices, `SecureEnclaveP256Signer` keeps a P-256 key inside the
Secure Enclave. The key cannot be exported; persist its `dataRepresentation`.

```swift
if SecureEnclaveP256Signer.isAvailable {
    let enclaveKey = try SecureEnclaveP256Signer.generate()
    let enclaveSignature = try enclaveKey.sign(message)    // low-S, like any other
}
```

### Service-auth tokens

Any signer can mint an inter-service JWT, and any public key can verify one.
JWT verification uses the `.jwt` policy by default.

```swift
let token = try await ServiceJWT.mint(
    issuer: "did:plc:abcdefghijklmnopqrstuvwx",
    audience: "did:web:api.bsky.app",
    method: "com.atproto.repo.getRecord",
    eventID: UUID().uuidString,
    signer: keypair
)
let claims = try ServiceJWT.verify(token, publicKey: keypair.publicKey)
```

## Topics

### Entry points

- ``ATProtoCrypto``
- ``ATProtoSigner``
- ``ATProtoPublicKey``
- ``ATProtoSignatureVerificationOptions``
