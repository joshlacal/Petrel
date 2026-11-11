# ``PetrelCrypto``

AT Protocol cryptography: key generation, signing and signature verification on P-256 and K-256.

## Overview

AT Protocol authenticates public data with ECDSA on two curves, `p256` and
`k256` (secp256k1), and expects implementations to support both. This module
implements the [Cryptography specification](https://atproto.com/specs/cryptography)
on Apple platforms and Linux:

- generate, import and export private keys on either curve;
- sign with SHA-256 and ECDSA, always producing the 64-byte compact,
  low-S signature the protocol requires;
- verify strictly by default, with an explicit lax mode for JWTs;
- encode and decode public keys as `did:key`, Multikey, and the legacy
  multibase form found in older DID documents;
- plug in a Secure Enclave key or a remote signer behind one protocol.

`import Petrel` re-exports this module; `import PetrelCrypto` uses it on its
own. Start with <doc:Cryptography>.

## Topics

### Essentials

- <doc:Cryptography>
- ``ATProtoCrypto``
- ``ATProtoKeyCurve``

### Keys and signers

- ``ATProtoSigner``
- ``ATProtoKeypair``
- ``ATProtoExportableKeypair``
- ``K256Keypair``
- ``P256Keypair``
- ``ATProtoExternalSigner``

### Public keys and verification

- ``ATProtoPublicKey``
- ``ATProtoVerifier``
- ``ATProtoSignatureVerificationOptions``
- ``ATProtoSignature``

### Service authentication

- <doc:ServiceAuth>
- ``ServiceAuthVerifier``
- ``ServiceJWT``
- ``ServiceJWTClaims``
- ``ServiceJWTInspection``

### Encodings

- ``Base58BTC``
- ``Hex``
- ``JWTBase64URL``

### Errors

- ``PetrelCryptoError``

### Curve-specific and earlier API

These types predate the curve-agnostic API above and remain supported.

- ``P256WireSignature``
- ``PLCDIDKeyCodec``
- ``PLCDIDVerificationKey``
- ``ATProtoJWTVerificationKey``
- ``P256DIDKey``
- ``ServiceJWTSigningKey``
