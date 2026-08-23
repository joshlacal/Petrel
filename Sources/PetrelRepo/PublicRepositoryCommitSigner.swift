import Crypto
import Foundation
import PetrelCrypto

/// The repository commit codec is deliberately independent of account-key
/// lookup and of any particular signature implementation.
public enum PublicRepositorySigningAlgorithm: String, Sendable, Equatable {
    case p256
    case secp256k1
}

public protocol PublicRepositoryCommitSigner: Sendable {
    var signingAlgorithm: PublicRepositorySigningAlgorithm { get }

    /// Signs the exact canonical unsigned commit bytes. Implementations must
    /// not pre-hash these bytes before calling an ECDSA message-signing API.
    func sign(unsignedCommitBytes: Data) async throws -> Data
}

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

/// Swan's current account repository-key adapter.
// Swift Crypto's P256 key wrappers are immutable but are not annotated
// Sendable on the Linux toolchain used by the Compose builder. The signer only
// captures the key and invokes the pure signing operation, so assert that
// immutable ownership at the protocol boundary.
public struct P256PublicRepositoryCommitSigner: @unchecked Sendable, PublicRepositoryCommitSigner {
    public let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    private let privateKey: P256.Signing.PrivateKey

    public init(privateKey: P256.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    public func sign(unsignedCommitBytes: Data) async throws -> Data {
        try P256WireSignature.sign(unsignedCommitBytes, using: privateKey)
    }
}

/// A verifier for an already-resolved P-256 repository signing key. DID
/// resolution and key rotation remain outside this pure repository target.
public struct P256PublicRepositoryCommitVerifier: @unchecked Sendable, PublicRepositoryCommitVerifier {
    public let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    public let verificationIdentity: String
    private let publicKey: P256.Signing.PublicKey

    public init(publicKey: P256.Signing.PublicKey) {
        self.publicKey = publicKey
        let digest = SHA256.hash(data: publicKey.x963Representation)
        self.verificationIdentity = "p256-sha256:\(Hex.encode(digest))"
    }

    public func verify(
        signature: Data,
        unsignedCommitBytes: Data,
        did _: String
    ) async throws {
        let decoded = try P256WireSignature.decodeCanonical(signature)
        guard publicKey.isValidSignature(decoded, for: unsignedCommitBytes) else {
            throw PublicRepositoryCommitError.invalidSignature
        }
    }
}
