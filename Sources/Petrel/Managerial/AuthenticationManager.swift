//
//  AuthenticationManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation

public protocol AuthenticationDelegate: AnyObject, Sendable {
    func authenticationRequired(client: ATProtoClient) async
}

/// Protocol defining the interface for managing authentication.
protocol AuthenticationManaging: Sendable {
    func createSession(identifier: String, password: String) async throws
    func reauthenticate() async throws
    func setClient(_ client: ATProtoClient) async
}

/// Actor responsible for managing authentication flows.
actor AuthenticationManager: AuthenticationManaging {
    // MARK: - Properties

    private let authenticationService: AuthenticationService
    private weak var client: ATProtoClient?

    // MARK: - Initialization

    /// Initializes the AuthenticationManager with the AuthenticationService.
    ///
    /// - Parameters:
    ///   - authenticationService: The unified authentication service.
    ///   - client: The ATProtoClient instance.
    public init(
        authenticationService: AuthenticationService,
        client: ATProtoClient
    ) async {
        self.authenticationService = authenticationService
        self.client = client
    }

    // MARK: - AuthenticationManaging Protocol Methods

    /// Sets the ATProtoClient instance.
    ///
    /// - Parameter client: The ATProtoClient instance.
    public func setClient(_ client: ATProtoClient) {
        self.client = client
    }

    /// Creates a new session using the appropriate authentication method.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., handle).
    ///   - password: The user's password.
    public func createSession(identifier: String, password: String) async throws {
        do {
            try await authenticationService.login(identifier: identifier, password: password)
        } catch {
            LogManager.logError("AuthenticationManager - Failed to create session: \(error)")
            throw error
        }
    }

    /// Reauthenticates the user.
    public func reauthenticate() async throws {
        do {
            let refreshed = try await authenticationService.refreshTokenIfNeeded()
            if !refreshed {
                await notifyAuthenticationRequired()
            }
        } catch {
            LogManager.logError("AuthenticationManager - Reauthentication failed: \(error)")
            await notifyAuthenticationRequired()
            throw error
        }
    }

    /// Handles session reauthentication requests from SessionManager.
    ///
    /// - Parameter sessionManager: The SessionManager requesting reauthentication.
    func sessionRequiresReauthentication(sessionManager: SessionManager) async throws {
        try await reauthenticate()
    }

    // MARK: - Helper Methods

    /// Notifies the ATProtoClient that authentication is required.
    private func notifyAuthenticationRequired() async {
        guard let client = client else {
            LogManager.logError("AuthenticationManager - ATProtoClient is not set.")
            return
        }
        await client.authDelegate?.authenticationRequired(client: client)
    }
}
