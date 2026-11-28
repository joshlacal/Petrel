import Foundation

/// A decoder that hides the `$type` key of the object it reads.
///
/// A generated object that does not write its own `$type` keeps one it was decoded
/// with in a private `wireTypeTag` and writes it back, so re-encoding never changes the
/// DAG-CBOR bytes or CID of the record that holds it. A union member is different: the
/// union reads the tag to pick the member and writes it back itself. Generated unions
/// decode their member through this decoder, so a member decoded from the wire equals
/// one built in code (neither carries the tag).
///
/// Only the top-level object is affected; nested values decode through the wrapped
/// decoder unchanged.
public struct ATProtoUnionMemberDecoder: Decoder {
    private let base: Decoder

    public init(_ base: Decoder) {
        self.base = base
    }

    public var codingPath: [CodingKey] {
        base.codingPath
    }

    public var userInfo: [CodingUserInfoKey: Any] {
        base.userInfo
    }

    public func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try KeyedDecodingContainer(TypeTagHidingContainer(base: base.container(keyedBy: Key.self)))
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try base.unkeyedContainer()
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        try base.singleValueContainer()
    }
}

private let typeTagKey = "$type"

// MARK: - Nested `$type`

public extension ATProtocolValueContainer {
    /// Reads the `$type` of the object being decoded, for a generated type that does not
    /// write its own. `nil` when absent, not a string, or hidden by
    /// ``ATProtoUnionMemberDecoder``.
    static func decodeTypeTag(from decoder: Decoder) throws -> String? {
        let container = try decoder.container(keyedBy: UndeclaredFieldKey.self)
        let key = UndeclaredFieldKey(typeTagKey)
        guard container.contains(key) else { return nil }
        return try? container.decode(String.self, forKey: key)
    }

    /// Writes back a `$type` the value was decoded with.
    static func encodeTypeTag(_ tag: String?, to encoder: Encoder) throws {
        guard let tag else { return }
        var container = encoder.container(keyedBy: UndeclaredFieldKey.self)
        try container.encode(tag, forKey: UndeclaredFieldKey(typeTagKey))
    }

    /// Adds a `$type` the value was decoded with to its DAG-CBOR map.
    static func addingTypeTag(_ tag: String?, to map: OrderedCBORMap) -> OrderedCBORMap {
        guard let tag else { return map }
        return map.adding(key: typeTagKey, value: tag)
    }
}

private struct TypeTagHidingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let base: KeyedDecodingContainer<Key>

    var codingPath: [CodingKey] {
        base.codingPath
    }

    var allKeys: [Key] {
        base.allKeys.filter { $0.stringValue != typeTagKey }
    }

    func contains(_ key: Key) -> Bool {
        key.stringValue != typeTagKey && base.contains(key)
    }

    private func visible(_ key: Key) throws -> Key {
        guard key.stringValue != typeTagKey else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "The union that decodes this member owns its $type"
                )
            )
        }
        return key
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try base.decodeNil(forKey: visible(key))
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try base.decode(type, forKey: visible(key))
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try base.decode(type, forKey: visible(key))
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try base.decode(type, forKey: visible(key))
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key) else { return nil }
        return try base.decodeIfPresent(type, forKey: key)
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try base.nestedContainer(keyedBy: type, forKey: visible(key))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try base.nestedUnkeyedContainer(forKey: visible(key))
    }

    func superDecoder() throws -> Decoder {
        try base.superDecoder()
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        try base.superDecoder(forKey: visible(key))
    }
}
