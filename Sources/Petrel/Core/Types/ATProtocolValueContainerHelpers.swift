//
//  ATProtocolValueContainerHelpers.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation
import SwiftCBOR

// MARK: Safe Decoding

public struct JSONValue: Codable {
    let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([JSONValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: JSONValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { JSONValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { JSONValue($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Invalid JSON value"
            ))
        }
    }
}

public extension ATProtocolValueContainer {
    /// Decodes a `.knownType` payload as a concrete generated type, e.g.
    /// `postView.record.decoded(AppBskyFeedPost.self)`. Returns nil when the
    /// container holds a different type or an unknown/primitive value.
    func decoded<T: ATProtocolValue>(_: T.Type = T.self) -> T? {
        if case let .knownType(value) = self {
            return value as? T
        }
        return nil
    }

    var textRepresentation: String {
        switch self {
        case let .knownType(value):
            let mirror = Mirror(reflecting: value)
            return mirror.children.map { "\($0.label ?? ""): \($0.value)" }.joined(separator: ", ")
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .bigNumber(value):
            return value
        case let .object(value):
            return "Object: \(value.description)"
        case let .array(value):
            return "Array: \(value.description)"
        case let .bool(value):
            return value ? "True" : "False"
        case .null:
            return "Null"
        case let .link(value):
            return "Link: \(value)"
        case let .bytes(value):
            return "Bytes: \(value)"
        case let .unknownType(type, dict):
            if case let .object(objectDict) = dict {
                return
                    "Unknown Type: \(type), Values: \(objectDict.map { key, value in "\(key): \(value.textRepresentation)" }.joined(separator: ", "))"
            } else {
                return "Unknown Type: \(type)"
            }
        case let .decodeError(errorMessage):
            return "Decode Error: \(errorMessage)"
        }
    }

    func toJSON() throws -> Any {
        switch self {
        case let .knownType(value):
            return value
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bigNumber(value):
            return value
        case let .bool(value):
            return value
        case .null:
            return NSNull()
        case let .link(value):
            return value
        case let .bytes(value):
            return value
        case let .object(dict):
            return try dict.mapValues { try $0.toJSON() }
        case let .array(array):
            return try array.map { try $0.toJSON() }
        case let .unknownType(typeName, ATProtocolValueContainer):
            var jsonDict = [String: Any]()
            if case let .object(dict) = ATProtocolValueContainer {
                for (key, value) in dict {
                    jsonDict[key] = try value.toJSON()
                }
            }
            return ["type": typeName, "value": jsonDict]
        case let .decodeError(value):
            LogManager.logDebug("ATProtocolValueContainer - Decode error: \(value.debugDescription)")
            return value
        }
    }

    func toData() throws -> Data {
        let json = try toJSON()
        return try JSONSerialization.data(withJSONObject: json)
    }

    static func == (lhs: ATProtocolValueContainer, rhs: ATProtocolValueContainer) -> Bool {
        switch (lhs, rhs) {
        case let (.string(a), .string(b)):
            return a == b
        case let (.number(a), .number(b)):
            return a == b
        case let (.bigNumber(a), .bigNumber(b)):
            return a == b
        case let (.bool(a), .bool(b)):
            return a == b
        case (.null, .null):
            return true
        case let (.link(a), .link(b)):
            return a == b
        case let (.bytes(a), .bytes(b)):
            return a == b
        case let (.array(a), .array(b)):
            return a == b
        case let (.object(a), .object(b)):
            return a == b
        case let (.knownType(a), .knownType(b)):
            return a.isEqual(to: b)
        case let (.unknownType(typeA, valA), .unknownType(typeB, valB)):
            return typeA == typeB && valA == valB
        case let (.decodeError(a), .decodeError(b)):
            return a == b
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .string(value):
            hasher.combine(value)
        case let .number(value):
            hasher.combine(value)
        case let .bigNumber(value):
            hasher.combine(value)
        case let .bool(value):
            hasher.combine(value)
        case .null:
            hasher.combine(0) // Arbitrary choice for null
        case let .link(value):
            hasher.combine(value)
        case let .bytes(value):
            hasher.combine(value)
        case let .array(value):
            hasher.combine(value)
        case let .object(value):
            hasher.combine(value)
        case let .knownType(value):
            value.hash(into: &hasher)
        case let .unknownType(type, value):
            hasher.combine(type)
            hasher.combine(value)
        case let .decodeError(error):
            hasher.combine(error)
        }
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ATProtocolValueContainer else {
            return false
        }
        return self == otherValue
    }
}

// MARK: - In-Memory Container Decoder

/// Direct in-memory decoder that navigates `ATProtocolValueContainer` ASTs
/// without serializing to JSON intermediate data or dictionaries.
public struct ATProtocolValueContainerDecoder: Decoder {
    public let value: ATProtocolValueContainer
    public let codingPath: [CodingKey]
    public let userInfo: [CodingUserInfoKey: Any]

