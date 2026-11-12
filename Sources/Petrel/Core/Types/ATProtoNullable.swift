import Foundation

/// The value of a Lexicon property that is both optional and nullable.
///
/// Such a property has three wire states, and they can mean different things:
/// `com.atproto.repo.putRecord` treats an absent `swapRecord` as "no check", a `null`
/// one as "the record must not exist yet" and a CID as "the record must currently be
/// this version". A plain Swift optional can only express two of them, so generated
/// types declare these properties as `ATProtoNullable<T>?`:
///
/// ```swift
/// swapRecord: nil            // key absent
/// swapRecord: .null          // "swapRecord": null
/// swapRecord: .value(cid)    // "swapRecord": "bafy…"
/// ```
///
/// Decoding keeps the distinction, so re-encoding reproduces what was read.
public enum ATProtoNullable<Wrapped: Sendable>: Sendable {
    /// An explicit `null`.
    case null
    /// A value.
    case value(Wrapped)

    /// The wrapped value, or `nil` for an explicit `null`.
    public var value: Wrapped? {
        switch self {
        case .null: nil
        case let .value(value): value
        }
    }

    /// Wraps an optional: `nil` becomes an explicit `null`.
    public init(_ value: Wrapped?) {
        self = value.map { .value($0) } ?? .null
    }
}

extension ATProtoNullable: Equatable where Wrapped: Equatable {}
extension ATProtoNullable: Hashable where Wrapped: Hashable {}

extension ATProtoNullable: Encodable where Wrapped: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .value(value):
            try value.encode(to: encoder)
        }
    }
}

extension ATProtoNullable: Decodable where Wrapped: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else {
            self = try .value(Wrapped(from: decoder))
        }
    }
}

extension ATProtoNullable: DAGCBOREncodable where Wrapped: DAGCBOREncodable {
    public func toCBORValue() throws -> Any {
        switch self {
        case .null: NSNull()
        case let .value(value): try value.toCBORValue()
        }
    }
}
