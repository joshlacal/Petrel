//
//  LogManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Logging
import Synchronization

public struct PetrelLogEvent: Sendable {
    public enum Level: Sendable { case debug, info, warning, error }
    public let level: Level
    public let category: LogCategory
    public let message: String
}

/// Internal logger that also broadcasts events to optional observers.
class LogManager {
    /// Bootstrap swift-log with OSLogHandler on Apple platforms (runs once before any logger is created)
    private static let bootstrapOnce: Void = {
        #if canImport(os)
            LoggingSystem.bootstrap { label in
                OSLogHandler(label: label)
            }
        #else
            // On non-Apple platforms, use the default StreamLogHandler
            LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        #endif
    }()

    private static let networkLogger: Logger = {
        _ = bootstrapOnce
        return Logger(label: "com.joshlacalamito.Petrel.Network")
    }()

    private static let authLogger: Logger = {
        _ = bootstrapOnce
        return Logger(label: "com.joshlacalamito.Petrel.Authentication")
    }()

    private static let generalLogger: Logger = {
        _ = bootstrapOnce
        return Logger(label: "com.joshlacalamito.Petrel.General")
    }()

    private static let sensitiveHeaders = [
        "authorization", "dpop", "x-dpop", "dpop-nonce", "cookie", "set-cookie",
        "x-api-key", "x-auth-token", "bearer",
    ]

    private static let tokenEndpointPaths = [
        "/xrpc/com.atproto.server.createSession",
        "/xrpc/com.atproto.server.refreshSession",
        "/oauth/token", "/token",
    ]

    // MARK: - Observer support (Swift Concurrency safe)

    // DEPRECATED: Use PetrelAuthEvents for authentication event observation instead

    private actor ObserverStore {
        private var observers: [@Sendable (PetrelLogEvent) -> Void] = []
        private(set) var hasObservers = false

        func add(_ observer: @escaping @Sendable (PetrelLogEvent) -> Void) {
            observers.append(observer)
            hasObservers = true
        }

        func snapshot() -> [@Sendable (PetrelLogEvent) -> Void] {
            observers
        }
    }

    private static let observerStore = ObserverStore()

    /// Cache for observer existence check (set once, read many times).
    private static let cachedHasObservers = Mutex(false)

    /// Register a callback to receive Petrel log events.
    /// - Warning: DEPRECATED - Use `PetrelAuthEvents.addObserver()` for authentication events.
    /// This method is maintained for backwards compatibility but should not be used for new code.
    @available(*, deprecated, message: "Use PetrelAuthEvents.addObserver() for authentication events instead")
    static func addObserver(_ observer: @escaping @Sendable (PetrelLogEvent) -> Void) {
        Task {
            await observerStore.add(observer)
            cachedHasObservers.withLock { hasObservers in
                hasObservers = true
            }
        }
    }

    private static func notifyObservers(_ event: PetrelLogEvent) {
        // Fast path: check cached flag first to avoid Task creation when no observers
        let hasObservers = cachedHasObservers.withLock { cachedValue in
            cachedValue
        }
        guard hasObservers else { return }

        // Only notify for auth-related warnings/errors to preserve backwards compatibility
        // Regular logging (debug/info/network) no longer triggers observers
        guard event.category == .authentication else { return }
        guard event.level == .warning || event.level == .error else { return }

        Task(priority: .background) {
            let current = await observerStore.snapshot()
            current.forEach { $0(event) }
        }
    }

    static func logInfo(_ message: @autoclosure () -> String, category: LogCategory = .general) {
        let msg = message()
        getLogger(for: category).info("\(msg)")
        notifyObservers(.init(level: .info, category: category, message: msg))
    }

    static func logDebug(_ message: @autoclosure () -> String, category: LogCategory = .general) {
        #if DEBUG
            let msg = message()
            getLogger(for: category).debug("\(msg)")
            // In Release builds, skip observer notification for debug entirely
            notifyObservers(.init(level: .debug, category: category, message: msg))
        #endif
    }

    /// Warning-level logging for noteworthy but non-fatal issues
    static func logWarning(_ message: @autoclosure () -> String, category: LogCategory = .general) {
        let msg = message()
        getLogger(for: category).warning("\(msg)")
        notifyObservers(.init(level: .warning, category: category, message: msg))
    }

    static func logError(_ message: @autoclosure () -> String, category: LogCategory = .general) {
        let msg = message()
        getLogger(for: category).error("\(msg)")
        notifyObservers(.init(level: .error, category: category, message: msg))
    }

