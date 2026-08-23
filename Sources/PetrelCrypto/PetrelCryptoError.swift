import Foundation

public enum PetrelCryptoError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidIdentifier(String)
    case malformed(String)
    case unauthorized(String)
    case unsupportedAlgorithm(String)
    case expired

    public var description: String {
        switch self {
        case let .invalidIdentifier(msg):
            return "Invalid identifier: \(msg)"
        case let .malformed(msg):
            return "Malformed data: \(msg)"
        case let .unauthorized(msg):
            return "Unauthorized: \(msg)"
        case let .unsupportedAlgorithm(msg):
            return "Unsupported algorithm: \(msg)"
        case .expired:
            return "Expired"
        }
    }
}