    public init(
        value: ATProtocolValueContainer,
        codingPath: [CodingKey] = [],
        userInfo: [CodingUserInfoKey: Any] = [:]
    ) {
        self.value = value
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    public func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        switch value {
        case let .object(dict):
            let container = KeyedContainer<Key>(decoder: self, dictionary: dict)
            return KeyedDecodingContainer(container)
        case let .unknownType(_, inner):
            if case let .object(dict) = inner {
                let container = KeyedContainer<Key>(decoder: self, dictionary: dict)
                return KeyedDecodingContainer(container)
            }
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected an object but found \(value)"
            ))
        case let .knownType(customValue):
            if let cbor = try? customValue.toCBORValue() {
                let containerValue = ATProtocolValueContainer.containerFromCBORValue(cbor)
                if case let .object(dict) = containerValue {
                    var finalDict = dict
                    let typeId = Swift.type(of: customValue).typeIdentifier
                    if !typeId.isEmpty && finalDict["$type"] == nil {
                        finalDict["$type"] = .string(typeId)
                    }
                    let container = KeyedContainer<Key>(decoder: self, dictionary: finalDict)
                    return KeyedDecodingContainer(container)
                }
            }
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected an object but found \(value)"
            ))
        default:
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected an object but found \(value)"
            ))
        }
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch value {
        case let .array(array):
            return UnkeyedContainer(decoder: self, array: array)
        default:
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected an array but found \(value)"
            ))
        }
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValueContainer(decoder: self)
    }

    private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: ATProtocolValueContainerDecoder
        let dictionary: [String: ATProtocolValueContainer]

        var codingPath: [CodingKey] { decoder.codingPath }
        var allKeys: [Key] { dictionary.keys.compactMap { Key(stringValue: $0) } }

        func contains(_ key: Key) -> Bool {
            dictionary[key.stringValue] != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard let val = dictionary[key.stringValue] else {
                return true
            }
            return val == .null
        }

        private func getValue(forKey key: Key) throws -> ATProtocolValueContainer {
            guard let val = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(key, DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \(key.stringValue)"
                ))
            }
            return val
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            let val = try getValue(forKey: key)
            if case let .bool(b) = val { return b }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected Bool for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            let val = try getValue(forKey: key)
            if case let .string(s) = val { return s }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected String for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            let val = try getValue(forKey: key)
            if case let .number(n) = val { return Double(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected Double for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            let val = try getValue(forKey: key)
            if case let .number(n) = val { return Float(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected Float for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            let val = try getValue(forKey: key)
            if case let .number(n) = val { return n }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected Int for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            let n = try decode(Int.self, forKey: key)
            guard let result = Int8(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(n) does not fit in Int8"))
            }
            return result
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            let n = try decode(Int.self, forKey: key)
            guard let result = Int16(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(n) does not fit in Int16"))
            }
            return result
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            let n = try decode(Int.self, forKey: key)
            guard let result = Int32(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(n) does not fit in Int32"))
            }
            return result
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            let val = try getValue(forKey: key)
            if case let .number(n) = val { return Int64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected Int64 for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            let val = try getValue(forKey: key)
            if case let .number(n) = val, n >= 0 { return UInt(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected UInt for \(key.stringValue), got \(val)"
            ))
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            let u = try decode(UInt.self, forKey: key)
            guard let result = UInt8(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(u) does not fit in UInt8"))
            }
            return result
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            let u = try decode(UInt.self, forKey: key)
            guard let result = UInt16(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(u) does not fit in UInt16"))
            }
            return result
        }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            let u = try decode(UInt.self, forKey: key)
            guard let result = UInt32(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "\(u) does not fit in UInt32"))
            }
            return result
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            let val = try getValue(forKey: key)
            if case let .number(n) = val, n >= 0 { return UInt64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: nestedPath(key),
                debugDescription: "Expected UInt64 for \(key.stringValue), got \(val)"
            ))
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let val = try getValue(forKey: key)
            if T.self == ATProtocolValueContainer.self {
                return val as! T
            }
            if case let .knownType(customValue) = val, let typed = customValue as? T {
                return typed
            }
            if T.self == CID.self {
                if case let .link(link) = val { return link.cid as! T }
                if case let .string(s) = val { return try CID.parse(s) as! T }
            }
            if T.self == ATProtoLink.self {
                if case let .link(link) = val { return link as! T }
                if case let .object(obj) = val, obj.count == 1, case let .string(cidStr)? = obj["$link"] {
                    return try ATProtoLink(cidString: cidStr) as! T
                }
            }
            if T.self == Bytes.self {
                if case let .bytes(bytes) = val { return bytes as! T }
                if case let .object(obj) = val, obj.count == 1, case let .string(b64)? = obj["$bytes"] {
                    guard let d = Data(base64Encoded: b64) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: nestedPath(key), debugDescription: "Invalid base64 in $bytes"))
                    }
                    return Bytes(data: d) as! T
                }
            }
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: nestedPath(key),
                userInfo: decoder.userInfo
            )
            return try T(from: childDecoder)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
            guard let val = dictionary[key.stringValue], val != .null else {
                return nil
            }
            return try decode(type, forKey: key)
        }

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> {
            let val = try getValue(forKey: key)
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: nestedPath(key),
                userInfo: decoder.userInfo
            )
            return try childDecoder.container(keyedBy: NestedKey.self)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let val = try getValue(forKey: key)
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: nestedPath(key),
                userInfo: decoder.userInfo
            )
            return try childDecoder.unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            decoder
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            let val = try getValue(forKey: key)
            return ATProtocolValueContainerDecoder(
                value: val,
                codingPath: nestedPath(key),
                userInfo: decoder.userInfo
            )
        }

        private func nestedPath(_ key: Key) -> [CodingKey] {
            var path = codingPath
            path.append(key)
            return path
        }
    }

    private struct UnkeyedContainer: UnkeyedDecodingContainer {
        let decoder: ATProtocolValueContainerDecoder
        let array: [ATProtocolValueContainer]
        private(set) var currentIndex: Int = 0

        init(decoder: ATProtocolValueContainerDecoder, array: [ATProtocolValueContainer]) {
            self.decoder = decoder
            self.array = array
        }

        var codingPath: [CodingKey] { decoder.codingPath }
        var count: Int? { array.count }
        var isAtEnd: Bool { currentIndex >= array.count }

        mutating func decodeNil() throws -> Bool {
            guard !isAtEnd else { return false }
            if array[currentIndex] == .null {
                currentIndex += 1
                return true
            }
            return false
        }

        private mutating func nextValue() throws -> ATProtocolValueContainer {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self,
                    DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end")
                )
            }
            let val = array[currentIndex]
            currentIndex += 1
            return val
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let val = try nextValue()
            if case let .bool(b) = val { return b }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool, got \(val)"))
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let val = try nextValue()
            if case let .string(s) = val { return s }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String, got \(val)"))
        }
        mutating func decode(_ type: Double.Type) throws -> Double {
            let val = try nextValue()
            if case let .number(n) = val { return Double(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double, got \(val)"))
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            let val = try nextValue()
            if case let .number(n) = val { return Float(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Float, got \(val)"))
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            let val = try nextValue()
            if case let .number(n) = val { return n }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int, got \(val)"))
        }
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            let n = try decode(Int.self)
            guard let result = Int8(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int8"))
            }
            return result
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            let n = try decode(Int.self)
            guard let result = Int16(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int16"))
            }
            return result
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            let n = try decode(Int.self)
            guard let result = Int32(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int32"))
            }
            return result
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            let val = try nextValue()
            if case let .number(n) = val { return Int64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int64, got \(val)"))
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            let val = try nextValue()
            if case let .number(n) = val, n >= 0 { return UInt(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt, got \(val)"))
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            let u = try decode(UInt.self)
            guard let result = UInt8(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt8"))
            }
            return result
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            let u = try decode(UInt.self)
            guard let result = UInt16(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt16"))
            }
            return result
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            let u = try decode(UInt.self)
            guard let result = UInt32(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt32"))
            }
            return result
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            let val = try nextValue()
            if case let .number(n) = val, n >= 0 { return UInt64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt64, got \(val)"))
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let val = try nextValue()
            if T.self == ATProtocolValueContainer.self {
                return val as! T
            }
            if case let .knownType(customValue) = val, let typed = customValue as? T {
                return typed
            }
            if T.self == CID.self {
                if case let .link(link) = val { return link.cid as! T }
                if case let .string(s) = val { return try CID.parse(s) as! T }
            }
            if T.self == ATProtoLink.self {
                if case let .link(link) = val { return link as! T }
                if case let .object(obj) = val, obj.count == 1, case let .string(cidStr)? = obj["$link"] {
                    return try ATProtoLink(cidString: cidStr) as! T
                }
            }
            if T.self == Bytes.self {
                if case let .bytes(bytes) = val { return bytes as! T }
                if case let .object(obj) = val, obj.count == 1, case let .string(b64)? = obj["$bytes"] {
                    guard let d = Data(base64Encoded: b64) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid base64 in $bytes"))
                    }
                    return Bytes(data: d) as! T
                }
            }
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: codingPath,
                userInfo: decoder.userInfo
            )
            return try T(from: childDecoder)
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            let val = try nextValue()
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: codingPath,
                userInfo: decoder.userInfo
            )
            return try childDecoder.container(keyedBy: NestedKey.self)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let val = try nextValue()
            let childDecoder = ATProtocolValueContainerDecoder(
                value: val,
                codingPath: codingPath,
                userInfo: decoder.userInfo
            )
            return try childDecoder.unkeyedContainer()
        }

        mutating func superDecoder() throws -> Decoder {
            let val = try nextValue()
            return ATProtocolValueContainerDecoder(
                value: val,
                codingPath: codingPath,
                userInfo: decoder.userInfo
            )
        }
    }

    private struct SingleValueContainer: SingleValueDecodingContainer {
        let decoder: ATProtocolValueContainerDecoder

        var codingPath: [CodingKey] { decoder.codingPath }

        func decodeNil() -> Bool {
            decoder.value == .null
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            if case let .bool(b) = decoder.value { return b }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Bool, got \(decoder.value)"))
        }

        func decode(_ type: String.Type) throws -> String {
            if case let .string(s) = decoder.value { return s }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected String, got \(decoder.value)"))
        }
        func decode(_ type: Double.Type) throws -> Double {
            if case let .number(n) = decoder.value { return Double(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Double, got \(decoder.value)"))
        }

        func decode(_ type: Float.Type) throws -> Float {
            if case let .number(n) = decoder.value { return Float(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Float, got \(decoder.value)"))
        }

        func decode(_ type: Int.Type) throws -> Int {
            if case let .number(n) = decoder.value { return n }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int, got \(decoder.value)"))
        }
        func decode(_ type: Int8.Type) throws -> Int8 {
            let n = try decode(Int.self)
            guard let result = Int8(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int8"))
            }
            return result
        }

        func decode(_ type: Int16.Type) throws -> Int16 {
            let n = try decode(Int.self)
            guard let result = Int16(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int16"))
            }
            return result
        }

        func decode(_ type: Int32.Type) throws -> Int32 {
            let n = try decode(Int.self)
            guard let result = Int32(exactly: n) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(n) does not fit in Int32"))
            }
            return result
        }

        func decode(_ type: Int64.Type) throws -> Int64 {
            if case let .number(n) = decoder.value { return Int64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected Int64, got \(decoder.value)"))
        }

        func decode(_ type: UInt.Type) throws -> UInt {
            if case let .number(n) = decoder.value, n >= 0 { return UInt(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt, got \(decoder.value)"))
        }

        func decode(_ type: UInt8.Type) throws -> UInt8 {
            let u = try decode(UInt.self)
            guard let result = UInt8(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt8"))
            }
            return result
        }

        func decode(_ type: UInt16.Type) throws -> UInt16 {
            let u = try decode(UInt.self)
            guard let result = UInt16(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt16"))
            }
            return result
        }

        func decode(_ type: UInt32.Type) throws -> UInt32 {
            let u = try decode(UInt.self)
            guard let result = UInt32(exactly: u) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "\(u) does not fit in UInt32"))
            }
            return result
        }

        func decode(_ type: UInt64.Type) throws -> UInt64 {
            if case let .number(n) = decoder.value, n >= 0 { return UInt64(n) }
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected UInt64, got \(decoder.value)"))
        }
        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            if T.self == ATProtocolValueContainer.self {
                return decoder.value as! T
            }
            if case let .knownType(customValue) = decoder.value, let typed = customValue as? T {
                return typed
            }
            if T.self == CID.self {
                if case let .link(link) = decoder.value { return link.cid as! T }
                if case let .string(s) = decoder.value { return try CID.parse(s) as! T }
            }
            if T.self == ATProtoLink.self {
                if case let .link(link) = decoder.value { return link as! T }
                if case let .object(obj) = decoder.value, obj.count == 1, case let .string(cidStr)? = obj["$link"] {
                    return try ATProtoLink(cidString: cidStr) as! T
                }
            }
            if T.self == Bytes.self {
                if case let .bytes(bytes) = decoder.value { return bytes as! T }
                if case let .object(obj) = decoder.value, obj.count == 1, case let .string(b64)? = obj["$bytes"] {
                    guard let d = Data(base64Encoded: b64) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid base64 in $bytes"))
                    }
                    return Bytes(data: d) as! T
                }
            }
            return try T(from: decoder)
        }
    }
}
