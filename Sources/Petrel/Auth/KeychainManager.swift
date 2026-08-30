//
//  KeychainManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Crypto
import Foundation
import Synchronization
#if os(iOS) || os(macOS)
    import Security
#endif

enum KeychainError: Error, LocalizedError {
    case itemStoreError(status: Int)
    case itemRetrievalError(status: Int)
    case dataFormatError
    case unableToCreateKey
    case deletionError(status: Int)
    case storageUnavailable(String)
    case expiredState

    var errorDescription: String? {
        switch self {
        case let .itemStoreError(status):
            return "Failed to store item in keychain (Status: \(status))."
        case let .itemRetrievalError(status):
            return "Failed to retrieve item from keychain (Status: \(status))."
        case .dataFormatError:
            return "Keychain data is corrupted or in an invalid format."
        case .unableToCreateKey:
            return "Failed to create cryptographic key from keychain data."
        case let .deletionError(status):
            return "Failed to delete item from keychain (Status: \(status))."
        case let .storageUnavailable(reason):
            return "No secure storage backend could be initialized: \(reason)"
        case .expiredState:
            return "The authentication flow state has expired."
        }
    }

    var failureReason: String? {
        #if os(iOS) || os(macOS)
            switch self {
            case let .itemStoreError(status) where status == Int(errSecDuplicateItem):
                return "An item with this key already exists in the keychain."
            case let .itemStoreError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            case let .itemRetrievalError(status) where status == Int(errSecItemNotFound):
                return "The requested item was not found in the keychain."
            case let .itemRetrievalError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            case .dataFormatError:
                return "The stored keychain data cannot be decoded or is missing required fields."
            case .unableToCreateKey:
                return "The cryptographic key data from keychain is invalid or corrupted."
            case let .deletionError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            case .expiredState:
                return "The authentication flow state has expired and is no longer valid."
            default:
                return "Keychain operation failed due to system restrictions or device state."
            }
        #else
            switch self {
            case .itemRetrievalError:
                return "The requested item was not found."
            case .dataFormatError:
                return "The stored data cannot be decoded or is missing required fields."
            case .unableToCreateKey:
                return "The cryptographic key data is invalid or corrupted."
            case .expiredState:
                return "The authentication flow state has expired and is no longer valid."
            default:
                return "Storage operation failed."
            }
        #endif
    }

    var recoverySuggestion: String? {
        #if os(iOS) || os(macOS)
            switch self {
            case let .itemStoreError(status) where status == Int(errSecAuthFailed),
                 .itemRetrievalError(let status) where status == Int(errSecAuthFailed),
                 .deletionError(let status) where status == Int(errSecAuthFailed):
                return "Please unlock your device and ensure the app has keychain access."
            case let .itemRetrievalError(status) where status == Int(errSecItemNotFound):
                return "You may need to log in again to restore your credentials."
            case .dataFormatError, .unableToCreateKey:
                return "Please log out and log back in to reset your stored credentials."
            case .expiredState:
                return "Please restart the authentication flow."
            case let .itemStoreError(status) where status == Int(errSecDuplicateItem):
                return "Please restart the app or log out and log back in."
            default:
                return "Try restarting the app. If the problem persists, you may need to log out and log back in."
            }
        #else
            switch self {
            case .expiredState:
                return "Please restart the authentication flow."
            default:
                return "Try restarting the app. If the problem persists, you may need to log out and log back in."
            }
        #endif
    }
}

enum KeychainManager {
    // MARK: - Storage Backend

    /// The secure storage backend used by this manager
    private static let defaultStorage: SecureStorage = {
        #if os(iOS) || os(macOS)
            return AppleKeychainStore()
        #elseif os(Linux)
            return createLinuxStorage()
        #else
            #error("Unsupported platform")
        #endif
    }()

    /// Test-only override of the storage backend, protected by a lock.
    private static let storageOverrideState = Mutex<SecureStorage?>(nil)

    /// The active storage backend (test override if set, otherwise the platform default)
    private static var storage: SecureStorage {
        storageOverrideState.withLock { $0 } ?? defaultStorage
    }

