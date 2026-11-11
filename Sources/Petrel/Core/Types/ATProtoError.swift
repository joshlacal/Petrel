//
//  ATProtoError.swift
//  Petrel
//
//  Error handling infrastructure for ATProto lexicon-defined errors
//

import Foundation

/// Represents a structured error response from an ATProto endpoint
public struct ATProtoErrorResponse: Codable {
    /// The error code (matches lexicon error names)
    public let error: String
    /// Human-readable error message
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case message
    }
}

/// Protocol for lexicon-defined error enums
public protocol ATProtoErrorType: Error, RawRepresentable where RawValue == String {
    /// The error name as defined in the lexicon
    var errorName: String { get }
}

/// Extension to provide default implementation
public extension ATProtoErrorType {
    var errorName: String {
        // Extract just the error name from the raw value
        // Raw values are like "NotFound." or "NotFound.Description"
        let parts = rawValue.split(separator: ".")
        return String(parts.first ?? "")
    }
}

/// Wrapper for ATProto endpoint errors that combines type information and message
public struct ATProtoError<ErrorType: ATProtoErrorType>: Error, LocalizedError {
    /// The typed error from the lexicon
    public let error: ErrorType
    /// The error message from the server
    public let message: String?
    /// The HTTP status code
    public let statusCode: Int
    /// The response headers, keyed by lowercased header name.
    public let headers: [String: String]

    public init(error: ErrorType, message: String?, statusCode: Int) {
        self.init(error: error, message: message, statusCode: statusCode, headers: [:])
    }

    /// Creates a typed endpoint error that also carries the response headers.
    public init(error: ErrorType, message: String?, statusCode: Int, headers: [String: String]) {
        self.error = error
        self.message = message
        self.statusCode = statusCode
        self.headers = headers
    }

    /// The rate-limit state the server reported with this error, if any.
    public var rateLimit: XRPCRateLimit? {
        XRPCRateLimit(headers: headers)
    }

    public var errorDescription: String? {
        if let message = message {
            return "\(error.errorName): \(message)"
        }
        return error.errorName
    }
}
/// An XRPC error returned by an AT Protocol service, preserving the exact server-provided error code and message.
public struct ATProtoXRPCError: Error, LocalizedError, Sendable, Equatable {
    /// The error code string from the server (e.g. "InvalidRequest", "ExpiredToken", "SpaceNotFound").
    public let error: String
    /// The human-readable message from the server, if provided.
    public let message: String?
    /// The HTTP status code.
    public let statusCode: Int
    /// The response headers, keyed by lowercased header name.
    public let headers: [String: String]

    public init(error: String, message: String? = nil, statusCode: Int) {
        self.init(error: error, message: message, statusCode: statusCode, headers: [:])
    }

    /// Creates an XRPC error that also carries the response headers.
    public init(error: String, message: String?, statusCode: Int, headers: [String: String]) {
        self.error = error
        self.message = message
        self.statusCode = statusCode
        self.headers = headers
    }

    /// The rate-limit state the server reported with this error, if any.
    ///
    /// Present on `429 RateLimitExceeded` responses from services that send the
    /// `ratelimit-*` headers, and on any other error response that carries them.
    public var rateLimit: XRPCRateLimit? {
        XRPCRateLimit(headers: headers)
    }

    /// Seconds to wait before retrying, from a `Retry-After` header holding a
    /// delay in seconds. `nil` when the header is absent or holds an HTTP date.
    public var retryAfter: TimeInterval? {
        headers["retry-after"].flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) }
    }

    public var errorDescription: String? {
        if let message = message, !message.isEmpty {
            return "\(error): \(message)"
        }
        return error
    }
}

/// Rate-limit state reported by a service through the `ratelimit-*` response headers.
public struct XRPCRateLimit: Sendable, Equatable {
    /// `ratelimit-limit`: the request quota of the current window.
    public let limit: Int
    /// `ratelimit-remaining`: the requests left in the current window.
    public let remaining: Int
    /// `ratelimit-reset`: when the current window ends.
    public let reset: Date
    /// `ratelimit-policy`: the server's description of the window, such as `3000;w=300`.
    public let policy: String?

