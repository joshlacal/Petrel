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
    case oauthManagerNotSet
    case maxRetryAttemptsReached
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
        }
    }
}