    /// Injects a storage backend for testing. Pass `nil` to restore the platform default.
    /// Clears all caches so cached reads cannot leak across backends.
    static func _setStorageOverride(_ backend: SecureStorage?) {
        storageOverrideState.withLock { $0 = backend }
        clearCacheStorage()
    }

    #if os(Linux)
        /// Create appropriate storage backend for Linux
        private static func createLinuxStorage() -> SecureStorage {
            // Try libsecret first (desktop environment)
            if LibSecretStore.isAvailable() {
                LogManager.logInfo("KeychainManager - Using libsecret for secure storage (desktop Linux)")
                return LibSecretStore()
            }

            // Fallback to encrypted file storage (server/headless)
            LogManager.logInfo("KeychainManager - Using file-encrypted storage (libsecret not available)")
            do {
                return try FileEncryptedStore()
            } catch {
                // A library must not kill the host process: surface the failure as a
                // thrown error on first storage use instead.
                LogManager.logError("KeychainManager - Failed to initialize FileEncryptedStore: \(error)")
                return UnavailableSecureStorage(underlyingError: error)
            }
        }

        /// Placeholder backend used when no secure storage could be initialized;
        /// every operation throws so callers see a recoverable error instead of
        /// the process aborting.
        private struct UnavailableSecureStorage: SecureStorage {
            let underlyingError: Error

            private func unavailable() -> KeychainError {
                LogManager.logError("KeychainManager - Secure storage unavailable: \(underlyingError)")
                return KeychainError.storageUnavailable(String(describing: underlyingError))
            }

            func store(key _: String, value _: Data, namespace _: String, accessGroup _: String?) throws {
                throw unavailable()
            }

            func retrieve(key _: String, namespace _: String, accessGroup _: String?) throws -> Data {
                throw unavailable()
            }

            func delete(key _: String, namespace _: String, accessGroup _: String?) throws {
                throw unavailable()
            }

            func deleteAll(namespace _: String, accessGroup _: String?) throws {
                throw unavailable()
            }

            func storeDPoPKeyRepresentation(_: Data, keyTag _: String, accessGroup _: String?) throws {
                throw unavailable()
            }

            func retrieveDPoPKeyRepresentation(keyTag _: String, accessGroup _: String?) throws -> Data {
                throw unavailable()
            }

            func deleteDPoPKey(keyTag _: String, accessGroup _: String?) throws {
                throw unavailable()
            }
        }
    #endif

    // MARK: - Cache

