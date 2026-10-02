import Foundation
import CJSONBridge

/// Experimental bridge, deliberately confined to the benchmark target.
/// No Swift JSON object graph is built; Decoder containers reference simdjson's DOM.
struct SIMDModelDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let document = try SIMDDocument(data)
        return try withExtendedLifetime(document) { try DOMDecoder(node: document.root).decode(type) }
    }
}

func simdParseOnly(_ data: Data) throws -> Int {
    let document = try SIMDDocument(data)
    return withExtendedLifetime(document) { Int(sj_type(document.root.raw)) }
}

func simdBackend() -> String { String(cString: sj_backend()) }
func simdVersion() -> String { String(cString: sj_version()) }

final class SIMDDocument {
    let handle: OpaquePointer
    let root: DOMNode
    init(_ data: Data) throws {
        var raw = sj_value()
        var code: Int32 = 0
        let result = data.withUnsafeBytes { sj_parse($0.baseAddress, $0.count, &raw, &code) }
        guard let result else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "simdjson: \(String(cString: sj_error(code)))"))
        }
        handle = result
        root = DOMNode(raw: raw)
    }
    deinit { sj_destroy(handle) }
}

struct DOMKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(_ value: String) { stringValue = value; intValue = nil }
    init(index: Int) { stringValue = "Index \(index)"; intValue = index }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { self.init(index: intValue) }
}

struct DOMNode {
    let raw: sj_value
    var kind: Int32 { sj_type(raw) }
    var isNull: Bool { kind == 110 }
    var isObject: Bool { kind == 123 }
    var isArray: Bool { kind == 91 }
    var isString: Bool { kind == 34 }

    func field(_ key: String) -> DOMNode? {
        var value = sj_value()
        // Counted key length also permits embedded NUL and the empty key.
        let code = key.withCString { sj_object_get(raw, $0, key.utf8.count, &value) }
        return code == 0 ? DOMNode(raw: value) : nil
    }

    func keys() -> [String] {
        var cursor = sj_value(), end = sj_value(), value = sj_value()
        var count = 0, length = 0
        var key: UnsafePointer<CChar>?
        guard sj_object_begin(raw, &cursor, &end, &count) == 0 else { return [] }
        var keys: [String] = []; keys.reserveCapacity(count)
        while sj_object_next(&cursor, end, &key, &length, &value) != 0 {
            keys.append(String(decoding: UnsafeRawBufferPointer(start: key, count: length), as: UTF8.self))
        }
        return keys
    }

    func string(path: [any CodingKey] = []) throws -> String {
        var pointer: UnsafePointer<CChar>?, length = 0
        guard sj_string(raw, &pointer, &length) == 0 else { throw mismatch(String.self, path) }
        // simdjson has validated/unescaped UTF-8. Swift creates the owned String
        // required by Petrel models; this constructor may still inspect UTF-8.
        return String(decoding: UnsafeRawBufferPointer(start: pointer, count: length), as: UTF8.self)
    }

    func bool(path: [any CodingKey]) throws -> Bool {
        var result: Int32 = 0
        guard sj_bool(raw, &result) == 0 else { throw mismatch(Bool.self, path) }
        return result != 0
    }

    func double(path: [any CodingKey]) throws -> Double {
        var result: Double = 0
        guard sj_double(raw, &result) == 0 else { throw mismatch(Double.self, path) }
        return result
    }

    func integer<T: FixedWidthInteger>(_ type: T.Type, path: [any CodingKey]) throws -> T {
        if kind == 108 {
            var result: Int64 = 0
            if sj_int64(raw, &result) == 0, let value = T(exactly: result) { return value }
        } else if kind == 117 {
            var result: UInt64 = 0
            if sj_uint64(raw, &result) == 0, let value = T(exactly: result) { return value }
        } else if kind == 100 {
            var result: Double = 0
            if sj_double(raw, &result) == 0, let value = T(exactly: result) { return value }
        }
        throw mismatch(type, path)
    }

    func mismatch<T>(_ type: T.Type, _ path: [any CodingKey]) -> DecodingError {
        if isNull { return .valueNotFound(type, .init(codingPath: path, debugDescription: "Expected \(type), found null")) }
        return .typeMismatch(type, .init(codingPath: path, debugDescription: "Expected \(type), found simdjson type \(kind)"))
    }
}

