//
//  KeychainStorage.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Crypto
import Foundation
import Synchronization
enum AuthContinuityStorageMutationEvent {
    case willMutate(UUID)
    case didMutate(UUID)
}

private actor AuthContinuityObserverMailbox {
    private let observer: @Sendable (AuthContinuityStorageMutationEvent) async -> Void
    private var deliveryTail: (id: UUID, task: Task<Void, Never>)?

    init(observer: @escaping @Sendable (AuthContinuityStorageMutationEvent) async -> Void) {
        self.observer = observer
    }

    func deliver(_ event: AuthContinuityStorageMutationEvent) async {
        await deliver([event])
    }

    func deliver(_ events: [AuthContinuityStorageMutationEvent]) async {
        guard !events.isEmpty else { return }

        var previous = deliveryTail?.task
        var finalID: UUID?
        for event in events {
            let predecessor = previous
            let observer = observer
            let id = UUID()
            let task = Task {
                if let predecessor {
                    await predecessor.value
                }
                await observer(event)
            }
            deliveryTail = (id, task)
            previous = task
            finalID = id
        }
        await previous?.value
        if deliveryTail?.id == finalID {
            deliveryTail = nil
        }
    }
}

private actor AuthContinuityMutationHub {
    struct Scope: Hashable {
        let namespace: String
        let accessGroup: String?
    }

    static let shared = AuthContinuityMutationHub()

    private var observers: [Scope: [UUID: AuthContinuityObserverMailbox]] = [:]
    private var activeTickets: [Scope: [UUID]] = [:]

    func replaceObserver(
        _ previousToken: UUID?,
        for scope: Scope,
        observer: @escaping @Sendable (AuthContinuityStorageMutationEvent) async -> Void
    ) async -> UUID {
        if let previousToken {
            observers[scope]?.removeValue(forKey: previousToken)
        }
        let token = UUID()
        let mailbox = AuthContinuityObserverMailbox(observer: observer)
        observers[scope, default: [:]][token] = mailbox

        // Registration and the active-ticket snapshot are one hub operation.
        // Mailbox isolation preserves will-before-did ordering if completion
        // re-enters this hub while a replay callback is suspended.
        let replay = activeTickets[scope, default: []].map(AuthContinuityStorageMutationEvent.willMutate)
        await mailbox.deliver(replay)
        return token
    }

    func beginMutation(for scope: Scope) async -> UUID {
        let ticket = UUID()
        activeTickets[scope, default: []].append(ticket)
        let mailboxes = Array(observers[scope, default: [:]].values)
        for mailbox in mailboxes {
            await mailbox.deliver(.willMutate(ticket))
        }
        return ticket
    }

    func endMutation(_ ticket: UUID, for scope: Scope) async {
        activeTickets[scope, default: []].removeAll { $0 == ticket }
        let mailboxes = Array(observers[scope, default: [:]].values)
        for mailbox in mailboxes {
            await mailbox.deliver(.didMutate(ticket))
        }
    }
}

/// Mutation hub for synchronous DPoP generation bumps and awaited cache invalidation.
public final class DPoPKeyMutationHub: @unchecked Sendable {
    private let lock = NSLock()
    private var observers: [UUID: @Sendable (String?) async -> Void] = [:]
    private var generations: [String: UInt64] = [:]

    public init() {}

    @discardableResult
    public func addObserver(_ observer: @escaping @Sendable (String?) async -> Void) -> UUID {
        let id = UUID()
        lock.withLock {
            observers[id] = observer
        }
        return id
    }

    public func removeObserver(_ id: UUID) {
        lock.withLock {
            _ = observers.removeValue(forKey: id)
        }
    }

    /// Bumps synchronously, before storage mutation; no suspension is permitted between
    /// this call and the underlying keychain operation.
    public func bumpGeneration(for did: String) {
        lock.withLock {
            generations[did, default: 0] += 1
        }
    }

    public func generation(for did: String) -> UInt64 {
        lock.withLock { generations[did, default: 0] }
    }

    /// Delivers invalidation after storage has committed so readers cannot retain a
    /// value installed while the mutation was suspended.
    public func notifyKeyMutation(for did: String?) async {
        let currentObservers: [@Sendable (String?) async -> Void] = lock.withLock {
            Array(observers.values)
        }
        for observer in currentObservers {
            await observer(did)
        }
    }
}

/// Mutation hub for synchronous Account generation bumps and awaited cache invalidation across AccountManager instances.
public final class AccountMutationHub: @unchecked Sendable {
    public struct ScopeDID: Hashable, Sendable {
        public let namespace: String
        public let accessGroup: String?
        public let did: String

        public init(namespace: String, accessGroup: String? = nil, did: String) {
            self.namespace = namespace
            self.accessGroup = accessGroup
            self.did = did
        }
    }

    private let lock = NSLock()
    private var observers: [UUID: @Sendable (ScopeDID?) async -> Void] = [:]
    private var generations: [ScopeDID: UInt64] = [:]
    private var globalEpoch: UInt64 = 0

    public static let shared = AccountMutationHub()

    public init() {}

    public func nextEpoch() -> UInt64 {
        lock.withLock {
            globalEpoch += 1
            return globalEpoch
        }
    }

    @discardableResult
    public func bumpGeneration(for scopeDID: ScopeDID) -> UInt64 {
        lock.withLock {
            globalEpoch += 1
            if generations.count >= 500 {
                generations.removeAll()
            }
            generations[scopeDID] = globalEpoch
            return globalEpoch
        }
    }
    public func generation(for scopeDID: ScopeDID) -> UInt64 {
        lock.withLock {
            if let gen = generations[scopeDID] {
                return gen
            }
            globalEpoch += 1
            if generations.count >= 500 {
                generations.removeAll()
            }
            generations[scopeDID] = globalEpoch
            return globalEpoch
        }
    }

    @discardableResult
    public func addObserver(_ observer: @escaping @Sendable (ScopeDID?) async -> Void) -> UUID {
        let id = UUID()
        lock.withLock {
            observers[id] = observer
        }
        return id
    }

    public func removeObserver(_ id: UUID) {
        lock.withLock {
            _ = observers.removeValue(forKey: id)
        }
    }

    public func notifyMutation(for scopeDID: ScopeDID?) async {
        let currentObservers: [@Sendable (ScopeDID?) async -> Void] = lock.withLock {
            Array(observers.values)
        }
        for observer in currentObservers {
            await observer(scopeDID)
        }
    }
}
private final class AsyncSerialGate: @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isLocked = false

    func acquire() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if !isLocked {
                isLocked = true
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            lock.unlock()
            next.resume()
        } else {
            isLocked = false
            lock.unlock()
        }
    }
}

