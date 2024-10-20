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
        LogManager.logDebug("ConfigurationManager initialized with baseURL: \(baseURL), namespace: \(namespace)")
        await loadSettings()
//            await subscribeToEvents()
//            await markInitializationComplete()
    }

    // MARK: - Event Subscription

    // ConfigurationManager.swift

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .baseURLUpdated(let newURL):
//                await updateBaseURL(newURL)
//            case .pdsURLResolved(let url):
//                await updatePDSURL(url)
//            case .didResolved(let did):
//                await updateDID(did: did)
//            case .handleResolved(let handle):
//                await updateHandle(handle)
//            case .userConfigurationUpdated(let did, let handle, let serviceEndpoint):
//                // Handle user configuration update if needed
//                LogManager.logInfo("ConfigurationManager - User configuration updated with DID: \(did), Handle: \(handle), Service Endpoint: \(serviceEndpoint)")
//            case .sessionInitialized:
//                await reloadSettings()
//            case .sessionExpired:
//                await clearSettings()
            default:
                break
            }
        }
    }

    // MARK: - Configuration Methods

    // ConfigurationManager.swift

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
        UserDefaults.standard.set(url.absoluteString, forKey: key("baseURL"))
        await EventBus.shared.publish(.baseURLUpdated(url))
    }

    /// Note: PDS and Service Endpoint are the same
    func updatePDSURL(_ url: URL) async {
        LogManager.logInfo("ConfigurationManager - Updating PDS URL to: \(url)")
        pdsURL = url
        baseURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: key("pdsURL"))
        await EventBus.shared.publish(.pdsURLResolved(url))
    }

    func updateDID(did: String) async {
        self.did = did
        UserDefaults.standard.set(did, forKey: key("did"))
        await EventBus.shared.publish(.didResolved(did: did))
    }

    /// Updates the user's handle.
    ///
    /// - Parameter handle: The user's handle.
    func updateHandle(_ handle: String) async {
        self.handle = handle
        UserDefaults.standard.set(handle, forKey: key("handle"))
        await EventBus.shared.publish(.handleResolved(handle: handle))
    }

    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata) async {
        LogManager.logInfo("ConfigurationManager - Setting ProtectedResourceMetadata with resource: \(metadata.resource)")
        protectedResourceMetadata = metadata
        saveMetadata()
    }

    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata) async {
        authorizationServerMetadata = metadata
        saveMetadata()
//        await EventBus.shared.publish(.authorizationServerMetadataUpdated(metadata))
    }

    func setCurrentAuthorizationServer(_ url: URL) async {
        currentAuthorizationServer = url
        UserDefaults.standard.set(url.absoluteString, forKey: key("currentAuthorizationServer"))
//        await EventBus.shared.publish(.currentAuthorizationServerUpdated(url))
    }

    // MARK: - Helper Methods

    private func reloadSettings() async {
        await loadSettings()
//        await EventBus.shared.publish(.configurationReloaded)
    }

    private func clearSettings() async {
        // Clear all stored settings
        UserDefaults.standard.removeObject(forKey: key("baseURL"))
        UserDefaults.standard.removeObject(forKey: key("did"))
        UserDefaults.standard.removeObject(forKey: key("handle"))
        UserDefaults.standard.removeObject(forKey: key("pdsURL"))
        UserDefaults.standard.removeObject(forKey: key("currentAuthorizationServer"))
        UserDefaults.standard.removeObject(forKey: key("protectedResourceMetadata"))
        UserDefaults.standard.removeObject(forKey: key("authorizationServerMetadata"))

        // Reset properties
        baseURL = URL(string: "https://bsky.social")! // Set to default URL
        did = nil
        handle = nil
        pdsURL = nil
        protectedResourceMetadata = nil
        authorizationServerMetadata = nil
        currentAuthorizationServer = nil

//        await EventBus.shared.publish(.configurationCleared)
    }

    // MARK: - Configuration Methods

    private func key(_ name: String) -> String {
        return "\(namespace).\(name)"
    }

    // ConfigurationManager.swift

    private func loadSettings() async {
        LogManager.logDebug("ConfigurationManager - Loading settings")
        if let metadata = await getProtectedResourceMetadata() {
            pdsURL = metadata.resource
            baseURL = metadata.resource
            LogManager.logInfo("ConfigurationManager - Loaded PDS URL from ProtectedResourceMetadata: \(metadata.resource)")
        } else if let pdsURLString = UserDefaults.standard.string(forKey: key("pdsURL")),
                  let pdsURL = URL(string: pdsURLString)
        {
            self.pdsURL = pdsURL
            baseURL = pdsURL
            LogManager.logInfo("ConfigurationManager - Loaded PDS URL from UserDefaults: \(pdsURL)")
        } else {
            LogManager.logError("ConfigurationManager - No PDS URL found in ProtectedResourceMetadata or UserDefaults")
        }

        did = UserDefaults.standard.string(forKey: key("did"))
        handle = UserDefaults.standard.string(forKey: key("handle"))

        if let authServerURLString = UserDefaults.standard.string(forKey: key("currentAuthorizationServer")) {
            currentAuthorizationServer = URL(string: authServerURLString)
            LogManager.logInfo("ConfigurationManager - Loaded Authorization Server: \(authServerURLString)")
        }

        await loadMetadata()

        LogManager.logDebug("ConfigurationManager - Settings loaded. Current state: baseURL: \(baseURL), pdsURL: \(String(describing: pdsURL)), did: \(String(describing: did)), handle: \(String(describing: handle))")
    }

    private func loadMetadata() async {
        if let protectedResourceData = UserDefaults.standard.data(forKey: key("protectedResourceMetadata")),
           let metadata = try? JSONDecoder().decode(ProtectedResourceMetadata.self, from: protectedResourceData)
        {
            protectedResourceMetadata = metadata
            // Optionally, publish an event if needed
        }
        if let authServerData = UserDefaults.standard.data(forKey: key("authorizationServerMetadata")),
           let metadata = try? JSONDecoder().decode(AuthorizationServerMetadata.self, from: authServerData)
        {
            authorizationServerMetadata = metadata
            // Optionally, publish an event if needed
        }
    }

    private func saveMetadata() {
        if let protectedResourceData = try? JSONEncoder().encode(protectedResourceMetadata) {
            UserDefaults.standard.set(protectedResourceData, forKey: key("protectedResourceMetadata"))
            LogManager.logDebug("ConfigurationManager - Saved ProtectedResourceMetadata to UserDefaults")
        } else {
            LogManager.logError("ConfigurationManager - Failed to encode ProtectedResourceMetadata")
        }

        if let authServerData = try? JSONEncoder().encode(authorizationServerMetadata) {
            UserDefaults.standard.set(authServerData, forKey: key("authorizationServerMetadata"))
        }
    }

    func getPDSURL() async -> URL? {
        if let pdsURL = pdsURL {
            LogManager.logDebug("ConfigurationManager - Returning cached PDS URL: \(pdsURL)")
            return pdsURL
        }
        if let pdsURLString = UserDefaults.standard.string(forKey: key("pdsURL")),
           let url = URL(string: pdsURLString)
        {
            pdsURL = url
            LogManager.logDebug("ConfigurationManager - Loaded PDS URL from UserDefaults: \(url)")
            return url
        }
        LogManager.logError("ConfigurationManager - No PDS URL found")
        return nil
    }

    func getProtectedResourceMetadata() async -> ProtectedResourceMetadata? {
        if let metadata = protectedResourceMetadata {
            LogManager.logDebug("ConfigurationManager - Returning cached ProtectedResourceMetadata")
            return metadata
        }
        if let data = UserDefaults.standard.data(forKey: key("protectedResourceMetadata")),
           let metadata = try? JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
        {
            LogManager.logDebug("ConfigurationManager - Loaded ProtectedResourceMetadata from UserDefaults")
            return metadata
        }
        LogManager.logError("ConfigurationManager - No ProtectedResourceMetadata found")
        return nil
    }

    func getBaseURL() async -> URL {
        return baseURL
    }

    func getHandle() async -> String? {
        return handle
    }

    func getDID() async -> String? {
        return did
    }

    func getAuthorizationServerMetadata() async -> AuthorizationServerMetadata? {
        return authorizationServerMetadata
    }

    func getCurrentAuthorizationServer() async -> URL? {
        return currentAuthorizationServer
    }
}

// MARK: - ConfigurationManagerError Enum

enum ConfigurationManagerError: Error {
    case invalidURL
    case dataNotFound
}
