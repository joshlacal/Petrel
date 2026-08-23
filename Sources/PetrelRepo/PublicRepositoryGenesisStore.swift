import Crypto
import Foundation

/// Public facts persisted for the deliberately narrow empty-repository
/// substrate. The timestamp records when Swan made the immutable genesis
/// visible in the per-account repository database; it is not account-control
/// state and must never be used as an authorization decision by itself.
public struct PersistedPublicRepositoryGenesis: Sendable, Equatable {
    public let genesis: PublicRepositoryGenesis
    public let installedAt: Date

    public init(genesis: PublicRepositoryGenesis, installedAt: Date) throws {
        let timestamp = installedAt.timeIntervalSince1970 * 1_000_000
        guard timestamp.isFinite, timestamp >= 0, timestamp <= Double(Int.max) else {
            throw PublicRepositoryGenesisStoreError.invalidTimestamp
        }
        self.genesis = genesis
        self.installedAt = installedAt
    }
}

/// The outcome of an immutable genesis installation. A caller must not infer
/// account activation from either result: control-plane registration is a
/// separate durable operation which happens only after this state exists.
public struct PublicRepositoryGenesisInstallation: Sendable, Equatable {
    public let persisted: PersistedPublicRepositoryGenesis
    public let wasAlreadyInstalled: Bool

    public init(
        persisted: PersistedPublicRepositoryGenesis,
        wasAlreadyInstalled: Bool
    ) {
        self.persisted = persisted
        self.wasAlreadyInstalled = wasAlreadyInstalled
    }
}

/// Fail-closed outcomes for a store that owns one account's public genesis.
/// Detailed SQLite and CAR errors remain internal to the adapter so callers
/// do not receive repository bytes through an error channel.
public enum PublicRepositoryGenesisStoreError: Error, Sendable, Equatable {
    case ownershipMismatch
    case conflictingGenesis
    case corruptStoredGenesis
    case invalidTimestamp
}

/// Domain-shaped persistence boundary for the public empty-repository
/// genesis. Implementations verify both new and loaded CARs under the
/// caller-supplied P-256 signing public key; a generic key-value store would
/// make it too easy to persist an unchecked repository root.
public protocol PublicRepositoryGenesisStore: Sendable {
    /// Atomically installs `candidate` if absent, or returns the existing
    /// immutable genesis when it is byte-for-byte the same verified CAR.
    /// A different candidate never replaces stored repository truth.
    func installPublicRepositoryGenesis(
        _ candidate: PublicRepositoryGenesis,
        signingPublicKey: P256.Signing.PublicKey,
        installedAt: Date
    ) async throws -> PublicRepositoryGenesisInstallation

    /// Loads and verifies the stored genesis. `nil` means this account has no
    /// public genesis; any malformed/tampered stored state is an error rather
    /// than an opportunity to repair it implicitly.
    func loadPublicRepositoryGenesis(
        did: String,
        signingPublicKey: P256.Signing.PublicKey
    ) async throws -> PersistedPublicRepositoryGenesis?
}
