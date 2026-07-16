//
//  AuthEventBroadcaster.swift
//  Petrel
//
//  Created by Claude on 11/27/24.
//

import Foundation
import Synchronization

/// Authentication event types that can be observed by the application layer
public enum AuthEvent: Sendable, Equatable {
    // MARK: - Startup & Recovery Events

    /// Detected inconsistent state during startup (account exists without valid session)
    case startupInconsistentState(did: String, hasAccount: Bool, hasSession: Bool, hasDPoPKey: Bool)

    /// Missing session for account during startup
    case startupMissingSession(did: String, hasDPoPKey: Bool)

    /// Missing DPoP key for account during startup
    case startupMissingDPoPKey(did: String, hasSession: Bool)

    /// Startup authentication state is healthy
    case startupStateHealthy(did: String)

    // MARK: - Account Switching Events

    /// Account auto-switched after removal of current account
    case accountAutoSwitched(previousDid: String, newDid: String?, reason: String)

    /// Current account changed by user action
    case currentAccountChanged(previousDid: String?, newDid: String)

    // MARK: - Session & Token Events

    /// Session missing for account during operation
    case sessionMissing(did: String, context: String)

    /// Refresh token invalid (401 invalid_grant)
    case refreshTokenInvalid(did: String, statusCode: Int, error: String)

    /// Invalid client metadata error during token refresh
    case invalidClientMetadata(did: String, statusCode: Int, error: String)

    /// Invalid client error during token refresh
    case invalidClient(did: String, statusCode: Int, error: String)

    /// DPoP nonce mismatch during refresh
    case dpopNonceMismatch(did: String, retryAttempt: Int)

    // MARK: - Logout Events

    /// Logout process started
    case logoutStarted(did: String, reason: String?)

    /// Account auto-switched after logout
    case logoutAutoSwitched(previousDid: String, newDid: String)

    /// No account available after logout (user needs to log in)
    case logoutNoAutoSwitch(did: String)

    /// Logout cleared current account
    case logoutClearedCurrentAccount(previousDid: String)

    /// Auto-logout triggered due to unrecoverable auth error
    case autoLogoutTriggered(did: String, reason: String)

    // MARK: - Error Events

    /// Account not found during set current account
    case accountNotFound(did: String)

    /// No session available when setting current account
    case setCurrentAccountNoSession(did: String)

    /// Failed to store current account DID
    case storageFailure(did: String, error: String)

    /// Inconsistent auth state detected - missing session
    case inconsistentStateMissingSession(did: String)

    /// Inconsistent auth state detected - missing account
    case inconsistentStateMissingAccount(did: String)
}

/// Actor-based broadcaster for authentication events with observer pattern
public actor AuthEventBroadcaster {
    public typealias Observer = @Sendable (AuthEvent) async -> Void

    private var observers: [Observer] = []

    public static let shared = AuthEventBroadcaster()

    private init() {}

    /// Add an observer to receive authentication events
    /// - Parameter observer: Closure called when auth events occur
    public func addObserver(_ observer: @escaping Observer) {
        observers.append(observer)
    }

    /// Remove all observers (useful for testing)
    public func removeAllObservers() {
        observers.removeAll()
    }

    /// Broadcast an authentication event to all observers
    /// - Parameter event: The authentication event to broadcast
    func broadcast(_ event: AuthEvent) async {
        let currentObservers = observers
        for observer in currentObservers {
            await observer(event)
        }
    }
}

/// Public API for subscribing to Petrel authentication events
public enum PetrelAuthEvents {
    private struct DeliveryState {
        var generation: UInt = 0
        var tail: Task<Void, Never>?
    }

    private static let deliveryState = Mutex(DeliveryState())

    /// Add an observer to receive authentication events
    /// - Parameter observer: Closure called when auth events occur
    ///
    /// Example usage:
    /// ```swift
    /// PetrelAuthEvents.addObserver { event in
    ///     switch event {
    ///     case .autoLogoutTriggered(let did, let reason):
    ///         await handleAutoLogout(did: did, reason: reason)
    ///     case .refreshTokenInvalid:
    ///         await showReauthenticationPrompt()
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public static func addObserver(_ observer: @escaping @Sendable (AuthEvent) async -> Void) {
        Task {
            await AuthEventBroadcaster.shared.addObserver(observer)
        }
    }

    /// Add an observer and return only after registration is complete.
    ///
    /// Await this overload when events may be emitted immediately after registration.
    public static func addObserver(_ observer: @escaping @Sendable (AuthEvent) async -> Void) async {
        await AuthEventBroadcaster.shared.addObserver(observer)
    }

    /// Remove all observers (primarily for testing)
    public static func removeAllObservers() {
        Task {
            await AuthEventBroadcaster.shared.removeAllObservers()
        }
    }

    /// Remove all observers after delivering events that were already enqueued.
    public static func removeAllObservers() async {
        await drain()
        await AuthEventBroadcaster.shared.removeAllObservers()
    }

    /// Wait until every authentication event enqueued before this method's final
    /// queue-state check has completed delivery to the registered observers.
    ///
    /// An event enqueued concurrently after that check requires another drain. Do
    /// not call this method from an authentication event observer.
    public static func drain() async {
        while true {
            let snapshot = deliveryState.withLock { state in
                (state.generation, state.tail)
            }
            await snapshot.1?.value

            let isStable = deliveryState.withLock { state in
                state.generation == snapshot.0
            }
            if isStable {
                return
            }
        }
    }

    /// Enqueue an event synchronously so a subsequent ``drain()`` observes it.
    static func broadcast(_ event: AuthEvent) {
        deliveryState.withLock { state in
            let predecessor = state.tail
            let delivery = Task(priority: .high) {
                await predecessor?.value
                await AuthEventBroadcaster.shared.broadcast(event)
            }
            state.generation &+= 1
            state.tail = delivery
        }
    }
}