struct DOMDecoder: Decoder {
    let node: DOMNode
    var codingPath: [any CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func child(_ value: DOMNode, _ key: any CodingKey) -> DOMDecoder {
        DOMDecoder(node: value, codingPath: codingPath + [key])
    }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        // Match Foundation's default strategies at generic decode boundaries.
        if type == Data.self {
            let string = try node.string(path: codingPath)
            guard let data = Data(base64Encoded: string) else {
                throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Invalid Base64"))
            }
            return data as! T
        }
        if type == Date.self { return Date(timeIntervalSinceReferenceDate: try node.double(path: codingPath)) as! T }
        if type == URL.self {
            guard let url = URL(string: try node.string(path: codingPath)) else {
                throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Invalid URL"))
            }
            return url as! T
        }
        return try T(from: self)
    }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard node.isObject else { throw node.mismatch([String: Any].self, codingPath) }
        return KeyedDecodingContainer(DOMKeyedContainer<Key>(decoder: self))
    }
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer { try DOMUnkeyedContainer(decoder: self) }
    func singleValueContainer() throws -> any SingleValueDecodingContainer { DOMSingleContainer(decoder: self) }
}

struct DOMSingleContainer: SingleValueDecodingContainer {
    let decoder: DOMDecoder
    var codingPath: [any CodingKey] { decoder.codingPath }
    func decodeNil() -> Bool { decoder.node.isNull }
    func decode(_ type: Bool.Type) throws -> Bool { try decoder.node.bool(path: codingPath) }
    func decode(_ type: String.Type) throws -> String { try decoder.node.string(path: codingPath) }
    func decode(_ type: Double.Type) throws -> Double { try decoder.node.double(path: codingPath) }
    func decode(_ type: Float.Type) throws -> Float {
        let value = Float(try decode(Double.self))
        guard value.isFinite else { throw decoder.node.mismatch(type, codingPath) }
        return value
    }
    func decode(_ type: Int.Type) throws -> Int { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try decoder.node.integer(type, path: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try decoder.node.integer(type, path: codingPath) }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try decoder.decode(type) }
}

struct DOMKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: DOMDecoder
    var codingPath: [any CodingKey] { decoder.codingPath }
    var allKeys: [Key] { decoder.node.keys().compactMap(Key.init(stringValue:)) }
    func contains(_ key: Key) -> Bool { decoder.node.field(key.stringValue) != nil }
    func value(_ key: Key) throws -> DOMDecoder {
        guard let value = decoder.node.field(key.stringValue) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing key \(key.stringValue)"))
        }
        return decoder.child(value, key)
    }
    func decodeNil(forKey key: Key) throws -> Bool { try value(key).node.isNull }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try value(key).decode(type) }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try DOMSingleContainer(decoder: value(key)).decode(type) }
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> { try value(key).container(keyedBy: type) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer { try value(key).unkeyedContainer() }
    func superDecoder() throws -> any Decoder {
        guard let value = decoder.node.field("super") else { throw DecodingError.keyNotFound(DOMKey("super"), .init(codingPath: codingPath, debugDescription: "Missing super")) }
        return decoder.child(value, DOMKey("super"))
    }
    func superDecoder(forKey key: Key) throws -> any Decoder { try value(key) }
}

struct DOMUnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: DOMDecoder
    var cursor = sj_value()
    let end: sj_value
    let count: Int?
    var currentIndex = 0
    var isAtEnd: Bool { currentIndex == count }
    var codingPath: [any CodingKey] { decoder.codingPath }
    init(decoder: DOMDecoder) throws {
        self.decoder = decoder
        var cursor = sj_value(), end = sj_value(), count = 0
        guard sj_array_begin(decoder.node.raw, &cursor, &end, &count) == 0 else { throw decoder.node.mismatch([Any].self, decoder.codingPath) }
        self.cursor = cursor; self.end = end; self.count = count
    }
    mutating func next() throws -> DOMDecoder {
        var value = sj_value()
        guard sj_array_next(&cursor, end, &value) != 0 else {
            throw DecodingError.valueNotFound(Any.self, .init(codingPath: codingPath, debugDescription: "End of array"))
        }
        defer { currentIndex += 1 }
        return decoder.child(DOMNode(raw: value), DOMKey(index: currentIndex))
    }
    mutating func decodeNil() throws -> Bool {
        var copy = self
        if try copy.next().node.isNull { self = copy; return true }
        return false
    }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try next().decode(type) }
    mutating func decode(_ type: Bool.Type) throws -> Bool { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: String.Type) throws -> String { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try DOMSingleContainer(decoder: next()).decode(type) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> { try next().container(keyedBy: type) }
    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer { try next().unkeyedContainer() }
    mutating func superDecoder() throws -> any Decoder { try next() }
}
