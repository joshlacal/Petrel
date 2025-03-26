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
    func getHandle() async -> String?
    func updatePDSURL(_ url: URL) async
    func getPDSURL() async -> URL?
    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata) async
    func getProtectedResourceMetadata() async -> ProtectedResourceMetadata?
    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata) async
    func getAuthorizationServerMetadata() async -> AuthorizationServerMetadata?
    func setCurrentAuthorizationServer(_ url: URL) async
    func getCurrentAuthorizationServer() async -> URL?
    func updateHandle(_ handle: String) async
}

// MARK: - ConfigurationManager Actor

actor ConfigurationManager: ConfigurationManaging {
    // MARK: - Properties

    private var isUpdating = false
    private let accountManager: AccountManaging
    private(set) var baseURL: URL
    private var pdsURL: URL?
    private var did: String?
    private var handle: String?
    private var protectedResourceMetadata: ProtectedResourceMetadata?
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var currentAuthorizationServer: URL?

    // MARK: - Initialization

    init(baseURL: URL, accountManager: AccountManaging) async {
        self.accountManager = accountManager
        self.baseURL = baseURL
        LogManager.logDebug("ConfigurationManager initialized with baseURL: \(baseURL)")
        await loadSettings()
        await subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
            case .activeAccountChanged:
                // Reload settings when active account changes
                await loadSettings()
            default:
                break
            }
        }
    }

    // MARK: - Helper Methods

    private func key(_ name: String) async -> String {
        if let did = await accountManager.getActiveAccountDID() {
            return "\(did).\(name)"
        } else {
            // Fall back to using "global" namespace when no account is active
            return "global.\(name)"
        }
    }

    private func loadSettings() async {
        LogManager.logDebug("ConfigurationManager - Loading settings from Keychain")

        // Get the namespace key
        let namespace = await key("")

        // Try to load protected resource metadata first
        if let metadata = await getProtectedResourceMetadata() {
            pdsURL = metadata.resource
            baseURL = metadata.resource
            LogManager.logInfo("ConfigurationManager - Loaded PDS URL from ProtectedResourceMetadata: \(metadata.resource)")
        } else {
            // Try to load PDS URL directly
            do {
                let pdsURLData = try KeychainManager.retrieve(key: await key("pdsURL"), namespace: namespace)
                if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
                   let url = URL(string: pdsURLString) {
                    pdsURL = url
                    baseURL = url
                    LogManager.logInfo("ConfigurationManager - Loaded PDS URL from Keychain: \(url)")
                }
            } catch {
                LogManager.logDebug("ConfigurationManager - No PDS URL found in Keychain: \(error)")
            }
        }

        // Load DID
        do {
            let didData = try KeychainManager.retrieve(key: await key("did"), namespace: namespace)
            did = String(data: didData, encoding: .utf8)
            LogManager.logDebug("ConfigurationManager - Loaded DID from Keychain: \(did ?? "nil")")
        } catch {
            LogManager.logDebug("ConfigurationManager - No DID found in Keychain")
        }

        // Load handle
        do {
            let handleData = try KeychainManager.retrieve(key: await key("handle"), namespace: namespace)
            handle = String(data: handleData, encoding: .utf8)
            LogManager.logDebug("ConfigurationManager - Loaded handle from Keychain: \(handle ?? "nil")")
        } catch {
            LogManager.logDebug("ConfigurationManager - No handle found in Keychain")
        }

        // Load metadata objects
        await loadMetadata()
    }

    private func loadMetadata() async {
        let namespace = await key("")
        // Load protected resource metadata
        do {
            let data = try KeychainManager.retrieve(key: await key("protectedResourceMetadata"), namespace: namespace)
            protectedResourceMetadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata from Keychain")
        } catch {
            LogManager.logDebug("ConfigurationManager - No ProtectedResourceMetadata found in Keychain: \(error)")
        }

        // Load authorization server metadata
        do {
            let data = try KeychainManager.retrieve(key: await key("authorizationServerMetadata"), namespace: namespace)
            authorizationServerMetadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
            LogManager.logDebug("ConfigurationManager - Loaded AuthorizationServerMetadata from Keychain")
        } catch {
            LogManager.logDebug("ConfigurationManager - No AuthorizationServerMetadata found in Keychain: \(error)")
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
        await EventBus.shared.publish(.userConfigurationUpdated(did: did, handle: handle, serviceEndpoint: serviceEndpoint))
    }

    func updateBaseURL(_ url: URL) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        baseURL = url

        do {
            try KeychainManager.store(
                key: await key("baseURL"),
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store baseURL in Keychain: \(error)")
        }

        await EventBus.shared.publish(.baseURLUpdated(url))
    }

    func updatePDSURL(_ url: URL) async {
        LogManager.logInfo("ConfigurationManager - Updating PDS URL to: \(url)")
        pdsURL = url
        baseURL = url

        do {
            try KeychainManager.store(
                key: await key("pdsURL"),
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store pdsURL in Keychain: \(error)")
        }

        await EventBus.shared.publish(.pdsURLResolved(url))
    }

    func updateDID(did: String) async {
        self.did = did

        do {
            try KeychainManager.store(
                key: await key("did"),
                value: did.data(using: .utf8) ?? Data(),
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store DID in Keychain: \(error)")
        }

        await EventBus.shared.publish(.didResolved(did: did))
    }

    func updateHandle(_ handle: String) async {
        self.handle = handle

        do {
            try KeychainManager.store(
                key: await key("handle"),
                value: handle.data(using: .utf8) ?? Data(),
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store handle in Keychain: \(error)")
        }

        await EventBus.shared.publish(.handleResolved(handle: handle))
    }

    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata) async {
        protectedResourceMetadata = metadata

        do {
            let data = try JSONEncoder().encode(metadata)
            try KeychainManager.store(
                key: await key("protectedResourceMetadata"),
                value: data,
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug("ConfigurationManager - Saved ProtectedResourceMetadata to Keychain")
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store ProtectedResourceMetadata in Keychain: \(error)")
        }
    }

    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata) async {
        authorizationServerMetadata = metadata

        do {
            let data = try JSONEncoder().encode(metadata)
            try KeychainManager.store(
                key: await key("authorizationServerMetadata"),
                value: data,
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug("ConfigurationManager - Saved AuthorizationServerMetadata to Keychain")
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store AuthorizationServerMetadata in Keychain: \(error)")
        }
    }

    func setCurrentAuthorizationServer(_ url: URL) async {
        currentAuthorizationServer = url

        do {
            try KeychainManager.store(
                key: await key("currentAuthorizationServer"),
                value: url.absoluteString.data(using: .utf8) ?? Data(),
                namespace: await key(""),
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
        } catch {
            LogManager.logError("ConfigurationManager - Failed to store currentAuthorizationServer in Keychain: \(error)")
        }
    }

    func getPDSURL() async -> URL? {
        if let pdsURL = pdsURL {
            LogManager.logDebug("ConfigurationManager - Returning cached PDS URL: \(pdsURL)")
            return pdsURL
        }

        do {
            let pdsURLData = try KeychainManager.retrieve(key: await key("pdsURL"), namespace: await key(""))
            if let pdsURLString = String(data: pdsURLData, encoding: .utf8),
               let url = URL(string: pdsURLString) {
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
        if let metadata = protectedResourceMetadata {
            LogManager.logDebug("ConfigurationManager - Returning cached ProtectedResourceMetadata")
            return metadata
        }

        do {
            let data = try KeychainManager.retrieve(key: await key("protectedResourceMetadata"), namespace: await key(""))
            let metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata from Keychain")
            protectedResourceMetadata = metadata
            return metadata
        } catch {
            LogManager.logDebug("ConfigurationManager - No ProtectedResourceMetadata found in Keychain: \(error)")
            return nil
        }
    }

    func getBaseURL() async -> URL {
        return baseURL
    }

    func getHandle() async -> String? {
        if let handle = handle {
            return handle
        }

        do {
            let handleData = try KeychainManager.retrieve(key: await key("handle"), namespace: await key(""))
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
            let didData = try KeychainManager.retrieve(key: await key("did"), namespace: await key(""))
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
            let data = try KeychainManager.retrieve(key: await key("authorizationServerMetadata"), namespace: await key(""))
            let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
            authorizationServerMetadata = metadata
            return metadata
        } catch {
            LogManager.logDebug("ConfigurationManager - No AuthorizationServerMetadata found in Keychain: \(error)")
            return nil
        }
    }

    func getCurrentAuthorizationServer() async -> URL? {
        if let server = currentAuthorizationServer {
            return server
        }

        do {
            let serverData = try KeychainManager.retrieve(key: await key("currentAuthorizationServer"), namespace: await key(""))
            if let serverString = String(data: serverData, encoding: .utf8),
               let serverURL = URL(string: serverString) {
                currentAuthorizationServer = serverURL
                return serverURL
            }
        } catch {
            LogManager.logDebug("ConfigurationManager - No current authorization server found in Keychain: \(error)")
        }

        return nil
    }

    // MARK: - Helper Methods

    private func clearSettings() async {
        let namespace = await key("")
        // Clear all stored settings
        do {
            // Delete all keychain items
            try KeychainManager.delete(key: await key("baseURL"), namespace: namespace)
            try KeychainManager.delete(key: await key("did"), namespace: namespace)
            try KeychainManager.delete(key: await key("handle"), namespace: namespace)
            try KeychainManager.delete(key: await key("pdsURL"), namespace: namespace)
            try KeychainManager.delete(key: await key("currentAuthorizationServer"), namespace: namespace)
            try KeychainManager.delete(key: await key("protectedResourceMetadata"), namespace: namespace)
            try KeychainManager.delete(key: await key("authorizationServerMetadata"), namespace: namespace)

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
}

// MARK: - ConfigurationManagerError Enum

enum ConfigurationManagerError: Error {
    case invalidURL
    case dataNotFound
}
