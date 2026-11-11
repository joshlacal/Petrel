import Crypto
import Foundation

/// Anything that can produce AT Protocol signatures: an in-memory key, a
/// Secure Enclave key, a cloud KMS, a hardware wallet.
///
/// `sign` is `async` so an implementation can cross a process, device or
/// network boundary. Repository commits, PLC operations and service-auth
/// JWTs are all signed through this one protocol.
///
/// ## Contract
///
/// `sign(_:)` receives the exact bytes to be signed, unhashed. It must
/// return ECDSA over `SHA-256(message)` on ``curve`` as 64 bytes `r || s`
/// with low-S. Implementations backed by a signer that returns DER or does
/// not normalize S should pass its output through
/// ``ATProtoSignature/canonicalize(_:curve:)``, or simply wrap it in
/// ``ATProtoExternalSigner``, which does that and checks the result.
public protocol ATProtoSigner: Sendable {
    /// The curve signatures are produced on.
    var curve: ATProtoKeyCurve { get }

    /// Signs `message`.
    ///
    /// - Parameter message: The bytes to sign. Do not pre-hash.
    /// - Returns: 64-byte compact low-S signature.
    func sign(_ message: Data) async throws -> Data
}

public extension ATProtoSigner {
    /// The JOSE `alg` value for this signer: `ES256` or `ES256K`.
    var jwtAlgorithm: String { curve.jwtAlgorithm }
}

/// A signer that also knows its public key.
public protocol ATProtoKeypair: ATProtoSigner {
    /// The public half of the key.
    var publicKey: ATProtoPublicKey { get }
}

public extension ATProtoKeypair {
    /// The curve of ``publicKey``.
    var curve: ATProtoKeyCurve { publicKey.curve }

    /// The public key as a `did:key` identifier.
    var didKey: String { publicKey.didKey }

    /// The public key as a multikey string.
    var multikey: String { publicKey.multikey }
}

/// A keypair whose private scalar can leave the process.
///
/// Hardware-backed signers deliberately do not conform.
public protocol ATProtoExportableKeypair: ATProtoKeypair {
    /// The 32-byte big-endian private scalar.
    func exportRawRepresentation() throws -> Data
}

public extension ATProtoExportableKeypair {
    /// The private scalar as 64 lowercase hex characters.
    func exportHex() throws -> String {
        try Hex.encode(exportRawRepresentation())
    }

    /// The private scalar as a private multikey: `z` +
    /// base58btc(multicodec varint + scalar), using `p256-priv` (0x1306) or
    /// `secp256k1-priv` (0x1301). Self-describing, so
    /// ``ATProtoCrypto/importKeypair(privateMultibase:)`` can restore the
    /// right curve.
    func exportMultibase() throws -> String {
        try "z" + Base58BTC.encode(curve.privateKeyMulticodecPrefix + exportRawRepresentation())
    }
}

/// Anything that can check an AT Protocol signature.
/// ``ATProtoPublicKey`` is the standard implementation.
public protocol ATProtoVerifier: Sendable {
    /// The curve signatures are expected on.
    var curve: ATProtoKeyCurve { get }

    /// Verifies `signature` over `SHA-256(message)`.
    func isValidSignature(
        _ signature: Data,
        for message: Data,
        options: ATProtoSignatureVerificationOptions
    ) -> Bool
}

extension ATProtoPublicKey: ATProtoVerifier {}

/// Adapts a signing operation that lives outside this process — a remote
/// key service, an HSM, a hardware token — to ``ATProtoSigner``.
///
/// The closure is handed both the message and its SHA-256 digest, so it can
/// feed whichever its backend wants. Whatever comes back (64-byte compact or
/// DER, high- or low-S) is normalized to the wire form and then **verified
/// against the declared public key** before it is returned, so a
/// misconfigured backend (wrong key, wrong hash, double hashing) fails here
/// rather than producing a commit nobody can verify.
///
/// ```swift
/// let signer = ATProtoExternalSigner(publicKey: rotationKey) { request in
///     try await kms.signECDSA(digest: request.sha256Digest)
/// }
/// let signature = try await signer.sign(operationBytes)
/// ```
public struct ATProtoExternalSigner: ATProtoKeypair {
    /// What an external signing operation is asked to sign.
    public struct Request: Sendable, Equatable {
        /// The bytes being signed, unhashed.
        public let message: Data
        /// `SHA-256(message)`, 32 bytes — the value ECDSA actually signs.
        public let sha256Digest: Data
        /// The curve the signature must be on.
        public let curve: ATProtoKeyCurve
    }

    /// The key the external signer is expected to hold.
    public let publicKey: ATProtoPublicKey
    private let operation: @Sendable (Request) async throws -> Data

    /// - Parameters:
    ///   - publicKey: The public key signatures must verify against.
    ///   - sign: Produces an ECDSA signature for the request, as 64-byte
    ///     `r || s` or ASN.1 DER.
    public init(
        publicKey: ATProtoPublicKey,
        sign: @escaping @Sendable (Request) async throws -> Data
    ) {
        self.publicKey = publicKey
        operation = sign
    }

    /// Calls the external operation, normalizes its output, and verifies it.
    ///
    /// - Throws: Whatever the operation throws;
    ///   ``PetrelCryptoError/malformed(_:)`` if the output is not a
    ///   signature; ``PetrelCryptoError/unauthorized(_:)`` if it does not
    ///   verify against ``publicKey``.
    public func sign(_ message: Data) async throws -> Data {
        let request = Request(
            message: message,
            sha256Digest: Data(SHA256.hash(data: message)),
            curve: publicKey.curve
        )
        let produced = try await operation(request)
        let canonical = try ATProtoSignature.canonicalize(produced, curve: publicKey.curve)
        guard publicKey.isValidSignature(canonical, for: message) else {
            throw PetrelCryptoError.unauthorized(
                "external signer returned a signature that does not verify against its public key"
            )
        }
        return canonical
    }
}
