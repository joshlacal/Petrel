import Foundation
import Petrel
import PetrelCrypto

/// `IdentityResolver` as the key source for commit verification.
///
/// The sync specification has a consumer resolve the account's identity,
/// take the `#atproto` key from its DID document, and resolve again once if
/// a signature fails, to pick up a key rotation. The identity resolver
/// already does exactly that: `forceRefresh: true` re-reads the DID
/// document. It caches documents, but a forced refresh always reaches the
/// network, and anyone can put a bad signature on a firehose or into a CAR.
/// For untrusted input, wrap it in `CachingServiceAuthKeyResolver`, which
/// also conforms and limits forced refreshes per DID:
///
/// ```swift
/// let keys = CachingServiceAuthKeyResolver(upstream: IdentityResolver())
/// let diff = try await RepositoryCommitDiff.verifyCommitEvent(
///     blocks: event.blocks, commitCID: event.commitCID, did: event.repo,
///     revision: event.rev, operations: operations,
///     previousDataCID: previousDataCID, keyResolver: keys
/// )
/// ```
extension IdentityResolver: RepositorySigningKeyResolver {}

/// `CachingServiceAuthKeyResolver` as the key source for commit verification:
/// cached keys, with forced refreshes rate-limited per DID. See
/// the `IdentityResolver` conformance for the usual setup.
extension CachingServiceAuthKeyResolver: RepositorySigningKeyResolver {}