    /// Creates a rate-limit value.
    public init(limit: Int, remaining: Int, reset: Date, policy: String? = nil) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
        self.policy = policy
    }

    /// Reads the `ratelimit-*` headers. Returns `nil` unless limit, remaining and
    /// reset are all present and numeric.
    ///
    /// - Parameter headers: Response headers keyed by lowercased header name.
    public init?(headers: [String: String]) {
        guard let limit = headers["ratelimit-limit"].flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }),
              let remaining = headers["ratelimit-remaining"].flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }),
              let reset = headers["ratelimit-reset"].flatMap({ TimeInterval($0.trimmingCharacters(in: .whitespaces)) })
        else {
            return nil
        }
        self.init(
            limit: limit,
            remaining: remaining,
            reset: Date(timeIntervalSince1970: reset),
            policy: headers["ratelimit-policy"]
        )
    }
}

/// A successful (2xx) XRPC response whose body is not valid for the endpoint's output schema.
///
/// The Lexicon specification treats data that fails to validate as invalid as a whole,
/// so generated calls throw this instead of returning a partial or empty result.
public struct XRPCResponseDecodingError: Error, LocalizedError, Sendable {
    /// The NSID of the endpoint that was called.
    public let endpoint: String
    /// The HTTP status code of the response.
    public let statusCode: Int
    /// The decoding failure.
    public let underlying: any Error

    /// Creates a response decoding error.
    public init(endpoint: String, statusCode: Int, underlying: any Error) {
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.underlying = underlying
    }

    public var errorDescription: String? {
        "The \(statusCode) response of \(endpoint) does not match its output schema: \(underlying)"
    }
}

/// Helper for parsing error responses
public enum ATProtoErrorParser {
    /// Attempts to parse an error response and match it to a lexicon error type
    public static func parse<ErrorType: ATProtoErrorType>(
        data: Data,
        statusCode: Int,
        errorType: ErrorType.Type
    ) -> ATProtoError<ErrorType>? {
        // Try to decode the error response
        guard let errorResponse = try? JSONCoders.decode(ATProtoErrorResponse.self, from: data) else {
            return nil
        }

        let errorName = errorResponse.error

        guard let matchedError = ErrorType(rawValue: errorName) else {
            return nil
        }

        return ATProtoError(error: matchedError, message: errorResponse.message, statusCode: statusCode)
    }

    /// Attempts to parse any generic XRPC error response { "error": "...", "message": "..." } or non-empty error text.
    public static func parseGeneric(
        data: Data,
        statusCode: Int
    ) -> ATProtoXRPCError? {
        if let errorResponse = try? JSONDecoder().decode(ATProtoErrorResponse.self, from: data) {
            return ATProtoXRPCError(error: errorResponse.error, message: errorResponse.message, statusCode: statusCode)
        }
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return ATProtoXRPCError(error: "HTTP \(statusCode)", message: text, statusCode: statusCode)
        }
        return nil
    }

    /// Builds the error a generated call throws for a non-2xx response.
    ///
    /// The `{error, message}` envelope is preserved when the body carries one. A body
    /// that is not an envelope yields `error == "HTTP <status>"`, with the body text
    /// (if any) as `message`.
    public static func xrpcError(data: Data, response: HTTPURLResponse) -> ATProtoXRPCError {
        let headers = headerFields(of: response)
        let statusCode = response.statusCode
        if let parsed = parseGeneric(data: data, statusCode: statusCode) {
            return ATProtoXRPCError(
                error: parsed.error,
                message: parsed.message,
                statusCode: statusCode,
                headers: headers
            )
        }
        return ATProtoXRPCError(error: "HTTP \(statusCode)", message: nil, statusCode: statusCode, headers: headers)
    }

    /// Builds the error a generated call throws for a non-2xx response of an endpoint
    /// that declares errors in its Lexicon.
    ///
    /// - Returns: `ATProtoError<ErrorType>` when the envelope names a declared error,
    ///   otherwise the `ATProtoXRPCError` from ``xrpcError(data:response:)``.
    public static func xrpcError<ErrorType: ATProtoErrorType>(
        data: Data,
        response: HTTPURLResponse,
        declaredErrors: ErrorType.Type
    ) -> any Error {
        if let declared = parse(data: data, statusCode: response.statusCode, errorType: declaredErrors) {
            return ATProtoError(
                error: declared.error,
                message: declared.message,
                statusCode: declared.statusCode,
                headers: headerFields(of: response)
            )
        }
        return xrpcError(data: data, response: response)
    }

    /// The response headers keyed by lowercased name.
    public static func headerFields(of response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (name, value) in response.allHeaderFields {
            guard let name = name as? String else { continue }
            headers[name.lowercased()] = value as? String ?? "\(value)"
        }
        return headers
    }
}
