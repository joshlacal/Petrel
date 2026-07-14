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

/// The result of executing an operation while an exact authentication
/// continuity snapshot remains serialized against in-process mutations.
public enum AuthContinuityTransactionResult<Value: Sendable>: Sendable {
    case performed(Value)
    case continuityChanged
}

final class ExactAuthGeneratedRequestScopeState: @unchecked Sendable {
    private let lock = NSLock()
    private var launchClaimed = false
    private var responseCompleted = false
    private var continuityFailed = false

    func claimLaunch() -> Bool {
        lock.withLock {
            guard !launchClaimed, !continuityFailed else { return false }
            launchClaimed = true
            return true
        }
    }

    func failContinuity() {
        lock.withLock { continuityFailed = true }
    }

    func completeResponse() -> Bool {
        lock.withLock {
            guard launchClaimed, !responseCompleted, !continuityFailed else { return false }
            responseCompleted = true
            return true
        }
    }

    var completedExactlyOneResponse: Bool {
        lock.withLock { launchClaimed && responseCompleted && !continuityFailed }
    }
}

struct ExactAuthRequestOrigin: Equatable {
    let scheme: String
    let host: String
    let effectivePort: Int

    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil,
              components.password == nil
        else {
            return nil
        }
        scheme = "https"
        self.host = host
        effectivePort = components.port ?? 443
    }
}

struct ExactAuthGeneratedRequestScope {
    let id: UUID
    let expected: AuthContinuitySnapshot
    let networkServiceID: UUID
    let origin: ExactAuthRequestOrigin
    let destinationGeneration: UUID
    let state: ExactAuthGeneratedRequestScopeState
}

enum ExactAuthGeneratedRequestScopeContext {
    @TaskLocal static var current: ExactAuthGeneratedRequestScope?
}

struct ExactAuthGeneratedRequestContinuityError: Error {}

enum AuthContinuityProviderSnapshot {
    case stable(AuthContinuitySnapshot)
    case mutationPending(mode: AuthMode)
}

protocol AuthContinuityProviding: AnyObject, AuthenticationProvider {
    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async
    func authContinuitySnapshot() async -> AuthContinuitySnapshot
    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot
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

    func wouldChangeWhenObservingGatewayIdentity(_ identity: GatewayAuthIdentity?) -> Bool {
        guard mode == .gateway, !isExhausted else { return false }
        guard case let .observed(previous) = observation else { return false }
        return previous != identity
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

    /// Executes a synchronous operation only while `expected` is the exact
    /// current authentication continuity snapshot. Petrel-mediated auth
    /// mutations cannot become observable until the operation returns.
    ///
    /// The operation must not block or call back into Petrel. It cannot suspend.
    func performWithExactAuthContinuity<Value: Sendable>(
        matching expected: AuthContinuitySnapshot,
        _ operation: @Sendable () -> Value
    ) async -> AuthContinuityTransactionResult<Value> {
        await networkService.performWithExactAuthContinuity(
            matching: expected,
            operation
        )
    }

    /// Executes one directly-awaited generated API operation under an exact
    /// authentication request scope.
    ///
    /// The generated operation must be awaited directly and must issue exactly
    /// one request. Child tasks inherit the scope and remain fail-closed. Do not
    /// escape work from `operation`; detached work has no scope and is rejected
    /// while this scope owns the network service.
    func performGeneratedRequestWithExactAuthContinuity<Value: Sendable>(
        matching expected: AuthContinuitySnapshot,
        _ operation: @Sendable () async throws -> Value
    ) async throws -> AuthContinuityTransactionResult<Value> {
        let serviceID = networkService.exactAuthRequestScopeServiceID

        if let current = ExactAuthGeneratedRequestScopeContext.current {
            guard current.expected == expected,
                  current.networkServiceID == serviceID,
                  await networkService.isExactAuthGeneratedRequestScopeActive(current)
            else {
                current.state.failContinuity()
                return .continuityChanged
            }

            do {
                let value = try await operation()
                return await networkService.isExactAuthGeneratedRequestScopeActive(current)
                    && current.state.completedExactlyOneResponse
                    ? .performed(value)
                    : .continuityChanged
            } catch is ExactAuthGeneratedRequestContinuityError {
                current.state.failContinuity()
                return .continuityChanged
            }
        }

        let state = ExactAuthGeneratedRequestScopeState()
        guard let scope = await networkService.beginExactAuthGeneratedRequestScope(
            id: UUID(),
            expected: expected,
            state: state
        ) else {
            return .continuityChanged
        }

        do {
            let value = try await ExactAuthGeneratedRequestScopeContext.$current.withValue(scope) {
                try await operation()
            }
            await networkService.endExactAuthGeneratedRequestScope(scope)
            return scope.state.completedExactlyOneResponse
                ? .performed(value)
                : .continuityChanged
        } catch is ExactAuthGeneratedRequestContinuityError {
            scope.state.failContinuity()
            await networkService.endExactAuthGeneratedRequestScope(scope)
            return .continuityChanged
        } catch {
            await networkService.endExactAuthGeneratedRequestScope(scope)
            throw error
        }
    }
}
