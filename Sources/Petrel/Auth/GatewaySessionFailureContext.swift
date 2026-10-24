import Foundation
import Crypto

/// Non-secret proof of one gateway credential rejection. A queued failure must
/// be revalidated before changing UI state; a DID alone cannot identify a session.
public struct GatewaySessionFailureContext: Sendable, Equatable {
    public let did: String
    let storageScope: AccountMutationHub.ScopeDID
    let generation: UInt64
    private let expectedSessionFingerprint: [UInt8]?

    init(did: String, storageScope: AccountMutationHub.ScopeDID,
         generation: UInt64, expectedSession: String?) {
        self.did = did
        self.storageScope = storageScope
        self.generation = generation
        self.expectedSessionFingerprint = expectedSession.map { Array(SHA256.hash(data: Data($0.utf8))) }
    }

    func matchesSession(_ session: String?) -> Bool {
        let fingerprint = session.map { Array(SHA256.hash(data: Data($0.utf8))) }
        return fingerprint == expectedSessionFingerprint
    }
}

// Carries proof without adding a publicly constructible credential or changing
// the existing GatewayError cases used by direct strategy callers.
struct ScopedGatewaySessionRejection: Error {
    let context: GatewaySessionFailureContext
    let reason: String
}

public extension ATProtoClient {
    /// False for another account, a replaced credential, another storage scope,
    /// or unreadable storage. No provider request or credential removal occurs.
    func isCurrentGatewaySessionFailure(_ context: GatewaySessionFailureContext) async -> Bool {
        await networkService.isCurrentGatewaySessionFailure(context)
    }

    /// Revalidates an exact rejection and performs a synchronous UI transition while
    /// holding the process-local gateway credential and account-selection mutation gate.
    /// Same-process session replacement cannot interleave between validation and `perform`.
    /// External-process storage writes and authentication mode/provider reconfiguration
    /// are outside this gate; callers must also preserve their own UI/client continuity.
    /// The callback must only update UI state: do not call the SDK, wait for work, or
    /// perform cleanup from it. Run any async cleanup after this method returns.
    /// Returns whether the proof remained current and the callback was invoked.
    func withCurrentGatewaySessionFailure(
        _ context: GatewaySessionFailureContext,
        perform: @MainActor @Sendable () -> Void
    ) async -> Bool {
        await networkService.withCurrentGatewaySessionFailure(context, perform: perform)
    }
}
