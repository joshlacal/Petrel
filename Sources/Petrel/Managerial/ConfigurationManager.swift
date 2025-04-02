//
//  ConfigurationManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation

// MARK: - ConfigurationManaging Protocol

protocol ConfigurationManaging: Actor {
    var baseURL: URL { get }
    func updateBaseURL(_ url: URL) async
    func updateUserConfiguration(did: String, handle: String, serviceEndpoint: String) async throws
    func updateDID(did: String) async
    func getDID() async -> String?
    func getDID(forAccount did: String) async -> String?
    func getHandle() async -> String?
    func getHandle(forAccount did: String) async -> String?
    func updatePDSURL(_ url: URL) async
    func updatePDSURL(_ url: URL, forDID did: String) async
    func getPDSURL() async -> URL?
    func getPDSURL(forAccount did: String) async -> URL?
    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata, forDID did: String?)
        async
    func getProtectedResourceMetadata() async -> ProtectedResourceMetadata?
    func getProtectedResourceMetadata(forAccount did: String) async -> ProtectedResourceMetadata?
    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata, forDID did: String?)
        async
    func getAuthorizationServerMetadata() async -> AuthorizationServerMetadata?
    func getAuthorizationServerMetadata(forAccount did: String) async -> AuthorizationServerMetadata?
    func setCurrentAuthorizationServer(_ url: URL, forDID did: String?) async
    func getCurrentAuthorizationServer() async -> URL?
    func updateHandle(_ handle: String) async
    func switchToAccount(did: String) async -> Bool
    func listAccounts() async -> [String]
    func removeAccount(did: String) async throws
    func clearSettings() async
}

// MARK: - ConfigurationManager Actor

