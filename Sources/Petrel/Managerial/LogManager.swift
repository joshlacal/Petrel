//
//  LogManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
import os.log

class LogManager {
    private static let networkLogger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Petrel", category: "Network"
    )

    private static let authLogger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Petrel", category: "Authentication"
    )

    private static let generalLogger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Petrel", category: "General"
    )

    private static let sensitiveHeaders = [
        "authorization", "dpop", "x-dpop", "dpop-nonce", "cookie", "set-cookie",
        "x-api-key", "x-auth-token", "bearer",
    ]

    private static let tokenEndpointPaths = [
        "/xrpc/com.atproto.server.createSession",
        "/xrpc/com.atproto.server.refreshSession",
        "/oauth/token", "/token",
    ]

    static func logInfo(_ message: String, category: LogCategory = .general) {
        getLogger(for: category).info("\(message, privacy: .public)")
    }

    static func logDebug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
            getLogger(for: category).debug("\(message, privacy: .public)")
        #endif
    }

    static func logError(_ message: String, category: LogCategory = .general) {
        getLogger(for: category).error("\(message, privacy: .public)")
    }

    /// Logs a sensitive value with only the first few characters visible
    static func logSensitiveValue(_ value: String?, label: String, category: LogCategory = .authentication) {
        #if DEBUG
            if let value = value, !value.isEmpty {
                let truncated = String(value.prefix(4)) + "...[REDACTED]"
                logDebug("\(label): \(truncated)", category: category)
            } else {
                logDebug("\(label): nil", category: category)
            }
        #endif
    }

    /// Returns a DID for logging (DIDs are public identifiers, not sensitive)
    static func logDID(_ did: String?) -> String {
        return did ?? "nil"
    }

    static func logRequest(_ request: URLRequest) {
        #if DEBUG
            let url = request.url?.absoluteString ?? "N/A"
            var debugMessage = "Request URL: \(url)\n"
            debugMessage += "Method: \(request.httpMethod ?? "N/A")\n"

            // Filter sensitive headers
            var filteredHeaders: [String: String] = [:]
            request.allHTTPHeaderFields?.forEach { key, value in
                filteredHeaders[key] = sensitiveHeaders.contains(key.lowercased()) ? "[REDACTED]" : value
            }
            debugMessage += "Headers: \(filteredHeaders)"

            // Don't log body for token endpoints or if it contains sensitive data
            if let url = request.url,
               !tokenEndpointPaths.contains(where: { url.path.contains($0) }),
               let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8)
            {
                // Check if body might contain sensitive data
                let lowerBody = bodyString.lowercased()
                if lowerBody.contains("password") || lowerBody.contains("token") ||
                    lowerBody.contains("client_secret") || lowerBody.contains("code")
                {
                    debugMessage += "\nBody: [CONTAINS_SENSITIVE_DATA]"
                } else {
                    debugMessage += "\nBody: \(bodyString)"
                }
            }

            logDebug(debugMessage, category: .network)
        #endif
    }

    static func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
            let url = response.url?.absoluteString ?? "N/A"
            var debugMessage = "Response URL: \(url)\n"
            debugMessage += "Status Code: \(response.statusCode)\n"

            // Filter sensitive headers
            var filteredHeaders: [String: Any] = [:]
            for (key, value) in response.allHeaderFields {
                if let keyString = key as? String,
                   sensitiveHeaders.contains(keyString.lowercased())
                {
                    filteredHeaders[keyString] = "[REDACTED]"
                } else {
                    filteredHeaders["\(key)"] = value
                }
            }
            debugMessage += "Headers: \(filteredHeaders)"

            // Don't log response body for token endpoints
            if let url = response.url,
               !tokenEndpointPaths.contains(where: { url.path.contains($0) })
            {
                if let responseString = String(data: data, encoding: .utf8) {
                    // Truncate very long responses
                    let truncated = responseString.count > 1000 ?
                        String(responseString.prefix(1000)) + "...[TRUNCATED]" :
                        responseString
                    debugMessage += "\nBody: \(truncated)"
                }
            } else {
                debugMessage += "\nBody: [TOKEN_ENDPOINT_RESPONSE]"
            }

            logDebug(debugMessage, category: .network)
        #endif
    }

    static func logError(_ error: Error, category: LogCategory = .general) {
        logError("Error: \(error.localizedDescription)", category: category)
    }

    private static func getLogger(for category: LogCategory) -> os.Logger {
        switch category {
        case .network:
            return networkLogger
        case .authentication:
            return authLogger
        case .general:
            return generalLogger
        }
    }
}

enum LogCategory {
    case network
    case authentication
    case general
}
