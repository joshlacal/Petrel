#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation

/// A non-secret value that binds work to the current authentication principal
/// and gateway-session continuity.
///
/// The opaque gateway session identifier never crosses this API. Callers should
/// compare the complete value before and after suspension points and discard
/// security-sensitive work whenever it changes.
public struct AuthContinuitySnapshot: Equatable, Sendable {
    /// The authenticated gateway principal, or `nil` when no live gateway
    /// session has been observed.
    public let did: String?

    /// The authentication mode represented by this snapshot.
    public let mode: AuthMode

    /// An in-memory generation that changes whenever authentication continuity
    /// may have changed. It is intentionally not persisted across client launches.
    public let generation: UInt64

    public init(did: String?, mode: AuthMode, generation: UInt64) {
        self.did = did
        self.mode = mode
        self.generation = generation
    }
}

protocol AuthContinuityProviding: AnyObject, AuthenticationProvider {
    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async
    func authContinuitySnapshot() async -> AuthContinuitySnapshot
}

struct GatewayAuthIdentity: Equatable {
    let did: String
    private let sessionFingerprint: [UInt8]

    init(did: String, session: String) {
        self.did = did
        sessionFingerprint = Array(SHA256.hash(data: Data(session.utf8)))
    }
}

struct AuthContinuityState {
    private enum Observation: Equatable {
        case unobserved
        case invalidated
        case observed(GatewayAuthIdentity?)
    }

    private(set) var mode: AuthMode
    private(set) var generation: UInt64
    private(set) var isExhausted: Bool
    private var observation: Observation

    init(mode: AuthMode) {
        self.mode = mode
        generation = 0
        isExhausted = false
        observation = .unobserved
    }

    init(
        mode: AuthMode,
        generation: UInt64,
        observedGatewayIdentity: GatewayAuthIdentity?
    ) {
        self.mode = mode
        self.generation = generation
        isExhausted = false
        observation = .observed(observedGatewayIdentity)
    }

    var snapshot: AuthContinuitySnapshot {
        let did: String? = if isExhausted || mode != .gateway {
            nil
        } else if case let .observed(identity) = observation {
            identity?.did
        } else {
            nil
        }

        return AuthContinuitySnapshot(did: did, mode: mode, generation: generation)
    }

    /// Invalidates the current continuity before an operation can suspend.
    /// Exhaustion permanently removes the principal instead of wrapping and
    /// accidentally making two distinct authentication states compare equal.
    mutating func invalidate() {
        observation = .invalidated
        guard !isExhausted else { return }
        guard generation < .max else {
            isExhausted = true
            return
        }
        generation += 1
    }

    mutating func commitMode(_ newMode: AuthMode) {
        mode = newMode
        if newMode != .gateway {
            observation = .invalidated
        }
    }

    /// Reconciles the private underlying identity with the last observation.
    /// Tracked mutations have already incremented the generation and leave the
    /// state in `.invalidated`; out-of-band replacements increment here.
    mutating func observeGatewayIdentity(_ identity: GatewayAuthIdentity?) {
        guard mode == .gateway, !isExhausted else { return }

        switch observation {
        case .unobserved, .invalidated:
            observation = .observed(identity)
        case let .observed(previous) where previous != identity:
            invalidate()
            if !isExhausted {
                observation = .observed(identity)
            }
        case .observed:
            break
        }
    }
}

public extension ATProtoClient {
    /// Returns a non-secret snapshot of the client's authentication continuity.
    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        if let snapshot = await networkService.authContinuitySnapshot() {
            return snapshot
        }
        return AuthContinuitySnapshot(did: nil, mode: authMode, generation: 0)
    }
}