actor ConfigurationManager: ConfigurationManaging {
    // MARK: - Properties

    private var isUpdating = false
    private let namespace: String
    private(set) var baseURL: URL
    private var pdsURL: URL?
    private var did: String?
    private var handle: String?
    private var protectedResourceMetadata: ProtectedResourceMetadata?
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var currentAuthorizationServer: URL?

    // MARK: - Initialization

    init(baseURL: URL, namespace: String) async {
        self.namespace = namespace
        self.baseURL = baseURL
        LogManager.logDebug(
            "ConfigurationManager initialized with baseURL: \(baseURL), namespace: \(namespace)")
        await loadSettings()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
            default:
                break
            }
        }
    }

    // MARK: - Configuration Methods

    func updateUserConfiguration(did: String, handle: String, serviceEndpoint: String) async throws {
        await updateDID(did: did)
        await updateHandle(handle)
        guard let serviceURL = URL(string: serviceEndpoint) else {
            throw ConfigurationManagerError.invalidURL
        }
        await updateBaseURL(serviceURL)
        await updatePDSURL(serviceURL)
        await EventBus.shared.publish(
            .userConfigurationUpdated(did: did, handle: handle, serviceEndpoint: serviceEndpoint))
    }

    func updateBaseURL(_ url: URL) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        baseURL = url

        do {
            try KeychainManager.store(
                key: key("baseURL"),
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store baseURL in Keychain: \(error)")
        }

        await EventBus.shared.publish(.baseURLUpdated(url))
    }

    /// Note: PDS and Service Endpoint are the same
    func updatePDSURL(_ url: URL) async {
        LogManager.logInfo("ConfigurationManager - Updating PDS URL to: \(url)")

        // Diagnostic logging to trace DID state during PDS URL update
        let currentConfigDID = did
        LogManager.logError(
            "CONFIG_SAVE: Attempting to save PDS URL '\(url)' using configManager's current DID: \(currentConfigDID ?? "nil")"
        )
        let keyToSave = key("pdsURL")
        LogManager.logError("CONFIG_SAVE: Saving PDS URL to key: \(keyToSave)")

        pdsURL = url
        baseURL = url

        do {
            try KeychainManager.store(
                key: keyToSave,
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logError("CONFIG_SAVE: Successfully stored PDS URL to key \(keyToSave)")
        } catch {
            LogManager.logError("CONFIG_SAVE: FAILED to store PDS URL to key \(keyToSave): \(error)")
            LogManager.logError("ConfigurationManager - Failed to store pdsURL in Keychain: \(error)")
        }

        await EventBus.shared.publish(.pdsURLResolved(url))
    }

    /// Updates the PDS URL with an explicitly provided DID to ensure correct account association
    /// - Parameters:
    ///   - url: The new PDS URL to save
    ///   - did: The specific DID to associate this PDS URL with (overrides self.did)
    func updatePDSURL(_ url: URL, forDID did: String) async {
        LogManager.logInfo(
            "ConfigurationManager - Updating PDS URL to: \(url) specifically for DID: \(did)")

        // Temporarily store the original DID
        let originalDID = self.did
        LogManager.logError("CONFIG_SAVE_FORDID: Original configManager.did='\(originalDID ?? "nil")'")

        // Explicitly set the DID for this operation
        self.did = did
        LogManager.logError(
            "CONFIG_SAVE_FORDID: Temporarily set configManager.did='\(did)' for key generation")

        // Generate the key with the explicit DID
        let keyToSave = key("pdsURL")
        LogManager.logError("CONFIG_SAVE_FORDID: Using key '\(keyToSave)' for saving PDS URL")

        // Update in-memory state
        // Only update if this is the current active DID
        if originalDID == did {
            pdsURL = url
            baseURL = url
            LogManager.logError("CONFIG_SAVE_FORDID: Updated in-memory state (active DID)")
        } else {
            LogManager.logError("CONFIG_SAVE_FORDID: Not updating in-memory state (not active DID)")
        }

        // Save to keychain with the explicit DID's key
        do {
            try KeychainManager.store(
                key: keyToSave,
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logError("CONFIG_SAVE_FORDID: Successfully stored PDS URL to key \(keyToSave)")
        } catch {
            LogManager.logError(
                "CONFIG_SAVE_FORDID: FAILED to store PDS URL to key \(keyToSave): \(error)")
        }

        // Restore the original DID
        self.did = originalDID
        LogManager.logError(
            "CONFIG_SAVE_FORDID: Restored configManager.did to '\(originalDID ?? "nil")'")

        // Only publish event if this affects the current active DID
        if originalDID == did {
            await EventBus.shared.publish(.pdsURLResolved(url))
        }
    }

    func updateDID(did: String) async {
        self.did = did

        do {
            try KeychainManager.store(
                key: key("did"),
                value: did.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store DID in Keychain: \(error)")
        }

        await EventBus.shared.publish(.didResolved(did: did))
    }

    /// Updates the user's handle.
    ///
    /// - Parameter handle: The user's handle.
    func updateHandle(_ handle: String) async {
        self.handle = handle

        do {
            try KeychainManager.store(
                key: keychainKey(for: did, baseKey: "handle"),
                value: handle.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store handle in Keychain: \(error)")
        }

        await EventBus.shared.publish(.handleResolved(handle: handle))
    }

    func setProtectedResourceMetadata(
        _ metadata: ProtectedResourceMetadata, forDID did: String? = nil
    ) async {
        // Use provided DID or fall back to the actor's current DID
        let targetDID = did ?? self.did
        LogManager.logInfo(
            "ConfigurationManager - Setting ProtectedResourceMetadata with resource: \(metadata.resource) for DID: \(targetDID ?? "default")"
        )

        // Only update in-memory state if this is for the current DID
        if targetDID == self.did || (targetDID == nil && self.did == nil) {
            protectedResourceMetadata = metadata
        }

        // Temporarily store original DID
        let originalDID = self.did

        // Set the DID for key generation if a specific one was provided
        if let specificDID = targetDID {
            self.did = specificDID
        }

        // Generate the key with the appropriate DID
        let keyToSave = key("protectedResourceMetadata")
        LogManager.logDebug(
            "ConfigurationManager - Using key '\(keyToSave)' for saving ProtectedResourceMetadata")

        do {
            let data = try JSONEncoder().encode(metadata)
            try KeychainManager.store(
                key: keyToSave,
                value: data,
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug(
                "ConfigurationManager - Saved ProtectedResourceMetadata to Keychain with key \(keyToSave)")
        } catch {
            LogManager.logError(
                "ConfigurationManager - Failed to store ProtectedResourceMetadata in Keychain with key \(keyToSave): \(error)"
            )
        }

        // Restore original DID if we changed it
        if did != nil {
            self.did = originalDID
        }
    }

    func setAuthorizationServerMetadata(
        _ metadata: AuthorizationServerMetadata, forDID did: String? = nil
    ) async {
        // Use provided DID or fall back to the actor's current DID
        let targetDID = did ?? self.did
        LogManager.logInfo(
            "ConfigurationManager - Setting AuthorizationServerMetadata for DID: \(targetDID ?? "default")"
        )

        // Only update in-memory state if this is for the current DID
        if targetDID == self.did || (targetDID == nil && self.did == nil) {
            authorizationServerMetadata = metadata
        }

        // Temporarily store original DID
        let originalDID = self.did

        // Set the DID for key generation if a specific one was provided
        if let specificDID = targetDID {
            self.did = specificDID
        }

        // Generate the key with the appropriate DID
        let keyToSave = key("authorizationServerMetadata")
        LogManager.logDebug(
            "ConfigurationManager - Using key '\(keyToSave)' for saving AuthorizationServerMetadata")

        do {
            let data = try JSONEncoder().encode(metadata)
            try KeychainManager.store(
                key: keyToSave,
                value: data,
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug(
                "ConfigurationManager - Saved AuthorizationServerMetadata to Keychain with key \(keyToSave)"
            )
        } catch {
            LogManager.logError(
                "ConfigurationManager - Failed to store AuthorizationServerMetadata in Keychain with key \(keyToSave): \(error)"
            )
        }

        // Restore original DID if we changed it
        if did != nil {
            self.did = originalDID
        }
    }

    func setCurrentAuthorizationServer(_ url: URL, forDID did: String? = nil) async {
        // Use provided DID or fall back to the actor's current DID
        let targetDID = did ?? self.did
        LogManager.logInfo(
            "ConfigurationManager - Setting CurrentAuthorizationServer to: \(url) for DID: \(targetDID ?? "default")"
        )

        // Only update in-memory state if this is for the current DID
        if targetDID == self.did || (targetDID == nil && self.did == nil) {
            currentAuthorizationServer = url
        }

        // Temporarily store original DID
        let originalDID = self.did

        // Set the DID for key generation if a specific one was provided
        if let specificDID = targetDID {
            self.did = specificDID
        }

        // Generate the key with the appropriate DID
        let keyToSave = key("currentAuthorizationServer")
        LogManager.logDebug(
            "ConfigurationManager - Using key '\(keyToSave)' for saving CurrentAuthorizationServer")

        do {
            try KeychainManager.store(
                key: keyToSave,
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug(
                "ConfigurationManager - Saved CurrentAuthorizationServer to Keychain with key \(keyToSave)")
        } catch {
            LogManager.logError(
                "ConfigurationManager - Failed to store CurrentAuthorizationServer in Keychain with key \(keyToSave): \(error)"
            )
        }

        // Restore original DID if we changed it
        if did != nil {
            self.did = originalDID
        }
    }

    // MARK: - Helper Methods

    private func reloadSettings() async {
        await loadSettings()
    }

    func clearSettings() async {
        // Clear all stored settings
        do {
            // Delete all keychain items
            try KeychainManager.delete(key: key("baseURL"), namespace: namespace)
            try KeychainManager.delete(key: key("did"), namespace: namespace)
            try KeychainManager.delete(key: key("handle"), namespace: namespace)
            try KeychainManager.delete(key: key("pdsURL"), namespace: namespace)
            try KeychainManager.delete(key: key("currentAuthorizationServer"), namespace: namespace)
            try KeychainManager.delete(key: key("protectedResourceMetadata"), namespace: namespace)
            try KeychainManager.delete(key: key("authorizationServerMetadata"), namespace: namespace)

            try KeychainManager.delete(key: "baseURL.default", namespace: namespace)
            try KeychainManager.delete(key: "did.default", namespace: namespace)
            try KeychainManager.delete(key: "handle.default", namespace: namespace)
            try KeychainManager.delete(key: "pdsURL.default", namespace: namespace)

            LogManager.logDebug("ConfigurationManager - Cleared all settings from Keychain")
        } catch {
            LogManager.logError("ConfigurationManager - Error clearing settings from Keychain: \(error)")
        }

        // Reset properties
        baseURL = URL(string: "https://bsky.social")! // Set to default URL
        did = nil
        handle = nil
        pdsURL = nil
        protectedResourceMetadata = nil
        authorizationServerMetadata = nil
        currentAuthorizationServer = nil
    }

    // MARK: - Configuration Methods

    // Simplified key generation that prioritizes the explicit DID parameter
    private func keychainKey(for explicitDID: String? = nil, baseKey: String) -> String {
        let targetDID: String?

        if let explicit = explicitDID {
            targetDID = explicit
            LogManager.logError("CONFIG_KEY: Using explicit DID='\(explicit)' for baseKey='\(baseKey)'")
        } else if let current = did {
            targetDID = current
            LogManager.logError(
                "CONFIG_KEY: Using current actor DID='\(current)' for baseKey='\(baseKey)'")
        } else {
            // Try last active only if absolutely necessary (e.g., initial load)
            if let data = try? KeychainManager.retrieve(key: "lastActiveDID", namespace: namespace) {
                targetDID = String(data: data, encoding: .utf8)
            } else {
                targetDID = nil
            }
            LogManager.logError(
                "CONFIG_KEY: Using lastActiveDID='\(targetDID ?? "nil")' for baseKey='\(baseKey)'")
        }

        let userComponent = targetDID ?? "default"
        let finalKey = "\(baseKey).\(userComponent)"
        LogManager.logError("CONFIG_KEY: Final key='\(finalKey)' for baseKey='\(baseKey)'")
        return finalKey
    }

    // Replace existing key() method with keychainKey
    private func key(_ name: String) -> String {
        return keychainKey(for: nil, baseKey: name)
    }

    private func loadSettings() async {
        LogManager.logError(
            "CONFIG_LOAD: Starting to load settings from Keychain, current DID='\(did ?? "nil")'")

        // Try to load protected resource metadata first
        LogManager.logError("CONFIG_LOAD: Attempting to load ProtectedResourceMetadata")
        let metadataKey = key("protectedResourceMetadata")
        LogManager.logError("CONFIG_LOAD: Using key '\(metadataKey)' for ProtectedResourceMetadata")

        if let metadata = await getProtectedResourceMetadata() {
            LogManager.logError("CONFIG_LOAD: Retrieved metadata with resource URL: \(metadata.resource)")
            pdsURL = metadata.resource
            baseURL = metadata.resource
            LogManager.logInfo(
                "ConfigurationManager - Loaded PDS URL from ProtectedResourceMetadata: \(metadata.resource)"
            )
        } else {
            LogManager.logError("CONFIG_LOAD: No ProtectedResourceMetadata found, trying direct PDS URL")
            // Try to load PDS URL directly
            let pdsKey = key("pdsURL")
            LogManager.logError("CONFIG_LOAD: Using key '\(pdsKey)' for direct PDS URL lookup")
            do {
                let pdsURLData = try KeychainManager.retrieve(key: pdsKey, namespace: namespace)
                if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
                   let url = URL(string: pdsURLString)
                {
                    LogManager.logError("CONFIG_LOAD: Retrieved direct PDS URL: \(url)")
                    pdsURL = url
                    baseURL = url
                    LogManager.logInfo("ConfigurationManager - Loaded PDS URL from Keychain: \(url)")
                }
            } catch {
                LogManager.logError("CONFIG_LOAD: Failed to retrieve PDS URL: \(error)")
                LogManager.logDebug("ConfigurationManager - No PDS URL found in Keychain: \(error)")
            }
        }

        // Load DID
        let didKey = key("did")
        LogManager.logError("CONFIG_LOAD: Using key '\(didKey)' for DID lookup")
        do {
            let didData = try KeychainManager.retrieve(key: didKey, namespace: namespace)
            did = String(data: didData, encoding: .utf8)
            LogManager.logError("CONFIG_LOAD: Retrieved DID: \(did ?? "nil")")
            LogManager.logDebug("ConfigurationManager - Loaded DID from Keychain: \(did ?? "nil")")
        } catch {
            LogManager.logError("CONFIG_LOAD: Failed to retrieve DID: \(error)")
            LogManager.logDebug("ConfigurationManager - No DID found in Keychain")
        }

        // Load handle
        let handleKey = keychainKey(for: did, baseKey: "handle")
        LogManager.logError("CONFIG_LOAD: Using key '\(handleKey)' for handle lookup")
        do {
            let handleData = try KeychainManager.retrieve(key: handleKey, namespace: namespace)
            handle = String(data: handleData, encoding: .utf8)
            LogManager.logError("CONFIG_LOAD: Retrieved handle: \(handle ?? "nil")")
            LogManager.logDebug("ConfigurationManager - Loaded handle from Keychain: \(handle ?? "nil")")
        } catch {
            LogManager.logError("CONFIG_LOAD: Failed to retrieve handle: \(error)")
            LogManager.logDebug("ConfigurationManager - No handle found in Keychain")
        }

        // Load current authorization server
        let authServerKey = key("currentAuthorizationServer")
        LogManager.logError("CONFIG_LOAD: Using key '\(authServerKey)' for auth server lookup")
        do {
            let authServerData = try KeychainManager.retrieve(key: authServerKey, namespace: namespace)
            if let authServerString = String(data: authServerData, encoding: .utf8) {
                currentAuthorizationServer = URL(string: authServerString)
                LogManager.logError("CONFIG_LOAD: Retrieved auth server URL: \(authServerString)")
                LogManager.logInfo(
                    "ConfigurationManager - Loaded Authorization Server from Keychain: \(authServerString)")
            }
        } catch {
            LogManager.logError("CONFIG_LOAD: Failed to retrieve auth server: \(error)")
            LogManager.logDebug("ConfigurationManager - No Authorization Server found in Keychain")
        }

        // Load metadata objects
        LogManager.logError("CONFIG_LOAD: Loading metadata objects")
        await loadMetadata()

        LogManager.logError(
            "CONFIG_LOAD: Settings load complete. Final state: baseURL='\(baseURL)', pdsURL='\(String(describing: pdsURL))', did='\(String(describing: did))', handle='\(String(describing: handle))'"
        )
        LogManager.logDebug(
            "ConfigurationManager - Settings loaded. Current state: baseURL: \(baseURL), pdsURL: \(String(describing: pdsURL)), did: \(String(describing: did)), handle: \(String(describing: handle))"
        )
    }

    private func loadMetadata() async {
        // Load protected resource metadata
        do {
            let data = try KeychainManager.retrieve(
                key: key("protectedResourceMetadata"), namespace: namespace
            )
            protectedResourceMetadata = try JSONDecoder().decode(
                ProtectedResourceMetadata.self, from: data
            )
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata from Keychain")
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No ProtectedResourceMetadata found in Keychain: \(error)")
        }

        // Load authorization server metadata
        do {
            let data = try KeychainManager.retrieve(
                key: key("authorizationServerMetadata"), namespace: namespace
            )
            authorizationServerMetadata = try JSONDecoder().decode(
                AuthorizationServerMetadata.self, from: data
            )
            LogManager.logDebug("ConfigurationManager - Loaded AuthorizationServerMetadata from Keychain")
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No AuthorizationServerMetadata found in Keychain: \(error)")
        }
    }

    func getPDSURL() async -> URL? {
        if let pdsURL = pdsURL {
            LogManager.logDebug("ConfigurationManager - Returning cached PDS URL: \(pdsURL)")
            return pdsURL
        }

        do {
            let pdsURLData = try KeychainManager.retrieve(key: key("pdsURL"), namespace: namespace)
            if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
               let url = URL(string: pdsURLString)
            {
                pdsURL = url
                LogManager.logDebug("ConfigurationManager - Loaded PDS URL from Keychain: \(url)")
                return url
            }
        } catch {
            LogManager.logError("ConfigurationManager - No PDS URL found in Keychain: \(error)")
        }

        return nil
    }

    func getProtectedResourceMetadata() async -> ProtectedResourceMetadata? {
        LogManager.logError(
            "CONFIG_METADATA: Starting getProtectedResourceMetadata, current DID='\(did ?? "nil")'")

        if let metadata = protectedResourceMetadata {
            LogManager.logError(
                "CONFIG_METADATA: Returning cached metadata with resource URL: \(metadata.resource)")
            LogManager.logDebug("ConfigurationManager - Returning cached ProtectedResourceMetadata")
            return metadata
        }

        let metadataKey = key("protectedResourceMetadata")
        LogManager.logError("CONFIG_METADATA: No cached metadata, retrieving with key '\(metadataKey)'")

        do {
            let data = try KeychainManager.retrieve(key: metadataKey, namespace: namespace)

            // Log raw metadata for debugging
            if let rawString = String(data: data, encoding: .utf8) {
                LogManager.logError("CONFIG_METADATA: Raw metadata retrieved: \(rawString)")
            } else {
                LogManager.logError(
                    "CONFIG_METADATA: Raw metadata retrieved but couldn't be converted to string")
            }

            let metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
            LogManager.logError(
                "CONFIG_METADATA: Successfully decoded metadata with resource URL: \(metadata.resource)")
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata from Keychain")
            protectedResourceMetadata = metadata
            return metadata
        } catch {
            LogManager.logError("CONFIG_METADATA: Failed to retrieve/decode metadata: \(error)")
            LogManager.logDebug(
                "ConfigurationManager - No ProtectedResourceMetadata found in Keychain: \(error)")
            return nil
        }
    }

    func getBaseURL() async -> URL {
        return baseURL
    }

    func getHandle() async -> String? {
//        if let handle = handle {
//            return handle
//        }
//
        do {
            let handleData = try KeychainManager.retrieve(key: keychainKey(for: did, baseKey: "handle"), namespace: namespace)
            let handleString = String(data: handleData, encoding: .utf8)
            handle = handleString
            return handleString
        } catch {
            LogManager.logDebug("ConfigurationManager - No handle found in Keychain: \(error)")
            return nil
        }
    }

    func getDID() async -> String? {
        if let did = did {
            return did
        }

        do {
            let didData = try KeychainManager.retrieve(key: key("did"), namespace: namespace)
            let didString = String(data: didData, encoding: .utf8)
            did = didString
            return didString
        } catch {
            LogManager.logDebug("ConfigurationManager - No DID found in Keychain: \(error)")
            return nil
        }
    }

    func getAuthorizationServerMetadata() async -> AuthorizationServerMetadata? {
        if let metadata = authorizationServerMetadata {
            return metadata
        }

        do {
            let data = try KeychainManager.retrieve(
                key: key("authorizationServerMetadata"), namespace: namespace
            )
            let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
            authorizationServerMetadata = metadata
            return metadata
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No AuthorizationServerMetadata found in Keychain: \(error)")
            return nil
        }
    }

    func getCurrentAuthorizationServer() async -> URL? {
        if let server = currentAuthorizationServer {
            return server
        }

        do {
            let serverData = try KeychainManager.retrieve(
                key: key("currentAuthorizationServer"), namespace: namespace
            )
            if let serverString = String(data: serverData, encoding: .utf8),
               let serverURL = URL(string: serverString)
            {
                currentAuthorizationServer = serverURL
                return serverURL
            }
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No current authorization server found in Keychain: \(error)")
        }

        return nil
    }

    // MARK: - Multi-Account Support

    private let accountsListKey = "storedAccounts" // Key to store list of accounts

    /// Creates a user-specific key by combining the base key with a DID
    private func userSpecificKey(_ baseKey: String, did: String? = nil) -> String {
        return keychainKey(for: did, baseKey: baseKey)
    }

    /// Switches to a different account
    func switchToAccount(did: String) async -> Bool {
        // Save current state if we have a DID
        if let currentDID = self.did {
            // Add to accounts list
            await addToAccountsList(currentDID)
        }

        // Update current DID
        self.did = did

        // Load settings for the new DID
        let success = await loadSettingsForDID(did)

        if success {
            // Add to accounts list
            await addToAccountsList(did)

            // Publish account switched event
            await EventBus.shared.publish(.accountSwitched(did: did))
            LogManager.logInfo("ConfigurationManager - Switched to account: \(did)")
        } else {
            LogManager.logError("ConfigurationManager - Failed to load settings for DID: \(did)")
        }

        return success
    }

    /// Loads settings for a specific DID
    private func loadSettingsForDID(_ didToLoad: String) async -> Bool {
        LogManager.logError("CONFIG_LOAD_DID: Loading settings specifically for DID='\(didToLoad)'")

        // Update the actor's DID first
        did = didToLoad
        LogManager.logError("CONFIG_LOAD_DID: Set internal actor state did='\(didToLoad)'")

        // Use the keychainKey method to generate specific keys for this DID
        let handleKey = keychainKey(for: didToLoad, baseKey: "handle")
        let pdsKey = keychainKey(for: didToLoad, baseKey: "pdsURL")
        let protectedResourceMetadataKey = keychainKey(
            for: didToLoad, baseKey: "protectedResourceMetadata"
        )
        let authorizationServerMetadataKey = keychainKey(
            for: didToLoad, baseKey: "authorizationServerMetadata"
        )
        let authServerKey = keychainKey(for: didToLoad, baseKey: "currentAuthorizationServer")

        LogManager.logError(
            "CONFIG_LOAD_DID: Using keys: handle='\(handleKey)', pdsURL='\(pdsKey)', meta='\(protectedResourceMetadataKey)'"
        )

        // Load PDS URL (try protected resource metadata first)
        var loadedPDS: URL? = nil

        // Load Protected Resource Metadata
        do {
            let data = try KeychainManager.retrieve(
                key: protectedResourceMetadataKey, namespace: namespace
            )
            let loadedMeta = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
            protectedResourceMetadata = loadedMeta
            loadedPDS = loadedMeta.resource
            LogManager.logError(
                "CONFIG_LOAD_DID: Loaded PDS='\(loadedPDS?.absoluteString ?? "nil")' from Metadata for DID='\(didToLoad)'"
            )
        } catch {
            LogManager.logError(
                "CONFIG_LOAD_DID: No metadata found for DID='\(didToLoad)', trying direct PDS URL. Error: \(error)"
            )
            protectedResourceMetadata = nil

            // Try loading PDS URL directly
            do {
                let pdsURLData = try KeychainManager.retrieve(key: pdsKey, namespace: namespace)
                if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
                   let url = URL(string: pdsURLString)
                {
                    loadedPDS = url
                    LogManager.logError("CONFIG_LOAD_DID: Loaded direct PDS='\(url)' for DID='\(didToLoad)'")
                }
            } catch {
                LogManager.logError("CONFIG_LOAD_DID: Failed to retrieve direct PDS URL: \(error)")
            }
        }

        // Load handle
        do {
            let handleData = try KeychainManager.retrieve(key: handleKey, namespace: namespace)
            handle = String(data: handleData, encoding: .utf8)
            LogManager.logError(
                "CONFIG_LOAD_DID: Loaded handle='\(handle ?? "nil")' for DID='\(didToLoad)'")
        } catch {
            handle = nil
            LogManager.logError("CONFIG_LOAD_DID: No handle found for DID='\(didToLoad)': \(error)")
        }

        // Load Authorization Server Metadata
        do {
            let data = try KeychainManager.retrieve(
                key: authorizationServerMetadataKey, namespace: namespace
            )
            authorizationServerMetadata = try JSONDecoder().decode(
                AuthorizationServerMetadata.self, from: data
            )
            LogManager.logError(
                "CONFIG_LOAD_DID: Loaded AuthorizationServerMetadata for DID='\(didToLoad)'")
        } catch {
            authorizationServerMetadata = nil
            LogManager.logError(
                "CONFIG_LOAD_DID: No AuthorizationServerMetadata found for DID='\(didToLoad)': \(error)")
        }

        // Load current Authorization Server URL
        do {
            let authServerData = try KeychainManager.retrieve(key: authServerKey, namespace: namespace)
            if let authServerString = String(data: authServerData, encoding: .utf8) {
                currentAuthorizationServer = URL(string: authServerString)
                LogManager.logError(
                    "CONFIG_LOAD_DID: Loaded CurrentAuthorizationServer='\(authServerString)' for DID='\(didToLoad)'"
                )
            }
        } catch {
            currentAuthorizationServer = nil
            LogManager.logError(
                "CONFIG_LOAD_DID: No CurrentAuthorizationServer found for DID='\(didToLoad)': \(error)")
        }

        // Update the actor's main URL properties
        pdsURL = loadedPDS
        if let loadedPDS = loadedPDS {
            baseURL = loadedPDS
            LogManager.logError("CONFIG_LOAD_DID: Updated actor baseURL/pdsURL to '\(loadedPDS)'")
        }

        LogManager.logError(
            "CONFIG_LOAD_DID: Finished loading. Actor state: baseURL=\(baseURL), pdsURL=\(pdsURL?.absoluteString ?? "nil"), handle=\(handle ?? "nil"), did=\(did ?? "nil")"
        )

        return true
    }

    /// Loads metadata for a specific DID
    private func loadMetadataForDID(_ did: String) async {
        // Load protected resource metadata
        do {
            let data = try KeychainManager.retrieve(
                key: userSpecificKey("protectedResourceMetadata", did: did), namespace: namespace
            )
            protectedResourceMetadata = try JSONDecoder().decode(
                ProtectedResourceMetadata.self, from: data
            )
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata for DID \(did)")
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No ProtectedResourceMetadata found for DID \(did): \(error)")
            protectedResourceMetadata = nil
        }

        // Load authorization server metadata
        do {
            let data = try KeychainManager.retrieve(
                key: userSpecificKey("authorizationServerMetadata", did: did), namespace: namespace
            )
            authorizationServerMetadata = try JSONDecoder().decode(
                AuthorizationServerMetadata.self, from: data
            )
            LogManager.logDebug(
                "ConfigurationManager - Loaded AuthorizationServerMetadata for DID \(did)")
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No AuthorizationServerMetadata found for DID \(did): \(error)")
            authorizationServerMetadata = nil
        }
    }

    /// Adds a DID to the accounts list
    private func addToAccountsList(_ did: String) async {
        var accounts = await listAccounts()
        if !accounts.contains(did) {
            accounts.append(did)
            do {
                let data = try JSONEncoder().encode(accounts)
                try KeychainManager.store(key: accountsListKey, value: data, namespace: namespace)
                LogManager.logDebug("ConfigurationManager - Added DID to accounts list: \(did)")
            } catch {
                LogManager.logError("ConfigurationManager - Failed to save accounts list: \(error)")
            }
        }
    }

    /// Lists all accounts
    func listAccounts() async -> [String] {
        do {
            let data = try KeychainManager.retrieve(key: accountsListKey, namespace: namespace)
            let accounts = try JSONDecoder().decode([String].self, from: data)
            return accounts
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No stored accounts found or error retrieving them: \(error)")
            return []
        }
    }

    /// Removes an account
    func removeAccount(did: String) async throws {
        // Remove all user-specific settings
        try KeychainManager.delete(key: userSpecificKey("handle", did: did), namespace: namespace)
        try KeychainManager.delete(key: userSpecificKey("pdsURL", did: did), namespace: namespace)
        try KeychainManager.delete(
            key: userSpecificKey("protectedResourceMetadata", did: did), namespace: namespace
        )
        try KeychainManager.delete(
            key: userSpecificKey("authorizationServerMetadata", did: did), namespace: namespace
        )
        try KeychainManager.delete(
            key: userSpecificKey("currentAuthorizationServer", did: did), namespace: namespace
        )

        // Remove from accounts list
        var accounts = await listAccounts()
        accounts.removeAll { $0 == did }
        let data = try JSONEncoder().encode(accounts)
        try KeychainManager.store(key: accountsListKey, value: data, namespace: namespace)

        LogManager.logInfo("ConfigurationManager - Removed account: \(did)")

        // If this was the current DID, reset to another account or default state
        if self.did == did {
            if let firstAccount = accounts.first {
                await switchToAccount(did: firstAccount)
            } else {
                self.did = nil
                handle = nil
                pdsURL = nil
                protectedResourceMetadata = nil
                authorizationServerMetadata = nil
                currentAuthorizationServer = nil

                await clearSettings()
            }
        }
    }

    // MARK: - Multi-Account Getters

    func getDID(forAccount did: String) async -> String? {
        return did // The account DID is the DID itself
    }

    func getHandle(forAccount did: String) async -> String? {
//        if did == self.did, let handle = handle {
//            return handle
//        }
//
        do {
            let handleData = try KeychainManager.retrieve(
                key: userSpecificKey("handle", did: did), namespace: namespace
            )
            let handleString = String(data: handleData, encoding: .utf8)
            return handleString
        } catch {
            LogManager.logDebug("ConfigurationManager - No handle found for DID \(did): \(error)")
            return nil
        }
    }

    func getPDSURL(forAccount did: String) async -> URL? {
        if did == self.did, let pdsURL = pdsURL {
            return pdsURL
        }

        do {
            let pdsURLData = try KeychainManager.retrieve(
                key: userSpecificKey("pdsURL", did: did), namespace: namespace
            )
            if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
               let url = URL(string: pdsURLString)
            {
                return url
            }
        } catch {
            LogManager.logDebug("ConfigurationManager - No PDS URL found for DID \(did): \(error)")
        }

        return nil
    }

    func getProtectedResourceMetadata(forAccount did: String) async -> ProtectedResourceMetadata? {
        if did == self.did, let metadata = protectedResourceMetadata {
            return metadata
        }

        do {
            let data = try KeychainManager.retrieve(
                key: userSpecificKey("protectedResourceMetadata", did: did), namespace: namespace
            )
            return try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No ProtectedResourceMetadata found for DID \(did): \(error)")
            return nil
        }
    }

    func getAuthorizationServerMetadata(forAccount did: String) async -> AuthorizationServerMetadata? {
        if did == self.did, let metadata = authorizationServerMetadata {
            return metadata
        }

        do {
            let data = try KeychainManager.retrieve(
                key: userSpecificKey("authorizationServerMetadata", did: did), namespace: namespace
            )
            return try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
        } catch {
            LogManager.logDebug(
                "ConfigurationManager - No AuthorizationServerMetadata found for DID \(did): \(error)")
            return nil
        }
    }
}

// MARK: - ConfigurationManagerError Enum

enum ConfigurationManagerError: Error {
    case invalidURL
    case dataNotFound
}