/// A centralized storage layer for securely storing all persistent data using the keychain.
public actor KeychainStorage {
    let namespace: String
    private let accessGroup: String?
    private let gatewaySessionMutationGate = AsyncSerialGate()
    /// Observers notified when DPoP key material changes in storage for a DID (or nil for all DIDs).
    public static let dpopKeyMutationHub = DPoPKeyMutationHub()
    private struct PendingSessionState {
        var knownGenerations: [String: UInt64] = [:]
    }
    private static let pendingSessionState = Mutex<PendingSessionState>(PendingSessionState())
    private static let inFlightMigrationClaims = Mutex<Set<String>>([])
    private static let completedMigrationHistory = Mutex<Set<String>>([])
    private static let maxMigrationHistorySize = 200

    private static func retireMigrationClaim(_ gKey: String, completed: Bool) {
        inFlightMigrationClaims.withLock { inFlight in
            completedMigrationHistory.withLock { history in
                inFlight.remove(gKey)
                if completed {
                    if history.count >= maxMigrationHistorySize { history.removeAll() }
                    history.insert(gKey)
                }
            }
        }
    }
    private var authContinuityObserverToken: UUID?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var checkedPendingDIDs: Set<String> = []
    private func scopeKey(for did: String) -> String {
        "\(namespace)|\(accessGroup ?? "")|\(did)"
    }

    public func accountScopeDID(for did: String) -> AccountMutationHub.ScopeDID {
        AccountMutationHub.ScopeDID(namespace: namespace, accessGroup: accessGroup, did: did)
    }

    private var authContinuityScope: AuthContinuityMutationHub.Scope {
        AuthContinuityMutationHub.Scope(namespace: namespace, accessGroup: accessGroup)
    }
    /// Initializes a new KeychainStorage instance.
    /// - Parameters:
    ///   - namespace: A unique identifier for this application's keychain items
    ///   - accessGroup: Optional access group for keychain sharing between apps
    ///   - accessibility: Keychain accessibility for new writes on Apple platforms.
    ///     Defaults to `.afterFirstUnlockThisDeviceOnly` (no iCloud sync / device
    ///     transfer — DPoP-bound sessions are device-bound regardless).
    public init(namespace: String, accessGroup: String? = nil, accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) {
        self.namespace = namespace
        self.accessGroup = accessGroup
        KeychainManager.configureDefaultAccessGroup(accessGroup)
        KeychainManager.configureAccessibility(accessibility)
    }

    func setAuthContinuityObserver(
        _ observer: @escaping @Sendable (AuthContinuityStorageMutationEvent) async -> Void
    ) async {
        let scope = authContinuityScope
        authContinuityObserverToken = await AuthContinuityMutationHub.shared.replaceObserver(
            authContinuityObserverToken,
            for: scope,
            observer: observer
        )
    }

    private func beginAuthContinuityMutation() async -> UUID {
        await AuthContinuityMutationHub.shared.beginMutation(for: authContinuityScope)
    }

    private func endAuthContinuityMutation(_ ticket: UUID) async {
        await AuthContinuityMutationHub.shared.endMutation(ticket, for: authContinuityScope)
    }

    #if DEBUG
        func beginAuthContinuityMutationForTesting() async -> UUID {
            await beginAuthContinuityMutation()
        }

        func endAuthContinuityMutationForTesting(_ ticket: UUID) async {
            await endAuthContinuityMutation(ticket)
        }
    #endif

    // MARK: - Account Management

    /// Saves an account to the keychain.
    /// - Parameters:
    ///   - account: The account to save
    ///   - did: The DID of the account
    public func saveAccount(_ account: Account, for did: String) async throws {
        _ = try await saveAccountReturningGeneration(account, for: did)
    }

    /// Internal helper that saves an account and returns the post-mutation commit generation.
    func saveAccountReturningGeneration(_ account: Account, for did: String) async throws -> UInt64 {
        let scopeDID = accountScopeDID(for: did)
        AccountMutationHub.shared.bumpGeneration(for: scopeDID)
        let key = makeKey("account", did: did)
        let data = try encoder.encode(account)
        do {
            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
            try await addToAccountsList(did)
            let commitGen = AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
            return commitGen
        } catch {
            AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
            throw error
        }
    }

    /// Atomically saves both account and session data to prevent inconsistent authentication states.
    /// This method ensures that either both account and session are saved successfully, or neither is saved.
    /// - Parameters:
    ///   - account: The account to save
    ///   - session: The session to save
    ///   - did: The DID associated with both account and session
    func saveAccountAndSession(_ account: Account, session: Session, for did: String) async throws {
        let scopeDID = accountScopeDID(for: did)
        AccountMutationHub.shared.bumpGeneration(for: scopeDID)
        let accountKey = makeKey("account", did: did)
        let sessionKey = makeKey("session", did: did)
        let tempAccountKey = makeKey("account.temp", did: did)
        let tempSessionKey = makeKey("session.temp", did: did)
        let backupAccountKey = makeKey("account.backup", did: did)
        let backupSessionKey = makeKey("session.backup", did: did)

        let accountData = try encoder.encode(account)
        let sessionData = try encoder.encode(session)

        // Newest-wins guard: refresh tokens are single-use and rotate on every refresh,
        // so overwriting a newer session with an older one bricks the account.
        if try isStaleSessionWrite(session, for: did) {
            LogManager.logWarning(
                "Refusing to overwrite newer stored session with stale one (createdAt \(session.createdAt)) for DID: \(LogManager.logDID(did))"
            )
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
            return
        }

        LogManager.logDebug("Starting atomic account+session save for DID: \(LogManager.logDID(did))")

        // Update the accounts list before the commit sequence: addToAccountsList is the
        // only suspension point, and suspending mid-commit lets other actor calls
        // interleave with a half-written account+session pair. A listed DID without
        // data is harmless (validation treats it as an orphan); the reverse is not.
        try await addToAccountsList(did)

        // Re-check after the suspension above: another save may have committed a
        // newer session while this call was suspended. The commit block below is
        // fully synchronous, so this check cannot be bypassed again.
        if try isStaleSessionWrite(session, for: did) {
            LogManager.logWarning(
                "Newer session committed while suspended; skipping stale save for DID: \(LogManager.logDID(did))"
            )
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
            return
        }
        do {
            // Step 1: Create backups of existing data if they exist
            if let existingAccountData = try? KeychainManager.retrieve(
                key: accountKey, namespace: namespace, accessGroup: accessGroup
            ) {
                try KeychainManager.store(
                    key: backupAccountKey, value: existingAccountData, namespace: namespace, accessGroup: accessGroup
                )
                LogManager.logDebug("Account backup created for DID: \(LogManager.logDID(did))")
            }

            if let existingSessionData = try? KeychainManager.retrieve(
                key: sessionKey, namespace: namespace, accessGroup: accessGroup
            ) {
                try KeychainManager.store(
                    key: backupSessionKey, value: existingSessionData, namespace: namespace, accessGroup: accessGroup
                )
                LogManager.logDebug("Session backup created for DID: \(LogManager.logDID(did))")
            }

            // Step 2: Save both to temporary locations first
            try KeychainManager.store(key: tempAccountKey, value: accountData, namespace: namespace, accessGroup: accessGroup)
            LogManager.logDebug("Account saved to temporary location for DID: \(LogManager.logDID(did))")

            try KeychainManager.store(key: tempSessionKey, value: sessionData, namespace: namespace, accessGroup: accessGroup)
            LogManager.logDebug("Session saved to temporary location for DID: \(LogManager.logDID(did))")

            // Step 3: Atomic move both to final locations
            try KeychainManager.store(key: accountKey, value: accountData, namespace: namespace, accessGroup: accessGroup)
            LogManager.logDebug("Account moved to final location for DID: \(LogManager.logDID(did))")

            try KeychainManager.store(key: sessionKey, value: sessionData, namespace: namespace, accessGroup: accessGroup)
            LogManager.logDebug("Session moved to final location for DID: \(LogManager.logDID(did))")

            // Step 4: Verify both saves were successful by reading them back
            let verificationAccountData = try KeychainManager.retrieve(
                key: accountKey, namespace: namespace, accessGroup: accessGroup
            )
            let verificationSessionData = try KeychainManager.retrieve(
                key: sessionKey, namespace: namespace, accessGroup: accessGroup
            )

            let verifiedAccount = try decoder.decode(Account.self, from: verificationAccountData)
            let verifiedSession = try decoder.decode(Session.self, from: verificationSessionData)

            // Basic verification that both have required fields
            guard !verifiedAccount.did.isEmpty, !verifiedSession.accessToken.isEmpty else {
                throw KeychainError.dataFormatError
            }

            LogManager.logDebug(
                "Account+session save verification successful for DID: \(LogManager.logDID(did))"
            )

            // Step 5: Cleanup temporary and backup files
            try? KeychainManager.delete(key: tempAccountKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: tempSessionKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: backupAccountKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: backupSessionKey, namespace: namespace, accessGroup: accessGroup)

            LogManager.logDebug(
                "Account+session saved atomically and verified for DID: \(LogManager.logDID(did))"
            )
            let pKey = scopeKey(for: did)
            Self.pendingSessionState.withLock { _ = $0.knownGenerations.removeValue(forKey: pKey) }
            checkedPendingDIDs.insert(did)
            AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)

        } catch {
            LogManager.logError(
                "Atomic account+session save failed for DID: \(LogManager.logDID(did)), error: \(error)"
            )

            // Recovery: Attempt to restore from backups if final saves failed
            let accountRestored = restoreFromBackup(
                backupKey: backupAccountKey, into: accountKey, label: "account", did: did
            )
            let sessionRestored = restoreFromBackup(
                backupKey: backupSessionKey, into: sessionKey, label: "session", did: did
            )

            // Cleanup temporary files in error case
            try? KeychainManager.delete(key: tempAccountKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: tempSessionKey, namespace: namespace, accessGroup: accessGroup)
            // A backup is only redundant once its contents are back in place; deleting
            // one we failed to restore from destroys the very copy recovery needs.
            if accountRestored {
                try? KeychainManager.delete(key: backupAccountKey, namespace: namespace, accessGroup: accessGroup)
            }
            if sessionRestored {
                try? KeychainManager.delete(key: backupSessionKey, namespace: namespace, accessGroup: accessGroup)
            }
            if !accountRestored || !sessionRestored {
                LogManager.logError(
                    "Keeping backup copies for DID: \(LogManager.logDID(did)) because a restore did not complete (account restored: \(accountRestored), session restored: \(sessionRestored))"
                )
            }

            if accountRestored {
                AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            }
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)

            throw error
        }
    }

    /// Copies a backup entry back over its primary key.
    /// - Returns: True when the primary is known to hold the backed-up value, or when
    ///   there was no backup to restore. False means the backup must be kept.
    private func restoreFromBackup(
        backupKey: String, into primaryKey: String, label: String, did: String
    ) -> Bool {
        let backupData: Data
        do {
            backupData = try KeychainManager.retrieve(
                key: backupKey, namespace: namespace, accessGroup: accessGroup
            )
        } catch {
            if KeychainManager.isItemNotFound(error) { return true }
            LogManager.logError(
                "Could not read \(label) backup for DID: \(LogManager.logDID(did)), error: \(error)"
            )
            return false
        }

        do {
            try KeychainManager.store(
                key: primaryKey, value: backupData, namespace: namespace, accessGroup: accessGroup
            )
            LogManager.logDebug("\(label.capitalized) restored from backup for DID: \(LogManager.logDID(did))")
            return true
        } catch {
            LogManager.logError(
                "Failed to restore \(label) backup for DID: \(LogManager.logDID(did)), error: \(error)"
            )
            return false
        }
    }

    /// Retrieves an account from the keychain.
    /// - Parameter did: The DID of the account to retrieve
    /// - Returns: The account, or nil only when no account is stored for `did`.
    /// - Throws: The underlying storage error when the account could not be read or
    ///   decoded. Absence and failure are deliberately distinct: callers repair or
    ///   delete state based on "no account", and a failed read is not that.
    public func getAccount(for did: String) async throws -> Account? {
        let key = makeKey("account", did: did)
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            return try decoder.decode(Account.self, from: data)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError(
                "KeychainStorage - Failed to read account for DID \(LogManager.logDID(did)): \(error)"
            )
            throw error
        }
    }

    /// Deletes an account from the keychain.
    /// - Parameter did: The DID of the account to delete
    public func deleteAccount(for did: String) async throws {
        let scopeDID = accountScopeDID(for: did)
        AccountMutationHub.shared.bumpGeneration(for: scopeDID)
        let key = makeKey("account", did: did)
        do {
            try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            try await removeFromAccountsList(did)
            AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
        } catch {
            AccountMutationHub.shared.bumpGeneration(for: scopeDID)
            await AccountMutationHub.shared.notifyMutation(for: scopeDID)
            throw error
        }
    }

    /// Lists all account DIDs stored in the keychain.
    /// - Returns: The stored DIDs, or an empty array only when no list has been stored.
    /// - Throws: The underlying storage error when the list could not be read or
    ///   decoded — an empty array would otherwise read as "no accounts" and let
    ///   `addToAccountsList`/`removeFromAccountsList` overwrite the real list.
    public func listAccountDIDs() async throws -> [String] {
        let key = makeKey("accountDIDs")
        let data: Data
        do {
            data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return [] }
            LogManager.logError("KeychainStorage - Failed to read the account DID list: \(error)")
            throw error
        }
        do {
            return try decoder.decode([String].self, from: data)
        } catch {
            // Reported as a distinct error so the write paths can rebuild the list;
            // a storage failure above must never be repaired by overwriting.
            LogManager.logError("KeychainStorage - Stored account DID list could not be decoded: \(error)")
            throw KeychainError.dataFormatError
        }
    }

    /// Saves the current DID to the keychain.
    /// - Parameter did: The DID to save as current
    public func saveCurrentDID(_ did: String) async throws {
        let key = makeKey("currentDID")
        let data = did.data(using: .utf8) ?? Data()
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
    }

    /// Retrieves the current DID from the keychain.
    /// - Returns: The current DID, or nil only when none has been stored.
    /// - Throws: The underlying storage error when the selector could not be read.
    public func getCurrentDID() async throws -> String? {
        let key = makeKey("currentDID")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            guard let did = String(data: data, encoding: .utf8) else {
                LogManager.logError("KeychainStorage - Stored current DID is not valid UTF-8")
                throw KeychainError.dataFormatError
            }
            return did
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError("KeychainStorage - Failed to read the current DID: \(error)")
            throw error
        }
    }

    /// Deletes the current DID from the keychain.
    public func deleteCurrentDID() async throws {
        let key = makeKey("currentDID")
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            if KeychainManager.isItemNotFound(error) { return }
            throw error
        }
    }

    // MARK: - Gateway Session

    /// Saves the gateway session for a specific account (per-DID storage for multi-account support)
    func saveGatewaySession(_ session: String, for did: String) async throws {
        await gatewaySessionMutationGate.acquire()
        defer { gatewaySessionMutationGate.release() }

        let gKey = scopeKey(for: did)
        Self.completedMigrationHistory.withLock { _ = $0.remove(gKey) }
        let key = makeKey("gatewaySession", did: did)
        let data = session.data(using: .utf8) ?? Data()
        LogManager.logInfo("KeychainStorage - Saving gateway session with key: \(namespace).\(key) for DID: \(did.prefix(20))...")
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
        LogManager.logInfo("KeychainStorage - Successfully saved gateway session for DID: \(did.prefix(20))...")
    }

    /// Retrieves the gateway session for a specific account.
    /// - Returns: The session, or nil only when none is stored for `did` (including
    ///   the legacy locations).
    /// - Throws: The underlying storage error when the session could not be read.
    ///   Legacy migration is deliberately not attempted in that case: it would
    ///   overwrite a per-DID session that is present but momentarily unreadable.
    func getGatewaySession(for did: String) async throws -> String? {
        let key = makeKey("gatewaySession", did: did)
        LogManager.logInfo("KeychainStorage - Looking for gateway session with key: \(namespace).\(key)")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            LogManager.logInfo("KeychainStorage - Retrieved gateway session for DID: \(did.prefix(20))...")
            guard let session = String(data: data, encoding: .utf8) else {
                LogManager.logError("KeychainStorage - Stored gateway session is not valid UTF-8 for key \(namespace).\(key)")
                throw KeychainError.dataFormatError
            }
            return session
        } catch {
            guard KeychainManager.isItemNotFound(error) else {
                LogManager.logError(
                    "KeychainStorage - Failed to read gateway session for key \(namespace).\(key): \(error). Not treating this as a missing session."
                )
                throw error
            }
            let gKey = scopeKey(for: did)
            let claimResult: (inFlight: Bool, completed: Bool) = Self.inFlightMigrationClaims.withLock { inFlight in
                Self.completedMigrationHistory.withLock { completed in
                    if completed.contains(gKey) {
                        return (inFlight: false, completed: true)
                    }
                    let inserted = inFlight.insert(gKey).inserted
                    return (inFlight: inserted, completed: false)
                }
            }
            guard !claimResult.completed, claimResult.inFlight else {
                LogManager.logWarning("KeychainStorage - No gateway session found for DID: \(did.prefix(20))... (legacy migration already attempted or in flight)")
                return nil
            }
            LogManager.logWarning("KeychainStorage - Gateway session not found for key \(namespace).\(key). Attempting legacy migration...")
            do {
                if let migratedSession = try await migrateLegacyGatewaySessionIfNeeded(for: did) {
                    LogManager.logInfo("KeychainStorage - Successfully migrated legacy gateway session for DID: \(did.prefix(20))...")
                    return migratedSession
                }
            } catch {
                Self.retireMigrationClaim(gKey, completed: false)
                throw error
            }
            LogManager.logWarning("KeychainStorage - No gateway session found for DID: \(did.prefix(20))... (including legacy locations)")
            return nil
        }
    }
    /// Deletes the gateway session for a specific account
    func deleteGatewaySession(for did: String) async throws {
        await gatewaySessionMutationGate.acquire()
        defer { gatewaySessionMutationGate.release() }

        let key = makeKey("gatewaySession", did: did)
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
        LogManager.logDebug("KeychainStorage - Deleted gateway session for DID: \(did.prefix(20))...")
        let gKey = scopeKey(for: did)
        Self.inFlightMigrationClaims.withLock { inFlight in
            Self.completedMigrationHistory.withLock { history in
                inFlight.remove(gKey)
                history.remove(gKey)
            }
        }
    }

    /// Saves raw pending gateway upgrade data for a specific account.
    func savePendingGatewayUpgradeData(_ data: Data, for did: String) async throws {
        let key = makeKey("pendingGatewayUpgrade", did: did)
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    /// Retrieves raw pending gateway upgrade data for a specific account.
    func getPendingGatewayUpgradeData(for did: String) async throws -> Data? {
        let key = makeKey("pendingGatewayUpgrade", did: did)
        do {
            return try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            throw error
        }
    }

    /// Deletes pending gateway upgrade data for a specific account.
    func deletePendingGatewayUpgradeData(for did: String) async throws {
        let key = makeKey("pendingGatewayUpgrade", did: did)
        do {
            try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return }
            throw error
        }
    }

    /// Serialized compare-and-swap of gateway session.
    /// Verifies current stored session for `did` matches `expectedOldSession`
    /// and current stored DID equals `did` before replacing it.
    func compareAndSwapGatewaySession(
        expectedOldSession: String,
        newSession: String,
        for did: String
    ) async throws -> Bool {
        await gatewaySessionMutationGate.acquire()
        defer { gatewaySessionMutationGate.release() }

        guard let currentDID = try await getCurrentDID(), currentDID == did else {
            return false
        }
        guard let currentSession = try await getGatewaySession(for: did),
              currentSession == expectedOldSession else {
            return false
        }
        let gKey = scopeKey(for: did)
        Self.completedMigrationHistory.withLock { _ = $0.remove(gKey) }
        let key = makeKey("gatewaySession", did: did)
        let data = newSession.data(using: .utf8) ?? Data()
        LogManager.logInfo("KeychainStorage - CAS saving gateway session with key: \(namespace).\(key) for DID: \(did.prefix(20))...")
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
        LogManager.logInfo("KeychainStorage - Successfully CAS-promoted gateway session for DID: \(did.prefix(20))...")
        return true
    }

    private func shouldMigrateLegacyGatewaySession(for did: String) async throws -> Bool {
        guard !did.isEmpty else { return false }

        if let currentDID = try await getCurrentDID(), !currentDID.isEmpty {
            return currentDID == did
        }

        let dids = try await listAccountDIDs()
        return dids.count == 1 && dids.first == did
    }

    /// - Throws: The underlying storage error when a legacy location could not be
    ///   read. Swallowing it would report "no gateway session" for an account whose
    private func migrateLegacyGatewaySessionIfNeeded(for did: String) async throws -> String? {
        guard try await shouldMigrateLegacyGatewaySession(for: did) else {
            let gKey = scopeKey(for: did)
            Self.retireMigrationClaim(gKey, completed: false)
            return nil
        }
        let gKey = scopeKey(for: did)

        if let legacySession = try await getLegacyGatewaySession(), !legacySession.isEmpty {
            LogManager.logInfo(
                "KeychainStorage - Migrating legacy gateway session to per-DID storage for DID: \(did.prefix(20))..."
            )
            if await persistMigratedGatewaySession(legacySession, for: did) {
                do {
                    try await deleteLegacyGatewaySession()
                } catch {
                    LogManager.logWarning(
                        "KeychainStorage - Migrated legacy gateway session but failed to remove the source copy: \(error)"
                    )
                }
                Self.retireMigrationClaim(gKey, completed: true)
            } else {
                Self.retireMigrationClaim(gKey, completed: false)
            }
            return legacySession
        }

        if let data = try await readGlobalGatewaySession(),
           let session = String(data: data, encoding: .utf8),
           !session.isEmpty
        {
            LogManager.logInfo(
                "KeychainStorage - Migrating global gateway session to per-DID storage for DID: \(did.prefix(20))..."
            )
            if await persistMigratedGatewaySession(session, for: did) {
                do {
                    try await KeychainManager.deleteAsync(
                        key: "gatewaySession",
                        namespace: "catbird.gateway",
                        accessGroup: accessGroup
                    )
                } catch {
                    LogManager.logWarning(
                        "KeychainStorage - Migrated global gateway session but failed to remove the source copy: \(error)"
                    )
                }
                Self.retireMigrationClaim(gKey, completed: true)
            } else {
                Self.retireMigrationClaim(gKey, completed: false)
            }
            return session
        }

        Self.retireMigrationClaim(gKey, completed: true)
        return nil
    }

    private func saveLegacyGatewaySession(_ session: String) async throws {
        Self.completedMigrationHistory.withLock { $0.removeAll() }
        let key = makeKey("gatewaySession")
        let data = session.data(using: .utf8) ?? Data()
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
    }


    /// Reads the pre-multi-account gateway session from its global namespace.
    /// - Returns: The raw bytes, or nil only when nothing is stored there.
    private func readGlobalGatewaySession() async throws -> Data? {
        do {
            return try await KeychainManager.retrieveAsync(
                key: "gatewaySession",
                namespace: "catbird.gateway",
                accessGroup: accessGroup
            )
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError("KeychainStorage - Failed to read the global gateway session: \(error)")
            throw error
        }
    }

    /// Writes a migrated gateway session to per-DID storage and reads it back.
    /// - Returns: True only when the new copy is verified readable, so the caller
    ///   never deletes the source of a migration that did not land.
    private func persistMigratedGatewaySession(_ session: String, for did: String) async -> Bool {
        do {
            try await saveGatewaySession(session, for: did)
        } catch {
            LogManager.logError(
                "KeychainStorage - Failed to persist migrated gateway session for DID: \(did.prefix(20))...: \(error). Keeping the legacy copy."
            )
            return false
        }

        let key = makeKey("gatewaySession", did: did)
        guard
            let verification = try? await KeychainManager.retrieveAsync(
                key: key, namespace: namespace, accessGroup: accessGroup
            ),
            String(data: verification, encoding: .utf8) == session
        else {
            LogManager.logError(
                "KeychainStorage - Could not verify migrated gateway session for DID: \(did.prefix(20)).... Keeping the legacy copy."
            )
            return false
        }
        return true
    }

    /// Legacy single-session methods for backward compatibility during migration
    @available(*, deprecated, message: "Use saveGatewaySession(_:for:) for multi-account support")
    func saveGatewaySession(_ session: String) async throws {
        try await saveLegacyGatewaySession(session)
    }

    @available(*, deprecated, message: "Use getGatewaySession(for:) for multi-account support")
    func getGatewaySession() async throws -> String? {
        try await getLegacyGatewaySession()
    }

    @available(*, deprecated, message: "Use deleteGatewaySession(for:) for multi-account support")
    func deleteGatewaySession() async throws {
        try await deleteLegacyGatewaySession()
    }

    private func getLegacyGatewaySession() async throws -> String? {
        let key = makeKey("gatewaySession")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            return String(data: data, encoding: .utf8)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError("KeychainStorage - Failed to read the legacy gateway session: \(error)")
            throw error
        }
    }

    private func deleteLegacyGatewaySession() async throws {
        let key = makeKey("gatewaySession")
        let continuityTicket = await beginAuthContinuityMutation()
        do {
            try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
            await endAuthContinuityMutation(continuityTicket)
        } catch {
            await endAuthContinuityMutation(continuityTicket)
            throw error
        }
    }

    // MARK: - Session Management

    /// Saves a session to the keychain.
    /// - Parameters:
    ///   - session: The session to save
    ///   - did: The DID associated with the session
    public func saveSession(_ session: Session, for did: String) async throws {
        let key = makeKey("session", did: did)
        let tempKey = makeKey("session.temp", did: did)
        let backupKey = makeKey("session.backup", did: did)
        // Validate session before attempting to save
        guard !session.accessToken.isEmpty else {
            LogManager.logError(
                "Attempted to save invalid session with empty access token for DID: \(LogManager.logDID(did))"
            )
            throw KeychainError.dataFormatError
        }

        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            LogManager.logError(
                "Failed to encode session for DID: \(LogManager.logDID(did)), error: \(error)"
            )
            throw KeychainError.dataFormatError
        }

        // Newest-wins guard: never replace a newer stored session with an older one
        // (single-use rotating refresh tokens make stale overwrites unrecoverable).
        if try isStaleSessionWrite(session, for: did) {
            LogManager.logWarning(
                "Refusing to overwrite newer stored session with stale one (createdAt \(session.createdAt)) for DID: \(LogManager.logDID(did))"
            )
            return
        }

        LogManager.logDebug("Starting session save for DID: \(LogManager.logDID(did))")

        // Enhanced atomic save operation with comprehensive error handling
        do {
            // Step 1: Create backup of existing session if it exists
            if let existingData = try? KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup) {
                do {
                    try KeychainManager.store(key: backupKey, value: existingData, namespace: namespace, accessGroup: accessGroup)
                    LogManager.logDebug("Session backup created for DID: \(LogManager.logDID(did))")
                } catch {
                    LogManager.logWarning(
                        "Failed to create session backup for DID: \(LogManager.logDID(did)), continuing without backup: \(error)"
                    )
                }
            }

            // Step 2: Save to temporary location first
            do {
                try KeychainManager.store(key: tempKey, value: data, namespace: namespace, accessGroup: accessGroup)
                LogManager.logDebug(
                    "Session saved to temporary location for DID: \(LogManager.logDID(did))"
                )
            } catch {
                LogManager.logError(
                    "Failed to save session to temporary location for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.temporarySaveFailed(underlying: error)
            }

            // Step 3: Atomic move to final location
            do {
                try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
                LogManager.logDebug("Session moved to final location for DID: \(LogManager.logDID(did))")
            } catch {
                LogManager.logError(
                    "Failed to save session to final location for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.finalSaveFailed(underlying: error)
            }

            // Step 4: Verify the save was successful by reading it back
            do {
                let verificationData = try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
                let verifiedSession = try decoder.decode(Session.self, from: verificationData)

                // Comprehensive verification that the session has required fields
                guard !verifiedSession.accessToken.isEmpty,
                      verifiedSession.did == session.did,
                      abs(verifiedSession.createdAt.timeIntervalSince(session.createdAt)) < 1.0
                else {
                    throw SessionSaveError.verificationFailed(
                        "Session verification failed: stored session doesn't match expected values"
                    )
                }

                LogManager.logDebug(
                    "Session save verification successful for DID: \(LogManager.logDID(did))"
                )
            } catch let SessionSaveError.verificationFailed(message) {
                LogManager.logError(
                    "Session verification failed for DID: \(LogManager.logDID(did)): \(message)"
                )
                throw SessionSaveError.verificationFailed(message)
            } catch {
                LogManager.logError(
                    "Session verification error for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.verificationFailed("Could not verify saved session: \(error)")
            }

            // Step 5: Cleanup temporary files
            try? KeychainManager.delete(key: tempKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: backupKey, namespace: namespace, accessGroup: accessGroup)
            LogManager.logDebug(
                "Session saved atomically and verified for DID: \(LogManager.logDID(did))"
            )
            let pKey = scopeKey(for: did)
            Self.pendingSessionState.withLock { _ = $0.knownGenerations.removeValue(forKey: pKey) }
            checkedPendingDIDs.insert(did)

        } catch let sessionSaveError as SessionSaveError {
            LogManager.logError(
                "Session save failed for DID: \(LogManager.logDID(did)): \(sessionSaveError)"
            )
            await handleSessionSaveFailure(
                sessionSaveError, key: key, tempKey: tempKey, backupKey: backupKey, did: did
            )
            throw sessionSaveError
        } catch {
            LogManager.logError(
                "Unexpected session save error for DID: \(LogManager.logDID(did)): \(error)"
            )
            await handleSessionSaveFailure(
                SessionSaveError.unexpectedError(error), key: key, tempKey: tempKey, backupKey: backupKey,
                did: did
            )
            throw SessionSaveError.unexpectedError(error)
        }
    }

    /// Handles session save failures with appropriate recovery actions
    private func handleSessionSaveFailure(
        _ error: SessionSaveError, key: String, tempKey: String, backupKey: String, did: String
    ) async {
        switch error {
        case .temporarySaveFailed:
            // If we can't even save to temp, just cleanup and fail
            try? KeychainManager.delete(key: tempKey, namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: backupKey, namespace: namespace, accessGroup: accessGroup)

        case .finalSaveFailed, .verificationFailed, .unexpectedError:
            // For final save or verification failures, attempt recovery from backup
            var restored = false
            var backupData: Data?
            do {
                backupData = try KeychainManager.retrieve(key: backupKey, namespace: namespace, accessGroup: accessGroup)
            } catch {
                if KeychainManager.isItemNotFound(error) {
                    // Nothing was backed up, so nothing needs preserving.
                    restored = true
                } else {
                    LogManager.logError(
                        "Could not read session backup for DID: \(LogManager.logDID(did)): \(error)"
                    )
                }
            }

            if let backupData {
                do {
                    try KeychainManager.store(key: key, value: backupData, namespace: namespace, accessGroup: accessGroup)
                    restored = true
                    LogManager.logInfo(
                        "Session restored from backup after save failure for DID: \(LogManager.logDID(did))"
                    )
                } catch {
                    LogManager.logError(
                        "Failed to restore session backup for DID: \(LogManager.logDID(did)): \(error)"
                    )
                }
            }

            // Always cleanup temporary files in error cases
            try? KeychainManager.delete(key: tempKey, namespace: namespace, accessGroup: accessGroup)
            // Only drop the backup once its contents are known to be back in place;
            // deleting the copy we just failed to restore from destroys the session.
            if restored {
                try? KeychainManager.delete(key: backupKey, namespace: namespace, accessGroup: accessGroup)
            } else {
                LogManager.logError(
                    "Keeping the session backup for DID: \(LogManager.logDID(did)) because the restore did not complete; getSession can still recover from it"
                )
            }
        }
    }

    /// Errors that can occur during session save operations
    enum SessionSaveError: Error, LocalizedError {
        case temporarySaveFailed(underlying: Error)
        case finalSaveFailed(underlying: Error)
        case verificationFailed(String)
        case unexpectedError(Error)

        var errorDescription: String? {
            switch self {
            case let .temporarySaveFailed(underlying):
                return "Failed to save session to temporary location: \(underlying.localizedDescription)"
            case let .finalSaveFailed(underlying):
                return "Failed to save session to final location: \(underlying.localizedDescription)"
            case let .verificationFailed(message):
                return "Session verification failed: \(message)"
            case let .unexpectedError(underlying):
                return "Unexpected session save error: \(underlying.localizedDescription)"
            }
        }

        var failureReason: String? {
            switch self {
            case .temporarySaveFailed:
                return "The keychain may be temporarily unavailable or the device may be locked."
            case .finalSaveFailed:
                return "The keychain operation failed during the final save step."
            case .verificationFailed:
                return "The saved session data could not be verified or was corrupted."
            case .unexpectedError:
                return "An unexpected error occurred during the save operation."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .temporarySaveFailed, .finalSaveFailed:
                return
                    "Please ensure your device is unlocked and try again. If the problem persists, you may need to restart the app."
            case .verificationFailed:
                return
                    "The authentication state may be corrupted. Please try logging out and logging back in."
            case .unexpectedError:
                return "Please try the operation again. If the problem persists, contact support."
            }
        }
    }

    /// Retrieves a session from the keychain.
    ///
    /// Resolution order is newest-wins: a pending session (written when a post-refresh
    /// save could not complete) is promoted over an older primary; temp/backup copies
    /// are only used when the primary is unreadable, and never resurrect a session
    /// older than the newest readable copy.
    /// - Parameters:
    ///   - did: The DID associated with the session to retrieve
    ///   - bypassCache: When true, reads the keychain directly instead of the
    ///     in-memory cache — required to observe rotations made by other processes
    ///     sharing the access group (e.g. app extensions) before refreshing.
    /// - Returns: The session, or nil only when no copy exists anywhere.
    /// - Throws: The underlying storage error when the primary copy could not be read
    ///   (its freshness is then unknown, so no fallback may be promoted over it), or
    ///   when no copy could be read at all and at least one read failed. A *missing*
    ///   copy still falls through to the next candidate; only absence proven by
    ///   successful reads is reported as nil, because callers delete state on nil.
    public func getSession(for did: String, bypassCache: Bool = false) async throws -> Session? {
        let key = makeKey("session", did: did)
        let tempKey = makeKey("session.temp", did: did)
        let backupKey = makeKey("session.backup", did: did)
        let pendingKey = makeKey("session.pending", did: did)
        var readErrors: [Error] = []

        let primaryRead = await readSessionCopy(key, for: did, bypassCache: bypassCache)
        if let primaryError = primaryRead.error {
            LogManager.logError(
                "KeychainStorage - Primary session unreadable for DID: \(LogManager.logDID(did)); refusing to promote a fallback copy over it: \(primaryError)"
            )
            throw primaryError
        }
        let primary = decodeSession(primaryRead.data)

        let pKey = scopeKey(for: did)
        let hasChecked = checkedPendingDIDs.contains(did)
        let knownGen = Self.pendingSessionState.withLock { $0.knownGenerations[pKey] }
        let isKnown = knownGen != nil
        let shouldCheckPending = bypassCache || (primary == nil) || isKnown || !hasChecked

        if shouldCheckPending {
            let pendingRead = await readSessionCopy(pendingKey, for: did, bypassCache: bypassCache)
            if let error = pendingRead.error { readErrors.append(error) }
            if let pending = decodeSession(pendingRead.data) {
                if primary == nil || pending.createdAt > primary!.createdAt {
                    LogManager.logInfo(
                        "Promoting pending session to primary for DID: \(LogManager.logDID(did))"
                    )
                    if let data = try? encoder.encode(pending) {
                        do {
                            try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
                            try? await KeychainManager.deleteAsync(key: pendingKey, namespace: namespace, accessGroup: accessGroup)
                            Self.pendingSessionState.withLock { state in
                                if let gen = knownGen, state.knownGenerations[pKey] == gen {
                                    state.knownGenerations.removeValue(forKey: pKey)
                                }
                            }
                            checkedPendingDIDs.insert(did)
                        } catch {
                            let token = AccountMutationHub.shared.nextEpoch()
                            Self.pendingSessionState.withLock { state in
                                if state.knownGenerations[pKey] == nil {
                                    state.knownGenerations[pKey] = token
                                }
                            }
                        }
                    }
                    return pending
                } else {
                    try? await KeychainManager.deleteAsync(key: pendingKey, namespace: namespace, accessGroup: accessGroup)
                    Self.pendingSessionState.withLock { state in
                        if let gen = knownGen, state.knownGenerations[pKey] == gen {
                            state.knownGenerations.removeValue(forKey: pKey)
                        }
                    }
                    checkedPendingDIDs.insert(did)
                }
            } else if pendingRead.data == nil && pendingRead.error == nil {
                Self.pendingSessionState.withLock { state in
                    if let gen = knownGen, state.knownGenerations[pKey] == gen {
                        state.knownGenerations.removeValue(forKey: pKey)
                    }
                }
                checkedPendingDIDs.insert(did)
            }
        }
        if let primary {
            return primary
        }
        LogManager.logDebug(
            "Failed to retrieve session from primary location for DID: \(LogManager.logDID(did)), attempting recovery"
        )

        // Primary unreadable: recover the NEWEST of temp/backup. Restoring blindly
        // could resurrect an already-rotated (single-use) refresh token, so pick by
        // createdAt and only write back because no readable primary exists.
        let tempRead = await readSessionCopy(tempKey, for: did)
        if let error = tempRead.error { readErrors.append(error) }
        let backupRead = await readSessionCopy(backupKey, for: did)
        if let error = backupRead.error { readErrors.append(error) }
        let temp = decodeSession(tempRead.data)
        let backup = decodeSession(backupRead.data)

        let candidates = [(temp, tempKey, "temporary"), (backup, backupKey, "backup")]
            .compactMap { session, sourceKey, label in session.map { ($0, sourceKey, label) } }
            .sorted { $0.0.createdAt > $1.0.createdAt }

        guard let (recovered, sourceKey, label) = candidates.first else {
            if let firstError = readErrors.first {
                // No copy was readable and at least one read genuinely failed, so
                // "no session" is not a supported conclusion: report the failure.
                LogManager.logError(
                    "KeychainStorage - No session copy could be read for DID: \(LogManager.logDID(did)) (\(readErrors.count) read failure(s)); reporting the read error instead of absence"
                )
                throw firstError
            }
            return nil
        }

        LogManager.logInfo(
            "Session recovered from \(label) location for DID: \(LogManager.logDID(did))"
        )
        if let data = try? encoder.encode(recovered),
           (try? await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)) != nil
        {
            try? await KeychainManager.deleteAsync(key: sourceKey, namespace: namespace, accessGroup: accessGroup)
        }
        return recovered
    }

    /// Reads one stored session copy.
    /// - Returns: The raw bytes when present, plus the storage error when the read
    ///   itself failed. A copy that is simply absent yields `(nil, nil)` so the
    ///   caller can fall through to the next candidate without losing the
    ///   distinction between "not stored" and "could not be read".
    private func readSessionCopy(
        _ copyKey: String, for did: String, bypassCache: Bool = false
    ) async -> (data: Data?, error: Error?) {
        do {
            let data = try await KeychainManager.retrieveAsync(
                key: copyKey, namespace: namespace, accessGroup: accessGroup, bypassCache: bypassCache
            )
            return (data, nil)
        } catch {
            if KeychainManager.isItemNotFound(error) { return (nil, nil) }
            LogManager.logError(
                "KeychainStorage - Failed to read session copy \(namespace).\(copyKey) for DID: \(LogManager.logDID(did)): \(error)"
            )
            return (nil, error)
        }
    }

    /// Decodes a session from optional raw keychain data, returning nil on any failure.
    private func decodeSession(_ data: Data?) -> Session? {
        guard let data else { return nil }
        return try? decoder.decode(Session.self, from: data)
    }

    /// Returns true if a decodable stored session for `did` is newer than `session`.
    /// Used by save paths so interleaved writers converge on the newest session.
    ///
    /// Fails closed: if the stored session cannot be read, the write is refused by
    /// throwing rather than allowed, because the unreadable copy may be newer and a
    /// single-use refresh token overwritten by an older one is unrecoverable.
    /// Throwing (rather than silently reporting "stale") is what lets the caller
    /// fall back to `savePendingSession` instead of believing the write landed.
    /// A stored session that reads back but cannot be *decoded* is unusable to every
    /// reader, so overwriting it is the repair path, not a loss.
    private func isStaleSessionWrite(_ session: Session, for did: String) throws -> Bool {
        let key = makeKey("session", did: did)
        let data: Data
        do {
            data = try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return false }
            LogManager.logError(
                "KeychainStorage - Cannot compare against the stored session for DID: \(LogManager.logDID(did)): \(error). Refusing the write rather than risk overwriting a newer session."
            )
            throw error
        }
        guard let existing = try? decoder.decode(Session.self, from: data) else {
            LogManager.logError(
                "KeychainStorage - Stored session for DID: \(LogManager.logDID(did)) could not be decoded; allowing the write to replace it."
            )
            return false
        }
        return session.createdAt < existing.createdAt
    }

    /// Persists a refreshed session with a single keychain write, for use when the
    public func savePendingSession(_ session: Session, for did: String) async throws {
        let key = makeKey("session.pending", did: did)
        let data = try encoder.encode(session)
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
        let pKey = scopeKey(for: did)
        let token = AccountMutationHub.shared.nextEpoch()
        Self.pendingSessionState.withLock { state in
            state.knownGenerations[pKey] = token
        }
        checkedPendingDIDs.remove(did)
        LogManager.logInfo("KeychainStorage - Saved pending session for DID: \(LogManager.logDID(did))")
    }

    /// Deletes a session from the keychain, including pending/temp/backup copies
    public func deleteSession(for did: String) async throws {
        var failures: [Error] = []
        for suffix in ["session", "session.pending", "session.temp", "session.backup"] {
            do {
                try KeychainManager.delete(key: makeKey(suffix, did: did), namespace: namespace, accessGroup: accessGroup)
            } catch {
                guard KeychainManager.isItemNotFound(error) else {
                    LogManager.logError(
                        "KeychainStorage - Failed to delete \(suffix) for DID: \(LogManager.logDID(did)): \(error)"
                    )
                    failures.append(error)
                    continue
                }
            }
        }

        if let first = failures.first {
            LogManager.logError(
                "KeychainStorage - \(failures.count) session copy/copies survived deletion for DID: \(LogManager.logDID(did)); a later read could resurrect the session"
            )
            throw first
        }

        let pKey = scopeKey(for: did)
        Self.pendingSessionState.withLock { _ = $0.knownGenerations.removeValue(forKey: pKey) }
        checkedPendingDIDs.insert(did)
    }
    // MARK: - Session Backup and Recovery

    /// Saves a backup copy of the session for recovery purposes.
    /// - Parameters:
    ///   - session: The session to backup
    ///   - did: The DID associated with the session
    public func saveSessionBackup(_ session: Session, for did: String) async throws {
        let key = makeKey("session.backup", did: did)
        let data = try encoder.encode(session)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
        LogManager.logDebug("KeychainStorage - Saved session backup for DID: \(LogManager.logDID(did))")
    }

    /// Saves a session to a temporary location (used during atomic saves).
    /// - Parameters:
    ///   - session: The session to save temporarily
    ///   - did: The DID associated with the session
    public func saveSessionToTemp(_ session: Session, for did: String) async throws {
        let key = makeKey("session.temp", did: did)
        let data = try encoder.encode(session)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
        LogManager.logDebug("KeychainStorage - Saved session to temp for DID: \(LogManager.logDID(did))")
    }

    /// Attempts to recover a session from backup or temporary locations.
    /// - Parameter did: The DID to recover session for
    /// - Returns: The recovered session if available, nil otherwise
    public func recoverSessionFromBackup(for did: String) async throws -> Session? {
        let backupKey = makeKey("session.backup", did: did)

        // Try backup location first
        do {
            let data = try KeychainManager.retrieve(key: backupKey, namespace: namespace, accessGroup: accessGroup)
            let session = try decoder.decode(Session.self, from: data)
            LogManager.logInfo("KeychainStorage - Recovered session from backup for DID: \(LogManager.logDID(did))")
            return session
        } catch {
            LogManager.logDebug("KeychainStorage - No backup session found for DID: \(LogManager.logDID(did))")
        }

        // Try temporary location as fallback
        let tempKey = makeKey("session.temp", did: did)
        do {
            let data = try KeychainManager.retrieve(key: tempKey, namespace: namespace, accessGroup: accessGroup)
            let session = try decoder.decode(Session.self, from: data)
            LogManager.logInfo("KeychainStorage - Recovered session from temp for DID: \(LogManager.logDID(did))")
            return session
        } catch {
            LogManager.logDebug("KeychainStorage - No temp session found for DID: \(LogManager.logDID(did))")
        }

        return nil
    }

    /// Deletes a session backup from the keychain.
    /// - Parameter did: The DID associated with the session backup to delete
    public func deleteSessionBackup(for did: String) async throws {
        let key = makeKey("session.backup", did: did)
        try KeychainManager.delete(key: key, namespace: namespace, accessGroup: accessGroup)
    }

    /// Deletes a temporary session from the keychain.
    /// - Parameter did: The DID associated with the temp session to delete
    public func deleteSessionTemp(for did: String) async throws {
        let key = makeKey("session.temp", did: did)
        try KeychainManager.delete(key: key, namespace: namespace, accessGroup: accessGroup)
    }

    // MARK: - DPoP Key Management

    /// Saves a DPoP key representation without moving CryptoKit key material
    /// across this actor's isolation boundary.
    func saveDPoPKeyRepresentation(_ representation: Data, for did: String) async throws {
        let key = try P256.Signing.PrivateKey(x963Representation: representation)
        let keyTag = makeKey("dpopKey", did: did)
        Self.dpopKeyMutationHub.bumpGeneration(for: did)
        do {
            try KeychainManager.storeDPoPKeyRepresentation(
                key.x963Representation,
                keyTag: keyTag,
                accessGroup: accessGroup
            )
            LogManager.logDebug(
                "Successfully saved DPoP key to Keychain for DID \(LogManager.logDID(did))"
            )
        } catch {
            LogManager.logError(
                "Failed to save DPoP key to Keychain (error: \(error)). This will likely cause authentication issues."
            )
            await Self.dpopKeyMutationHub.notifyKeyMutation(for: did)
            throw error
        }
        await Self.dpopKeyMutationHub.notifyKeyMutation(for: did)
    }




    /// Retrieves a DPoP key as a Sendable representation so callers can
    /// reconstruct it inside their own isolation domain.
    func getDPoPKeyRepresentation(for did: String) throws -> Data? {
        let keyTag = makeKey("dpopKey", did: did)
        do {
            let representation = try KeychainManager.retrieveDPoPKeyRepresentation(
                keyTag: keyTag,
                accessGroup: accessGroup
            )
            // Reject malformed or corrupted storage records before exposing bytes.
            return try P256.Signing.PrivateKey(
                x963Representation: representation
            ).x963Representation
        } catch let KeychainError.itemRetrievalError(status) where status == errSecItemNotFound {
            LogManager.logDebug(
                "DPoP key not found in Keychain for DID: \(did). A new key will be generated if needed."
            )
            return nil
        } catch let KeychainError.itemRetrievalError(status) {
            LogManager.logError(
                "Keychain retrieval error for DPoP key (status=\(status)) for DID: \(did). Will NOT rotate key."
            )
            throw KeychainError.itemRetrievalError(status: status)
        } catch {
            LogManager.logError(
                "Failed to retrieve DPoP key from Keychain (error: \(error)). Will NOT rotate key."
            )
            throw error
        }
    }

    /// Saves a DPoP key to the keychain.
    /// - Parameters:
    ///   - key: The private key to save
    ///   - did: The DID associated with the key
    public func saveDPoPKey(_ key: P256.Signing.PrivateKey, for did: String) async throws {
        try await saveDPoPKeyRepresentation(key.x963Representation, for: did)
    }


    /// Retrieves a DPoP key from the keychain.
    /// - Parameter did: The DID associated with the key to retrieve
    /// - Returns: The private key if found, or nil if not found
    public func getDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey? {
        guard let representation = try getDPoPKeyRepresentation(for: did) else {
            return nil
        }
        return try P256.Signing.PrivateKey(x963Representation: representation)
    }

    /// Checks whether a DPoP key exists without moving private key material
    /// across the storage actor boundary.
    public func containsDPoPKey(for did: String) async throws -> Bool {
        try getDPoPKeyRepresentation(for: did) != nil
    }

    public func deleteDPoPKey(for did: String) async throws {
        let keyTag = makeKey("dpopKey", did: did)
        Self.dpopKeyMutationHub.bumpGeneration(for: did)
        do {
            try KeychainManager.deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
        } catch {
            await Self.dpopKeyMutationHub.notifyKeyMutation(for: did)
            throw error
        }
        await Self.dpopKeyMutationHub.notifyKeyMutation(for: did)
    }




    // MARK: - DPoP Nonce Management

    /// Saves DPoP nonces to the keychain.
    /// - Parameters:
    ///   - nonces: The nonces to save, keyed by domain
    ///   - did: The DID associated with the nonces
    public func saveDPoPNonces(_ nonces: [String: String], for did: String) async throws {
        let key = makeKey("dpopNonces", did: did)
        let data = try encoder.encode(nonces)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    /// Retrieves DPoP nonces from the keychain.
    /// - Parameter did: The DID associated with the nonces to retrieve
    /// - Returns: The nonces, or nil when none are stored or the stored map cannot be
    ///   decoded. Callers treat nil as an empty map and rewrite the store, which is
    ///   the only way an undecodable map is ever repaired — throwing here would abort
    ///   every nonce update before it saved, wedging DPoP retries permanently.
    /// - Throws: The underlying storage error when the nonces could not be read.
    public func getDPoPNonces(for did: String) async throws -> [String: String]? {
        let key = makeKey("dpopNonces", did: did)
        let data: Data
        do {
            data = try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError(
                "KeychainStorage - Failed to read DPoP nonces for DID: \(LogManager.logDID(did)): \(error)"
            )
            throw error
        }
        do {
            return try decoder.decode([String: String].self, from: data)
        } catch {
            LogManager.logError(
                "KeychainStorage - Stored DPoP nonces for DID: \(LogManager.logDID(did)) could not be decoded (\(error)); treating them as empty so the next update rewrites the store"
            )
            return nil
        }
    }

    /// Saves DPoP nonces scoped by JKT (key thumbprint) to the keychain.
    /// - Parameters:
    ///   - noncesByJKT: Mapping of JKT -> (domain -> nonce)
    ///   - did: The DID associated with these nonces
    public func saveDPoPNoncesByJKT(_ noncesByJKT: [String: [String: String]], for did: String)
        async throws
    {
        let key = makeKey("dpopNoncesByJKT", did: did)
        let data = try encoder.encode(noncesByJKT)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    /// Retrieves DPoP nonces scoped by JKT (key thumbprint) from the keychain.
    /// - Parameter did: The DID associated with these nonces
    /// - Returns: Mapping of JKT -> (domain -> nonce), or nil when none are stored or
    ///   the stored map cannot be decoded — see `getDPoPNonces` for why an
    ///   undecodable map is reported as absent rather than as an error.
    /// - Throws: The underlying storage error when the nonces could not be read.
    public func getDPoPNoncesByJKT(for did: String) async throws -> [String: [String: String]]? {
        let key = makeKey("dpopNoncesByJKT", did: did)
        let data: Data
        do {
            data = try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError(
                "KeychainStorage - Failed to read JKT-scoped DPoP nonces for DID: \(LogManager.logDID(did)): \(error)"
            )
            throw error
        }
        do {
            return try decoder.decode([String: [String: String]].self, from: data)
        } catch {
            LogManager.logError(
                "KeychainStorage - Stored JKT-scoped DPoP nonces for DID: \(LogManager.logDID(did)) could not be decoded (\(error)); treating them as empty so the next update rewrites the store"
            )
            return nil
        }
    }

    // MARK: - OAuth State Management

    /// Saves an OAuth state to the keychain.
    /// - Parameter state: The OAuth state to save
    public func saveOAuthState(_ state: OAuthState) async throws {
        let key = makeKey("oauthState", stateToken: state.stateToken)
        let data = try encoder.encode(state)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    /// Retrieves an OAuth state from the keychain.
    /// - Parameter stateToken: The state token associated with the OAuth state to retrieve
    /// - Returns: The OAuth state if found, or nil if not found
    public func getOAuthState(for stateToken: String) async throws -> OAuthState? {
        let key = makeKey("oauthState", stateToken: stateToken)
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
            return try decoder.decode(OAuthState.self, from: data)
        } catch {
            if KeychainManager.isItemNotFound(error) { return nil }
            LogManager.logError("KeychainStorage - Failed to read OAuth state: \(error)")
            throw error
        }
    }

    /// Deletes an OAuth state from the keychain.
    /// - Parameter stateToken: The state token associated with the OAuth state to delete
    public func deleteOAuthState(for stateToken: String) async throws {
        let key = makeKey("oauthState", stateToken: stateToken)
        try KeychainManager.delete(key: key, namespace: namespace, accessGroup: accessGroup)
    }

    // MARK: - Session Integrity Validation

    /// Validates the integrity of authentication state and fixes inconsistencies.
    /// This method should be called at app startup to detect and repair race condition damage.
    /// - Returns: A summary of any issues found and fixed
    func validateAndRepairAuthenticationState() async -> AuthStateValidationResult {
        var result = AuthStateValidationResult()

        do {
            let accountDIDs = try await listAccountDIDs()
            LogManager.logDebug("Validating authentication state for \(accountDIDs.count) accounts")

            for did in accountDIDs {
                // Every branch below is destructive or advises re-authentication, and
                // each decision turns on something being *absent*. A read that failed
                // is not an absence, so a DID whose state cannot be read is skipped
                // rather than repaired — the previous code deleted live sessions when
                // the account read failed.
                let accountExists: Bool
                let sessionExists: Bool
                let gatewaySessionExists: Bool
                do {
                    accountExists = try await getAccount(for: did) != nil
                    sessionExists = try await getSession(for: did) != nil
                    gatewaySessionExists = try await getGatewaySession(for: did) != nil
                } catch {
                    LogManager.logError(
                        "Skipping auth-state repair for DID \(LogManager.logDID(did)): stored state could not be read (\(error)). Repair requires proven absence."
                    )
                    result.unreadableStates.append(did)
                    continue
                }
                let hasAuthSession = sessionExists || gatewaySessionExists

                if accountExists && !hasAuthSession {
                    LogManager.logWarning(
                        "Inconsistent auth state detected for DID \(LogManager.logDID(did)): account exists but session missing"
                    )
                    result.inconsistentStates.append(did)

                    // Attempt to recover session from temporary/backup locations
                    if try await recoverSessionFromBackup(for: did) {
                        result.recoveredSessions.append(did)
                        LogManager.logInfo(
                            "Successfully recovered session from backup for DID \(LogManager.logDID(did))"
                        )
                    } else {
                        // Don't delete the account - just log the issue and let the normal auth flow
                        // handle re-authentication. Deleting accounts aggressively causes problems
                        // for gateway auth users where sessions might be temporarily inaccessible.
                        LogManager.logWarning(
                            "Account exists but session not found for DID \(LogManager.logDID(did)) - user may need to re-authenticate"
                        )
                        result.requiresReauth.append(did)
                    }
                } else if !accountExists && sessionExists {
                    LogManager.logWarning(
                        "Orphaned session detected for DID \(LogManager.logDID(did)): session exists but account missing"
                    )
                    try await deleteSession(for: did)
                    result.cleanedOrphanedSessions.append(did)
                    LogManager.logInfo("Removed orphaned session for DID \(LogManager.logDID(did))")
                } else if !accountExists && gatewaySessionExists {
                    LogManager.logWarning(
                        "Orphaned gateway session detected for DID \(LogManager.logDID(did)): session exists but account missing"
                    )
                    try? await deleteGatewaySession(for: did)
                    result.cleanedOrphanedSessions.append(did)
                    LogManager.logInfo("Removed orphaned gateway session for DID \(LogManager.logDID(did))")
                }
            }

            // Clean up any temporary files that might have been left behind
            try await cleanupTemporaryFiles()

            LogManager.logInfo("Authentication state validation complete: \(result.summary)")

        } catch {
            LogManager.logError("Failed to validate authentication state: \(error)")
            result.validationError = error
        }

        return result
    }

    /// Attempts to recover a missing session from temporary or backup locations
    /// - Parameter did: The DID for which to recover the session
    /// - Returns: True if recovery was successful, false otherwise
    private func recoverSessionFromBackup(for did: String) async throws -> Bool {
        let sessionKey = makeKey("session", did: did)
        let tempSessionKey = makeKey("session.temp", did: did)
        let backupSessionKey = makeKey("session.backup", did: did)

        // Try temporary location first
        if let tempData = try? KeychainManager.retrieve(key: tempSessionKey, namespace: namespace, accessGroup: accessGroup) {
            do {
                let session = try decoder.decode(Session.self, from: tempData)
                guard !session.accessToken.isEmpty else { return false }

                try KeychainManager.store(key: sessionKey, value: tempData, namespace: namespace, accessGroup: accessGroup)
                try? KeychainManager.delete(key: tempSessionKey, namespace: namespace, accessGroup: accessGroup)

                LogManager.logDebug(
                    "Session recovered from temporary location for DID: \(LogManager.logDID(did))"
                )
                return true
            } catch {
                LogManager.logDebug("Failed to decode session from temporary location: \(error)")
            }
        }

        // Try backup location
        if let backupData = try? KeychainManager.retrieve(key: backupSessionKey, namespace: namespace, accessGroup: accessGroup) {
            do {
                let session = try decoder.decode(Session.self, from: backupData)
                guard !session.accessToken.isEmpty else { return false }

                try KeychainManager.store(key: sessionKey, value: backupData, namespace: namespace, accessGroup: accessGroup)
                try? KeychainManager.delete(key: backupSessionKey, namespace: namespace, accessGroup: accessGroup)

                LogManager.logDebug(
                    "Session recovered from backup location for DID: \(LogManager.logDID(did))"
                )
                return true
            } catch {
                LogManager.logDebug("Failed to decode session from backup location: \(error)")
            }
        }

        return false
    }

    /// Cleans up temporary and backup files that might have been left behind from interrupted operations
    private func cleanupTemporaryFiles() async throws {
        let accountDIDs = try await listAccountDIDs()

        for did in accountDIDs {
            // Clean up temporary files
            try? KeychainManager.delete(key: makeKey("session.temp", did: did), namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: makeKey("account.temp", did: did), namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: makeKey("session.backup", did: did), namespace: namespace, accessGroup: accessGroup)
            try? KeychainManager.delete(key: makeKey("account.backup", did: did), namespace: namespace, accessGroup: accessGroup)
        }

        LogManager.logDebug("Cleaned up temporary keychain files")
    }

    /// Result of authentication state validation
    struct AuthStateValidationResult {
        var inconsistentStates: [String] = []
        var recoveredSessions: [String] = []
        var cleanedOrphanedAccounts: [String] = []
        var cleanedOrphanedSessions: [String] = []
        var requiresReauth: [String] = []
        /// DIDs whose stored state could not be read, so no repair was attempted.
        var unreadableStates: [String] = []
        var validationError: Error?

        var hasIssues: Bool {
            return !inconsistentStates.isEmpty || !cleanedOrphanedAccounts.isEmpty
                || !cleanedOrphanedSessions.isEmpty || !requiresReauth.isEmpty
                || !unreadableStates.isEmpty || validationError != nil
        }

        var summary: String {
            var parts: [String] = []
            if !inconsistentStates.isEmpty {
                parts.append("\(inconsistentStates.count) inconsistent states")
            }
            if !recoveredSessions.isEmpty {
                parts.append("\(recoveredSessions.count) sessions recovered")
            }
            if !cleanedOrphanedAccounts.isEmpty {
                parts.append("\(cleanedOrphanedAccounts.count) orphaned accounts cleaned")
            }
            if !cleanedOrphanedSessions.isEmpty {
                parts.append("\(cleanedOrphanedSessions.count) orphaned sessions cleaned")
            }
            if !requiresReauth.isEmpty {
                parts.append("\(requiresReauth.count) accounts need re-authentication")
            }
            if !unreadableStates.isEmpty {
                parts.append("\(unreadableStates.count) accounts skipped (state unreadable)")
            }
            if let error = validationError {
                parts.append("validation error: \(error)")
            }
            return parts.isEmpty ? "no issues found" : parts.joined(separator: ", ")
        }
    }

    // MARK: - Helper Methods

    /// Creates a keychain key with the given base and optional DID.
    /// - Parameters:
    ///   - base: The base key name
    ///   - did: Optional DID to associate with the key
    ///   - stateToken: Optional state token to associate with the key
    /// - Returns: A formatted key string
    private func makeKey(_ base: String, did: String? = nil, stateToken: String? = nil) -> String {
        if let did = did {
            return "\(base).\(did)"
        } else if let stateToken = stateToken {
            return "\(base).\(stateToken)"
        } else {
            return base
        }
    }

    /// Adds a DID to the accounts list.
    /// - Parameter did: The DID to add
    private func addToAccountsList(_ did: String) async throws {
        let key = makeKey("accountDIDs")
        var dids = try await accountDIDsForRewrite()

        if !dids.contains(did) {
            dids.append(did)
            let data = try encoder.encode(dids)
            try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
        }
    }

    /// The account DID list as a basis for rewriting it. A list that cannot be
    /// decoded is unusable to every reader, so it is rebuilt; a list that could not
    /// be *read* is rethrown, because overwriting it would drop the other accounts.
    private func accountDIDsForRewrite() async throws -> [String] {
        do {
            return try await listAccountDIDs()
        } catch KeychainError.dataFormatError {
            LogManager.logError(
                "KeychainStorage - Rebuilding the account DID list from scratch because the stored list could not be decoded"
            )
            return []
        }
    }

    /// Removes a DID from the accounts list.
    /// - Parameter did: The DID to remove
    private func removeFromAccountsList(_ did: String) async throws {
        let key = makeKey("accountDIDs")
        var dids = try await accountDIDsForRewrite()

        dids.removeAll { $0 == did }
        let data = try encoder.encode(dids)
        try KeychainManager.store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }
}