    /// Logs a sensitive value with only the first few characters visible
    static func logSensitiveValue(_ value: String?, label: String, category: LogCategory = .authentication) {
        #if DEBUG
            if let value = value, !value.isEmpty {
                // TEMPORARY: Truncation disabled for debugging
                logDebug("\(label): \(value)", category: category)
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

            /// Filter sensitive headers
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

            /// Filter sensitive headers
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
                    // TEMPORARY: Truncation disabled for debugging
                    debugMessage += "\nBody: \(responseString)"
                }
            } else {
                debugMessage += "\nBody: [TOKEN_ENDPOINT_RESPONSE]"
            }

            logDebug(debugMessage, category: .network)
        #endif
    }

    // MARK: - Structured Request/Response Logging for BFF Debugging

    /// Extracts JSON shape information: top-level keys and array lengths (no values)
    static func jsonShape(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return describeJSONShape(json)
    }

    private static func describeJSONShape(_ value: Any, depth: Int = 0) -> String {
        guard depth < 3 else { return "..." } // Limit recursion depth
        if let dict = value as? [String: Any] {
            let keys = dict.keys.sorted().map { key -> String in
                let childShape = describeJSONShape(dict[key]!, depth: depth + 1)
                return "\(key):\(childShape)"
            }
            return "{\(keys.joined(separator: ","))}"
        } else if let arr = value as? [Any] {
            if arr.isEmpty { return "[]" }
            let first = describeJSONShape(arr[0], depth: depth + 1)
            return "[\(arr.count)x\(first)]"
        } else if value is String {
            return "str"
        } else if value is NSNumber {
            return "num"
        } else if value is NSNull {
            return "null"
        } else {
            return "?"
        }
    }

    /// Logs a structured request with shape information for BFF debugging
    /// - Parameters:
    ///   - requestId: UUID for correlating with BFF logs
    ///   - method: HTTP method
    ///   - url: Request URL (will be sanitized)
    ///   - bodySize: Size of request body in bytes
    ///   - bodyShape: JSON shape of request body (keys + array lengths)
    ///   - gatewayMode: Whether request is going through gateway
    static func logStructuredRequest(
        requestId: String,
        method: String,
        url: URL,
        bodySize: Int,
        bodyShape: String?,
        gatewayMode: Bool
    ) {
        let host = url.host ?? "unknown"
        let path = url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let mode = gatewayMode ? "gateway" : "direct"
        let shape = bodyShape ?? "nil"

        logInfo(
            "[XRPC-REQ] id=\(requestId) mode=\(mode) method=\(method) host=\(host) path=\(path)\(query) bodyBytes=\(bodySize) shape=\(shape)",
            category: .network
        )
    }

    /// Logs a structured response with shape information for BFF debugging
    /// - Parameters:
    ///   - requestId: UUID for correlating with request
    ///   - status: HTTP status code
    ///   - elapsedMs: Request duration in milliseconds
    ///   - bodySize: Size of response body in bytes
    ///   - bodyShape: JSON shape of response body (keys + array lengths)
    static func logStructuredResponse(
        requestId: String,
        status: Int,
        elapsedMs: Int,
        bodySize: Int,
        bodyShape: String?
    ) {
        let shape = bodyShape ?? "nil"

        logInfo(
            "[XRPC-RES] id=\(requestId) status=\(status) elapsed=\(elapsedMs)ms bodyBytes=\(bodySize) shape=\(shape)",
            category: .network
        )
    }

    static func logError(_ error: Error, category: LogCategory = .general) {
        logError("Error: \(error.localizedDescription)", category: category)
    }

    /// Emits a structured authentication incident with rich context as a single-line JSON payload
    /// - Parameters:
    ///   - type: Incident type (e.g., "RefreshInvalidGrant", "AccountAutoSwitched", "LogoutNoAutoSwitch")
    ///   - details: Arbitrary key-value context (strings, numbers, bools)
    ///   - category: Log category (defaults to authentication)
    static func logAuthIncident(_ type: String, details: [String: Any], category: LogCategory = .authentication) {
        var payload: [String: Any] = [
            "type": type,
            "ts": Int(Date().timeIntervalSince1970),
        ]
        // Merge details, do not overwrite core keys
        details.forEach { k, v in if payload[k] == nil { payload[k] = v } }

        let json: String
        if JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
        {
            json = String(data: data, encoding: .utf8) ?? "{}"
        } else {
            // Best-effort fallback
            json = "{\"type\":\"\(type)\"}"
        }

        // Emit as a warning to stand out without being fatal
        let line = "AUTH_INCIDENT \(json)"
        logWarning(line, category: category)

        // Also broadcast via new dedicated auth event system
        broadcastAuthEvent(type: type, details: details)
    }

    /// Converts auth incident type and details into AuthEvent and broadcasts it
    private static func broadcastAuthEvent(type: String, details: [String: Any]) {
        let event = convertToAuthEvent(type: type, details: details)
        Task {
            await AuthEventBroadcaster.shared.broadcast(event)
        }
    }

    /// Converts incident type string to strongly-typed AuthEvent
    private static func convertToAuthEvent(type: String, details: [String: Any]) -> AuthEvent {
        let did = details["did"] as? String ?? ""
        let previousDid = details["previousDid"] as? String
        let newDid = details["newDid"] as? String
        let reason = details["reason"] as? String ?? ""
        let error = details["error"] as? String ?? ""
        let statusCode = details["status"] as? Int ?? 0
        let context = details["context"] as? String ?? ""
        let hasAccount = details["hasAccount"] as? Bool ?? false
        let hasSession = details["hasSession"] as? Bool ?? false
        let hasDPoPKey = details["hasDPoPKey"] as? Bool ?? false
        let retryAttempt = details["retryAttempt"] as? Int ?? 0

        switch type {
        // Startup & Recovery Events
        case "StartupRecovery_InconsistentState":
            return .startupInconsistentState(did: did, hasAccount: hasAccount, hasSession: hasSession, hasDPoPKey: hasDPoPKey)
        case "StartupRecovery_MissingSession":
            return .startupMissingSession(did: did, hasDPoPKey: hasDPoPKey)
        case "StartupRecovery_MissingDPoPKey":
            return .startupMissingDPoPKey(did: did, hasSession: hasSession)
        case "StartupRecovery_StateHealthy":
            return .startupStateHealthy(did: did)
        // Account Switching Events
        case "AccountAutoSwitchAfterRemoval", "AccountAutoSwitchedAfterLogout":
            return .accountAutoSwitched(previousDid: previousDid ?? did, newDid: newDid, reason: reason)
        case "CurrentAccountChanged":
            return .currentAccountChanged(previousDid: previousDid, newDid: did)
        // Session & Token Events
        case "SessionMissingForAccount":
            return .sessionMissing(did: did, context: context)
        case "RefreshInvalidGrant":
            return .refreshTokenInvalid(did: did, statusCode: statusCode, error: error)
        case "InvalidClientMetadata":
            return .invalidClientMetadata(did: did, statusCode: statusCode, error: error)
        case "InvalidClient":
            return .invalidClient(did: did, statusCode: statusCode, error: error)
        case "DPoPNonceMismatchRefresh":
            return .dpopNonceMismatch(did: did, retryAttempt: retryAttempt)
        // Logout Events
        case "LogoutStart":
            return .logoutStarted(did: did, reason: reason)
        case "AccountAutoSwitchedAfterLogout":
            return .logoutAutoSwitched(previousDid: previousDid ?? did, newDid: newDid ?? "")
        case "LogoutNoAutoSwitch":
            return .logoutNoAutoSwitch(did: did)
        case "LogoutClearedCurrentAccount":
            return .logoutClearedCurrentAccount(previousDid: previousDid ?? did)
        case "AutoLogoutTriggered":
            return .autoLogoutTriggered(did: did, reason: reason)
        // Error Events
        case "SetCurrentAccount_AccountNotFound":
            return .accountNotFound(did: did)
        case "SetCurrentAccount_NoSession":
            return .setCurrentAccountNoSession(did: did)
        case "SetCurrentAccount_StorageFailed":
            return .storageFailure(did: did, error: error)
        case "InconsistentAuthState_MissingSession":
            return .inconsistentStateMissingSession(did: did)
        case "InconsistentAuthState_MissingAccount":
            return .inconsistentStateMissingAccount(did: did)
        // Fallback for unknown types - use autoLogoutTriggered as catch-all
        default:
            return .autoLogoutTriggered(did: did, reason: "Unknown incident type: \(type)")
        }
    }

    private static func getLogger(for category: LogCategory) -> Logger {
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

public enum LogCategory: Sendable {
    case network
    case authentication
    case general
}

/// Public facade to register for Petrel log events without exposing internal logger type.
/// - Warning: DEPRECATED - Use `PetrelAuthEvents.addObserver()` for authentication events.
@available(*, deprecated, message: "Use PetrelAuthEvents.addObserver() for authentication events instead")
public enum PetrelLog {
    public static func addObserver(_ observer: @escaping @Sendable (PetrelLogEvent) -> Void) {
        LogManager.addObserver(observer)
    }
}
