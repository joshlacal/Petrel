import Crypto
import Foundation
import PetrelCrypto

/// The curve a repository commit is signed on.
///
/// AT Protocol requires implementations to support both. This mirrors
/// `ATProtoKeyCurve` from `PetrelCrypto`; convert with ``curve`` and
/// ``init(_:)``.
public enum PublicRepositorySigningAlgorithm: String, Sendable, Equatable {
    /// NIST P-256 (`ES256`).
    case p256
    /// secp256k1 (`ES256K`), the curve most accounts on the network use.
    case secp256k1

    /// The matching `PetrelCrypto` curve.
    public var curve: ATProtoKeyCurve {
        switch self {
        case .p256: return .p256
        case .secp256k1: return .k256
        }
    }

    /// The algorithm for a `PetrelCrypto` curve.
    public init(_ curve: ATProtoKeyCurve) {
        switch curve {
        case .p256: self = .p256
        case .k256: self = .secp256k1
        }
    }
}

/// Signs repository commits with any `ATProtoSigner`: an in-memory
/// `K256Keypair` or `P256Keypair`, a Secure Enclave key, or an
/// `ATProtoExternalSigner` wrapping a KMS.
///
/// ```swift
/// let signer = ATProtoRepositoryCommitSigner(K256Keypair.generate())
/// ```
public struct ATProtoRepositoryCommitSigner: PublicRepositoryCommitSigner {
    private let signer: any ATProtoSigner

    /// Wraps `signer`.
    public init(_ signer: any ATProtoSigner) {
        self.signer = signer
    }

    public var signingAlgorithm: PublicRepositorySigningAlgorithm {
        PublicRepositorySigningAlgorithm(signer.curve)
    }

    public func sign(unsignedCommitBytes: Data) async throws -> Data {
        try await signer.sign(unsignedCommitBytes)
    }
}

/// Verifies repository commits against one already-resolved public key on
/// either curve.
///
/// This is the shipped verifier for the common case where the caller has
/// taken the account's `#atproto` key from its DID document. For
/// resolve-and-retry behaviour use
/// ``PublicRepositoryCommitCodec/verify(signedCommitBytes:expectedCommitCID:keyResolver:expectedDID:)``.
public struct ATProtoRepositoryCommitVerifier: PublicRepositoryCommitVerifier {
    /// The key commits are checked against.
    public let publicKey: ATProtoPublicKey

    /// Creates a verifier for `publicKey`.
    public init(publicKey: ATProtoPublicKey) {
        self.publicKey = publicKey
    }

    /// Creates a verifier from a `did:key` string.
    public init(didKey: String) throws {
        publicKey = try ATProtoPublicKey(didKey: didKey)
    }

    public var signingAlgorithm: PublicRepositorySigningAlgorithm {
        PublicRepositorySigningAlgorithm(publicKey.curve)
    }

    /// The key's `did:key` form.
    public var verificationIdentity: String { publicKey.didKey }

    public func verify(
        signature: Data,
        unsignedCommitBytes: Data,
        did _: String
    ) async throws {
        guard publicKey.isValidSignature(signature, for: unsignedCommitBytes, options: .strict) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }
}

/// Produces the signature of a repository commit.
public protocol PublicRepositoryCommitSigner: Sendable {
    var signingAlgorithm: PublicRepositorySigningAlgorithm { get }

    /// Signs the exact canonical unsigned commit bytes. Implementations must
    /// not pre-hash these bytes before calling an ECDSA message-signing API.
    func sign(unsignedCommitBytes: Data) async throws -> Data
}

/// Checks the signature of a repository commit against one key.
public protocol PublicRepositoryCommitVerifier: Sendable {
    var signingAlgorithm: PublicRepositorySigningAlgorithm { get }
    /// Stable identity derived from the exact resolved verification key.
    /// Import callers bind this value before accepting any CAR bytes.
    var verificationIdentity: String { get }

    func verify(
        signature: Data,
        unsignedCommitBytes: Data,
        did: String
    ) async throws
}

/// A commit signer over a Swift Crypto P-256 private key. Prefer
/// ``ATProtoRepositoryCommitSigner``, which accepts either curve.
public struct P256PublicRepositoryCommitSigner: PublicRepositoryCommitSigner {
    public let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    // Swift Crypto's key types are not `Sendable` on Linux. `P256Keypair`
    // holds the same key as plain bytes and is.
    private let keypair: P256Keypair

    public init(privateKey: P256.Signing.PrivateKey) {
        keypair = P256Keypair(privateKey)
    }

    public func sign(unsignedCommitBytes: Data) async throws -> Data {
        try keypair.sign(unsignedCommitBytes)
    }
}

/// A verifier for an already-resolved Swift Crypto P-256 key. Prefer
/// ``ATProtoRepositoryCommitVerifier``, which accepts either curve.
public struct P256PublicRepositoryCommitVerifier: PublicRepositoryCommitVerifier {
    public let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    public let verificationIdentity: String
    private let publicKey: ATProtoPublicKey

    public init(publicKey: P256.Signing.PublicKey) {
        self.publicKey = ATProtoPublicKey(publicKey)
        let digest = SHA256.hash(data: publicKey.x963Representation)
        self.verificationIdentity = "p256-sha256:\(Hex.encode(digest))"
    }

    public func verify(
        signature: Data,
        unsignedCommitBytes: Data,
        did _: String
    ) async throws {
        guard publicKey.isValidSignature(signature, for: unsignedCommitBytes, options: .strict) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }
}
