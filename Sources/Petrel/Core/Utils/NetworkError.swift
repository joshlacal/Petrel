//
//  NetworkError.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation

public enum NetworkError: Error {
    case invalidURL
    case requestFailed
    case responseError(statusCode: Int)
    case noData
    case decodingError
    case unknownError
    case expiredToken
    case authenticationRequired
    case retryRequest
    case invalidRequest
    case oauthManagerNotSet
    case maxRetryAttemptsReached
    case invalidContentType(expected: String, actual: String)
    case authenticationFailed
    case badRequest(description: String)
    case serverError(code: Int, message: String)
    case invalidResponse(description: String)
    case unauthorized
    case securityViolation
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .requestFailed:
            return "The network request failed."
        case let .responseError(statusCode):
            return "Received an error response from the server (Status Code: \(statusCode))."
        case .noData:
            return "No data was received from the server."
        case .decodingError:
            return "Failed to decode the data from the server."
        case .unknownError:
            return "An unknown error occurred."
        case .expiredToken:
            return "Session token has expired."
        case .authenticationRequired:
            return "Reauthentication required; login again."
        case .retryRequest:
            return "Request failed, retrying."
        case .oauthManagerNotSet:
            return "OAuth is not set up."
        case .maxRetryAttemptsReached:
            return "Max retry attempts reached."
        case let .invalidContentType(expected, actual):
            return "Invalid Content-Type received from the server. Expected: \(expected), got \(actual)."
        case .authenticationFailed:
            return "Authentication failed."
        case let .badRequest(description: description):
            return "Received bad request. \(description)."
        case .invalidRequest:
            return "The request was invalid."
        case let .serverError(code, message):
            return "Server error (\(code)): \(message)"
        case let .invalidResponse(description):
            return "Invalid response: \(description)"
        case .unauthorized:
            return "Unauthorized access."
        case .securityViolation:
            return "Network configuration issue detected. Please check your internet connection and try again."
        }
    }

    public var failureReason: String? {
        switch self {
        case .requestFailed:
            return "Network connectivity issues or server unavailability."
        case let .responseError(statusCode) where statusCode >= 500:
            return "The server is experiencing technical difficulties."
        case let .responseError(statusCode) where statusCode == 429:
            return "Too many requests sent. Rate limit exceeded."
        case let .responseError(statusCode) where statusCode >= 400:
            return "Client request was invalid or malformed."
        case .expiredToken:
            return "Your session has timed out for security reasons."
        case .authenticationFailed:
            return "Invalid credentials or authentication method."
        case .unauthorized:
            return "Access denied with current credentials."
        case .maxRetryAttemptsReached:
            return "Network connection is unstable or server is unresponsive."
        case .oauthManagerNotSet:
            return "Application configuration is incomplete."
        case .securityViolation:
            return "Your network configuration may be blocking the connection to the AT Protocol server."
        case .serverError:
            return "The server encountered an error."
        case .invalidResponse:
            return "The server sent a response in an unexpected format."
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .requestFailed:
            return "Check your internet connection and try again."
        case let .responseError(statusCode) where statusCode >= 500:
            return "Please wait a moment and try again. If the problem persists, contact support."
        case let .responseError(statusCode) where statusCode == 429:
            return "Please wait a few minutes before trying again."
        case .expiredToken, .authenticationRequired:
            return "Please log out and log back in to refresh your session."
        case .authenticationFailed:
            return "Check your username and password, then try again."
        case .unauthorized:
            return "Log out and log back in, or contact support if you believe you should have access."
        case .maxRetryAttemptsReached:
            return "Check your internet connection and try again in a few minutes."
        case .oauthManagerNotSet:
            return "Please restart the app. If the problem persists, contact support."
        case .securityViolation:
            return "Try switching to a different network or disabling VPN/proxy if enabled."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}
