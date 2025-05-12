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
    case serverError
    case invalidResponse
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
        case .serverError:
            return "The server encountered an error."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .unauthorized:
            return "Unauthorized access."
        case .securityViolation:
            return "Security violation detected."
        }
    }
}