    /// Thread-safe caches with automatic memory management
    private nonisolated(unsafe) static let dataCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100
        return cache
    }()
    private static let cachedKeysState = Mutex<Set<String>>([])
    private static let nonceNegativeCacheState = Mutex<Set<String>>([])
    private static let maxNegativeCacheSize = 200

    private static func isHotNonceKey(_ key: String) -> Bool {
        key.hasPrefix("dpopNonces.") || key.hasPrefix("dpopNoncesByJKT.")
    }

    private static func cacheKey(key: String, namespace: String, accessGroup: String?) -> String {
        "\(namespace)|\(accessGroup ?? "")|\(key)"
    }

    /// Configures the keychain accessibility level applied to new writes on Apple
    /// platforms (no-op elsewhere). Existing items keep their previous attribute
    /// until rewritten.
    static func configureAccessibility(_ accessibility: KeychainAccessibility) {
        #if os(iOS) || os(macOS)
            AppleKeychainStore.configureAccessibility(accessibility)
        #endif
    }

    static let itemNotFoundStatus: Int = {
        #if os(iOS) || os(macOS)
            return Int(errSecItemNotFound)
        #else
            return -25300
        #endif
    }()

    private static func accessGroupAttributes(_ accessGroup: String?) -> [String: Any] {
        guard let accessGroup, !accessGroup.isEmpty else { return [:] }
        #if canImport(Security)
            return [kSecAttrAccessGroup as String: accessGroup]
        #else
            return [:]
        #endif
    }
    /// True when `error` reports that the item simply does not exist, as opposed to
    /// a storage failure. Callers use this to tell absence from "could not read",
    /// which must never be collapsed into the same nil.
    static func isItemNotFound(_ error: Error) -> Bool {
        switch error {
        case let KeychainError.itemRetrievalError(status),
             let KeychainError.deletionError(status):
            return status == itemNotFoundStatus
        default:
            return false
        }
    }

    /// Configure cache limits
    static func configureCaches(countLimit: Int = 100) {
        dataCache.countLimit = countLimit
    }

    // MARK: - Cache Management
    private static func clearCacheStorage() {
        dataCache.removeAllObjects()
        cachedKeysState.withLock { $0.removeAll() }
        nonceNegativeCacheState.withLock { $0.removeAll() }
    }

    /// Clears all cached items
    static func clearCache() {
        clearCacheStorage()
        LogManager.logDebug("KeychainManager - Cache cleared.")
    }

    /// Clears cached items for a specific namespace
    static func clearCache(forNamespace namespace: String) {
        let prefix = "\(namespace)|"
        let keysToRemove = cachedKeysState.withLock { cachedKeys -> [String] in
            let matching = cachedKeys.filter { $0.hasPrefix(prefix) }
            for key in matching {
                cachedKeys.remove(key)
            }
            return Array(matching)
        }
        for key in keysToRemove {
            dataCache.removeObject(forKey: key as NSString)
        }
        nonceNegativeCacheState.withLock { negKeys in
            let matching = negKeys.filter { $0.hasPrefix(prefix) }
            for key in matching {
                negKeys.remove(key)
            }
        }
        LogManager.logDebug("KeychainManager - Cache cleared for namespace: \(namespace).")
    }
    // MARK: - Generic Data Methods

    static func deleteExplicitKey(_ exactKey: String, accessGroup: String? = nil) throws {
        let parts = exactKey.split(separator: ".", maxSplits: 1)
        let (namespace, key) = parts.count == 2 ? (String(parts[0]), String(parts[1])) : ("", exactKey)
        try storage.delete(
            key: key,
            namespace: namespace,
            accessGroup: accessGroup
        )

        // Remove from cache
        let cKey = cacheKey(key: key, namespace: namespace, accessGroup: accessGroup)
        dataCache.removeObject(forKey: cKey as NSString)
        cachedKeysState.withLock { _ = $0.remove(cKey) }
    }
    /// Stores data in the keychain with a specified key and namespace.
    static func store(
        key: String,
        value: Data,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        try storage.store(
            key: key,
            value: value,
            namespace: namespace,
            accessGroup: accessGroup
        )

        // Update cache
        let cKey = cacheKey(key: key, namespace: namespace, accessGroup: accessGroup)
        dataCache.setObject(value as NSData, forKey: cKey as NSString)
        cachedKeysState.withLock { _ = $0.insert(cKey) }
        if isHotNonceKey(key) {
            nonceNegativeCacheState.withLock { _ = $0.remove(cKey) }
        }
        LogManager.logDebug("KeychainManager - Successfully stored item for key \(namespace).\(key).")
    }

    /// Retrieves data from the keychain for a specified key and namespace.
    /// - Parameter bypassCache: When true, skips the in-memory cache and reads the
    ///   keychain directly (still refreshing the cache with the result). Use for
    ///   reads that must observe writes made by other processes sharing the access
    ///   group, e.g. the session read preceding a token refresh.
    static func retrieve(
        key: String,
        namespace: String,
        accessGroup: String? = nil,
        bypassCache: Bool = false
    ) throws -> Data {
        let cKey = cacheKey(key: key, namespace: namespace, accessGroup: accessGroup)

        // Check cache first
        if !bypassCache {
            if let cachedData = dataCache.object(forKey: cKey as NSString) {
                LogManager.logDebug("KeychainManager - Retrieved item from cache for key \(cKey).")
                return cachedData as Data
            }
            if isHotNonceKey(key) {
                let isNegative = nonceNegativeCacheState.withLock { $0.contains(cKey) }
                if isNegative {
                    LogManager.logDebug("KeychainManager - Negative cache hit for hot nonce key \(cKey).")
                    throw KeychainError.itemRetrievalError(status: itemNotFoundStatus)
                }
            }
        }

        let data: Data
        do {
            data = try storage.retrieve(
                key: key,
                namespace: namespace,
                accessGroup: accessGroup
            )
        } catch {
            if isItemNotFound(error) && isHotNonceKey(key) {
                nonceNegativeCacheState.withLock { set in
                    if set.count >= maxNegativeCacheSize { set.removeAll() }
                    _ = set.insert(cKey)
                }
            }
            throw error
        }

        dataCache.setObject(data as NSData, forKey: cKey as NSString)
        cachedKeysState.withLock { _ = $0.insert(cKey) }
        if isHotNonceKey(key) {
            nonceNegativeCacheState.withLock { _ = $0.remove(cKey) }
        }
        LogManager.logDebug("KeychainManager - Successfully retrieved item for key \(cKey).")
        return data
    }

    static func storeObject<T: Encodable>(
        _ object: T,
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let data = try JSONCoders.encode(object)
        try store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    static func retrieveObject<T: Decodable>(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws -> T {
        let data = try retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        return try JSONCoders.decode(T.self, from: data)
    }

    /// Deletes data from the keychain for a specified key and namespace.
    static func delete(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let cKey = cacheKey(key: key, namespace: namespace, accessGroup: accessGroup)

        dataCache.removeObject(forKey: cKey as NSString)
        cachedKeysState.withLock { _ = $0.remove(cKey) }
        do {
            try storage.delete(key: key, namespace: namespace, accessGroup: accessGroup)
        } catch {
            LogManager.logError("KeychainManager - Failed to delete item for key \(cKey): \(error)")
            throw error
        }

        dataCache.removeObject(forKey: cKey as NSString)
        cachedKeysState.withLock { _ = $0.remove(cKey) }
        if isHotNonceKey(key) {
            nonceNegativeCacheState.withLock { set in
                if set.count >= maxNegativeCacheSize { set.removeAll() }
                _ = set.insert(cKey)
            }
        }

        LogManager.logDebug("KeychainManager: Successfully deleted item for key \(cKey).")
    }

    static func nukeAllKeychainItems(
        forNamespace namespace: String,
        accessGroup: String? = nil
    ) -> Bool {
        do {
            try storage.deleteAll(namespace: namespace, accessGroup: accessGroup)
            clearCache(forNamespace: namespace)
            LogManager.logInfo("KeychainManager - Successfully nuked all items for namespace: \(namespace)")
            return true
        } catch {
            LogManager.logError("KeychainManager - Failed to nuke items for namespace \(namespace): \(error)")
            return false
        }
    }

    // MARK: - DPoP Key Methods

    /// Stores a serialized DPoP private key in the keychain with a specified key tag.
    static func storeDPoPKeyRepresentation(
        _ representation: Data,
        keyTag: String,
        accessGroup: String? = nil
    ) throws {
        try storage.storeDPoPKeyRepresentation(
            representation,
            keyTag: keyTag,
            accessGroup: accessGroup
        )
    }

    /// Retrieves a serialized DPoP private key from the keychain with a specified key tag.
    static func retrieveDPoPKeyRepresentation(
        keyTag: String,
        accessGroup: String? = nil
    ) throws -> Data {
        try storage.retrieveDPoPKeyRepresentation(
            keyTag: keyTag,
            accessGroup: accessGroup
        )
    }

    /// Synchronous compatibility helper. Serialization remains the only value
    /// that crosses the Sendable storage boundary.
    static func storeDPoPKey(
        _ key: P256.Signing.PrivateKey,
        keyTag: String,
        accessGroup: String? = nil
    ) throws {
        try storeDPoPKeyRepresentation(
            key.x963Representation,
            keyTag: keyTag,
            accessGroup: accessGroup
        )
    }

    /// Synchronous compatibility helper that reconstructs the key in the
    /// caller's current isolation domain.
    static func retrieveDPoPKey(
        keyTag: String,
        accessGroup: String? = nil
    ) throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(
            x963Representation: retrieveDPoPKeyRepresentation(
                keyTag: keyTag,
                accessGroup: accessGroup
            )
        )
    }

    /// Deletes a DPoP private key from the keychain with a specified key tag.
    static func deleteDPoPKey(keyTag: String, accessGroup: String? = nil) throws {
        try storage.deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
    }

    /// Stores a DPoP private key in the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func storeDPoPKey(
        _ key: P256.Signing.PrivateKey,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let tagString = "\(namespace).dpopkeypair"
        try storeDPoPKey(key, keyTag: tagString, accessGroup: accessGroup)
    }

    /// Retrieves a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func retrieveDPoPKey(
        namespace: String,
        accessGroup: String? = nil
    ) throws -> P256.Signing.PrivateKey {
        let tagString = "\(namespace).dpopkeypair"
        return try retrieveDPoPKey(keyTag: tagString, accessGroup: accessGroup)
    }

    /// Deletes a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func deleteDPoPKey(namespace: String, accessGroup: String? = nil) throws {
        let tagString = "\(namespace).dpopkeypair"
        try deleteDPoPKey(keyTag: tagString, accessGroup: accessGroup)
    }

    /// Deletes DPoP key bindings from the keychain for a specified namespace.
    static func deleteDPoPKeyBindings(namespace: String, accessGroup: String? = nil) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings"
        try deleteExplicitKey(bindingsKey, accessGroup: accessGroup)

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)
        cachedKeysState.withLock { _ = $0.remove(bindingsKey) }

        LogManager.logDebug(
            "KeychainManager - Successfully deleted DPoP key bindings for namespace \(namespace)."
        )
    }

    /// Deletes DPoP key bindings for a specific DID
    static func deleteDPoPKeyBindingsForDID(
        namespace: String,
        did: String,
        accessGroup: String? = nil
    ) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings.\(did)"
        try deleteExplicitKey(bindingsKey, accessGroup: accessGroup)

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)
        cachedKeysState.withLock { _ = $0.remove(bindingsKey) }

        LogManager.logDebug("KeychainManager - Successfully deleted DPoP key bindings for DID \(did).")
    }

    // MARK: - Initialization

    /// Call this at app startup
    static func initialize() {
        configureCaches()
    }

    // MARK: - Async Wrappers for CLI/Actor Safety

    /// Async wrapper for retrieve that offloads the blocking Security framework call to a background thread.
    /// This prevents blocking actor executors when called from within actors.
    static func retrieveAsync(
        key: String,
        namespace: String,
        accessGroup: String? = nil,
        bypassCache: Bool = false
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try retrieve(
                        key: key, namespace: namespace, accessGroup: accessGroup, bypassCache: bypassCache
                    )
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for store that offloads the blocking Security framework call to a background thread.
    static func storeAsync(
        key: String,
        value: Data,
        namespace: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store(key: key, value: value, namespace: namespace, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for delete that offloads the blocking Security framework call to a background thread.
    static func deleteAsync(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try delete(key: key, namespace: namespace, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper that moves only a serialized key representation across the
    /// continuation boundary.
    static func retrieveDPoPKeyRepresentationAsync(
        keyTag: String,
        accessGroup: String? = nil
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let representation = try retrieveDPoPKeyRepresentation(
                        keyTag: keyTag,
                        accessGroup: accessGroup
                    )
                    continuation.resume(returning: representation)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper that reconstructs key material inside the storage closure.
    static func storeDPoPKeyRepresentationAsync(
        _ representation: Data,
        keyTag: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let isolatedKey = try P256.Signing.PrivateKey(x963Representation: representation)
                    try storeDPoPKeyRepresentation(
                        isolatedKey.x963Representation,
                        keyTag: keyTag,
                        accessGroup: accessGroup
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for deleteDPoPKey that offloads the blocking Security framework call to a background thread.
    static func deleteDPoPKeyAsync(
        keyTag: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Gateway Session Management

    /// Saves the gateway session ID
    static func saveGatewaySession(_ session: String) throws {
        guard let data = session.data(using: .utf8) else {
            throw KeychainError.dataFormatError
        }
        try store(key: "gatewaySession", value: data, namespace: "catbird.gateway")
    }

    /// Retrieves the gateway session ID
    static func getGatewaySession() throws -> String? {
        do {
            let data = try retrieve(key: "gatewaySession", namespace: "catbird.gateway")
            return String(data: data, encoding: .utf8)
        } catch {
            if isItemNotFound(error) {
                return nil
            }
            throw error
        }
    }

    /// Deletes the gateway session ID
    static func deleteGatewaySession() throws {
        try delete(key: "gatewaySession", namespace: "catbird.gateway")
    }
}
