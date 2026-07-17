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

    public init(error: ErrorType, message: String?, statusCode: Int) {
        self.error = error
        self.message = message
        self.statusCode = statusCode
    }

    public var errorDescription: String? {
        if let message = message {
            return "\(error.errorName): \(message)"
        }
        return error.errorName
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
        guard let errorResponse = try? JSONDecoder().decode(ATProtoErrorResponse.self, from: data) else {
            return nil
        }

        let errorName = errorResponse.error

        guard let matchedError = ErrorType(rawValue: errorName) else {
            return nil
        }

        return ATProtoError(error: matchedError, message: errorResponse.message, statusCode: statusCode)
    }
}
