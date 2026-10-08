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
}
