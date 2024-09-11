//
//  ATProtoClientGeneratedMain.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/24.
//

import Foundation
internal import ZippyJSON

enum APIError: String, Error {
    case expiredToken = "ExpiredToken"
    case invalidToken
    case invalidResponse
}

public struct OAuthConfiguration: Sendable {
    public let clientId: String
    public let redirectUri: String
    public let scopes: [String]

    public init(clientId: String, redirectUri: String, scopes: [String]) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scopes = scopes
    }
}

enum InitializationState {
    case uninitialized
    case initializing
    case ready
    case failed(Error)
}

public enum ClientEnvironment: Sendable {
    case production
    case testing
}

public actor ATProtoClient: AuthenticationDelegate, OAuthHandling {
    public var baseURL: URL
    private let configManager: ConfigurationManaging
    private let sessionManager: SessionManaging
    private var networkManager: NetworkManaging
    private let tokenManager: TokenManaging
    private let authService: AuthenticationService
    private let oauthManager: OAuthManager
    private let oauthConfig: OAuthConfiguration
    private let authenticationManager: AuthenticationManaging
    private let middlewareService: MiddlewareService

    private(set) var initState: InitializationState = .uninitialized
    public weak var authDelegate: AuthenticationDelegate?

    // User-related properties
    var did: String?
    var handle: String?

    public init(oauthConfig: OAuthConfiguration, baseURL: URL, environment _: ClientEnvironment) {
        self.oauthConfig = oauthConfig
        self.baseURL = baseURL
        configManager = ConfigurationManager(baseURL: baseURL)
        tokenManager = TokenManager()
        networkManager = NetworkManager(baseURL: baseURL, configurationManager: configManager)

        // Create AuthenticationService without SessionManager
        authService = AuthenticationService(
            networkManager: networkManager,
            tokenManager: tokenManager,
            configurationManager: configManager
        )

        // Now create SessionManager with AuthenticationService
        sessionManager = SessionManager(tokenManager: tokenManager, authService: authService)

        // Create MiddlewareService
        middlewareService = MiddlewareService(sessionManager: sessionManager, tokenManager: tokenManager, authDelegate: nil, client: nil)

        oauthManager = OAuthManager(networkManager: networkManager, configurationManager: configManager, tokenManager: tokenManager, oauthConfig: oauthConfig)

        authenticationManager = AuthenticationManager(authService: authService)

        // Set up middleware and async tasks
        Task {
            await setupPostInit()
        }
    }

    private func setupPostInit() async {
        await configManager.setDelegate(networkManager)
        await tokenManager.setDelegate(sessionManager)
        await networkManager.setMiddlewareService(middlewareService: middlewareService)
        await authService.setOAuthHandler(self)
        await authenticationManager.setClient(self)
        await middlewareService.setClient(self)

        // Fetch JWKS asynchronously
        Task {
            do {
                try await tokenManager.fetchAuthServerMetadataAndJWKS(baseURL: baseURL)
            } catch {
                LogManager.logError("Failed to fetch authorization server metadata and JWKS: \(error)")
            }
        }
    }

    public func login(identifier: String, password: String) async throws {
        try await authenticationManager.createSession(identifier: identifier, password: password)
    }

    public func startOAuthFlow(identifier: String) async throws -> URL {
        return try await oauthManager.startOAuthFlow(identifier: identifier)
    }

    public func handleOAuthCallback(url: URL) async throws {
        let (accessToken, refreshToken) = try await oauthManager.handleCallback(url: url)
        try await tokenManager.saveTokens(accessJwt: accessToken, refreshJwt: refreshToken)
        // Update client state as needed
        did = await configManager.getDID()
        handle = await configManager.getHandle()
    }

    public func logout() async throws {
        do {
            await sessionManager.clearSession()
            try KeychainManager.delete(key: "accessJwt")
            try KeychainManager.delete(key: "refreshJwt")
        } catch {
            print("Logout failed: \(error)")
            throw error
        }
        Task.detached { [weak self] in
            guard let self = self else { return }
            await authDelegate?.authenticationRequired(client: self)
        }
    }

    // MARK: - Utility Functions

    public func getHandle() -> String? {
        return handle
    }

    public func getDid() async -> String? {
        return await configManager.getDID()
    }

    public func refreshToken() async throws -> Bool {
        do {
            return try await authService.refreshTokenIfNeeded()
        } catch {
            LogManager.logError("ATProtoClient - Failed to refresh token: \(error)")
            throw error
        }
    }

    public func hasValidSession() async -> Bool {
        LogManager.logDebug("ATProtoClient - Checking for valid session")
        do {
            let isValid = await sessionManager.hasValidSession()
            if !isValid {
                // Attempt to refresh the token if the session is not valid
                return try await refreshToken()
            }
            LogManager.logInfo("ATProtoClient - Session is valid")
            return true
        } catch {
            LogManager.logError("ATProtoClient - Session is invalid and token refresh failed: \(error)")
            return false
        }
    }

    public func initializeSession() async throws {
        LogManager.logInfo("ATProtoClient - Initializing session")
        do {
            try await sessionManager.initializeIfNeeded()
            let isValid = await hasValidSession() // This now includes an attempt to refresh if needed
            if isValid {
                LogManager.logInfo("ATProtoClient - Valid session established")
                did = await configManager.getDID()
                handle = await configManager.getHandle()
            } else {
                LogManager.logInfo("ATProtoClient - No valid session, authentication required")
                await authDelegate?.authenticationRequired(client: self)
            }
        } catch {
            LogManager.logError("ATProtoClient - Failed to initialize session: \(error)")
            throw error
        }
    }

    public func authenticationRequired(client _: ATProtoClient) async {
        print("authentication required")
    }

    func baseURLDidUpdate(_ newBaseURL: URL) {
        baseURL = newBaseURL
    }

    // MARK: Generated classes

    public lazy var tools: Tools = .init(networkManager: self.networkManager)

    public final class Tools: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var ozone: Ozone = .init(networkManager: self.networkManager)

        public final class Ozone: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var server: Server = .init(networkManager: self.networkManager)

            public final class Server: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var team: Team = .init(networkManager: self.networkManager)

            public final class Team: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var communication: Communication = .init(networkManager: self.networkManager)

            public final class Communication: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var app: App = .init(networkManager: self.networkManager)

    public final class App: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var bsky: Bsky = .init(networkManager: self.networkManager)

        public final class Bsky: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var video: Video = .init(networkManager: self.networkManager)

            public final class Video: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var embed: Embed = .init(networkManager: self.networkManager)

            public final class Embed: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var notification: Notification = .init(networkManager: self.networkManager)

            public final class Notification: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var unspecced: Unspecced = .init(networkManager: self.networkManager)

            public final class Unspecced: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var graph: Graph = .init(networkManager: self.networkManager)

            public final class Graph: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var feed: Feed = .init(networkManager: self.networkManager)

            public final class Feed: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var actor: Actor = .init(networkManager: self.networkManager)

            public final class Actor: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var richtext: Richtext = .init(networkManager: self.networkManager)

            public final class Richtext: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var labeler: Labeler = .init(networkManager: self.networkManager)

            public final class Labeler: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var chat: Chat = .init(networkManager: self.networkManager)

    public final class Chat: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var bsky: Bsky = .init(networkManager: self.networkManager)

        public final class Bsky: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var convo: Convo = .init(networkManager: self.networkManager)

            public final class Convo: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var actor: Actor = .init(networkManager: self.networkManager)

            public final class Actor: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var com: Com = .init(networkManager: self.networkManager)

    public final class Com: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var atproto: Atproto = .init(networkManager: self.networkManager)

        public final class Atproto: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var temp: Temp = .init(networkManager: self.networkManager)

            public final class Temp: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var identity: Identity = .init(networkManager: self.networkManager)

            public final class Identity: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var admin: Admin = .init(networkManager: self.networkManager)

            public final class Admin: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var label: Label = .init(networkManager: self.networkManager)

            public final class Label: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var server: Server = .init(networkManager: self.networkManager)

            public final class Server: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var sync: Sync = .init(networkManager: self.networkManager)

            public final class Sync: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var repo: Repo = .init(networkManager: self.networkManager)

            public final class Repo: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }
}
