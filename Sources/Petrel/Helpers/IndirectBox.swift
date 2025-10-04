import Foundation

/// A box type that breaks circular reference cycles by storing values indirectly on the heap.
/// This allows recursive/circular type definitions without causing infinite metadata instantiation.
public indirect enum IndirectBox<T>: Sendable where T: Sendable {
    case value(T)

    public init(_ value: T) {
        self = .value(value)
    }

    public var value: T {
        guard case .value(let v) = self else {
            fatalError("IndirectBox accessed with invalid state")
        }
        return v
    }
}

// MARK: - Codable
extension IndirectBox: Codable where T: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(T.self)
        self = .value(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Hashable
extension IndirectBox: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

// MARK: - Equatable
extension IndirectBox: Equatable where T: Equatable {
    public static func == (lhs: IndirectBox<T>, rhs: IndirectBox<T>) -> Bool {
        return lhs.value == rhs.value
    }
}
