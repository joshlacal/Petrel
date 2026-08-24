import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum PetrelPLCError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidIdentifier(String)
    case invalidProfile(String)
    case unauthorized(String)
    case conflict(expected: UInt64, actual: UInt64)
    case expired
    case malformed(String)
    case unavailable(String)

    public var description: String {
        switch self {
        case let .invalidIdentifier(value): "invalid identifier: \(value)"
        case let .invalidProfile(value): "invalid protocol profile: \(value)"
        case let .unauthorized(value): "unauthorized: \(value)"
        case .conflict: "repository revision conflict"
        case .expired: "credential or token expired"
        case let .malformed(value): "malformed input: \(value)"
        case let .unavailable(value): "unavailable: \(value)"
        }
    }
}

public typealias PLCError = PetrelPLCError
