import Foundation
import PetrelCore

// MARK: - JSON entry points

public extension LexValue {
    /// Parses JSON under the AT Protocol data-model rules.
    ///
    /// Rejected, each with a ``LexValueError`` that names the JSON pointer of
    /// the offending value:
    /// - numbers that are not integers (`123.456`; `123.0` and `1e3` are
    ///   integers and are accepted) or that do not fit in 64 signed bits;
    /// - `$type` that is not a non-empty string;
    /// - `$link` / `$bytes` objects with extra keys, a non-string payload, an
    ///   unparseable or unblessed CID, or invalid base64;
    /// - `$type: "blob"` objects that lack a `ref` link, a non-empty
    ///   `mimeType`, or a non-negative integer `size`;
    /// - duplicate object keys, lone surrogates, and nesting beyond
    ///   ``ParseOptions/maximumDepth``.
    ///
    /// - Parameters:
    ///   - json: UTF-8 encoded JSON text.
    ///   - options: Parser limits and CID policy.
    /// - Throws: ``LexValueError``.
    init(json: Data, options: ParseOptions = .standard) throws {
        var parser = LexJSONParser(bytes: [UInt8](json), options: options)
        self = try parser.parseDocument()
    }

    /// Parses a JSON string. See ``init(json:options:)``.
    init(jsonString: String, options: ParseOptions = .standard) throws {
        try self.init(json: Data(jsonString.utf8), options: options)
    }

    /// Parses JSON that must be an object at the top level, which is what the
    /// data model requires of a record, an XRPC body or an event.
    ///
    /// - Throws: ``LexValueError`` with code ``LexValueError/Code/notAnObject``
    ///   for any other top-level value, or any error of ``init(json:options:)``.
    static func record(json: Data, options: ParseOptions = .standard) throws -> LexValue {
        let value = try LexValue(json: json, options: options)
        guard case .object = value else {
            throw LexValueError(.notAnObject, path: "", "top-level value must be an object, found \(value.kind)")
        }
        return value
    }

    /// Serializes to JSON using the data model's conventions: links as
    /// `{"$link": …}`, bytes as `{"$bytes": …}` (unpadded base64). Object keys
    /// are written in sorted order so the output is deterministic.
    func jsonData() -> Data {
        var output = [UInt8]()
        LexJSONWriter.write(self, into: &output)
        return Data(output)
    }

    /// ``jsonData()`` as a `String`.
    func jsonString() -> String {
        String(decoding: jsonData(), as: UTF8.self)
    }
}

// MARK: - Parser

/// A small strict RFC 8259 parser. Foundation's `JSONSerialization` cannot be
/// used here: it loses the integer/float distinction the data model depends
/// on, silently keeps the last of two duplicate keys, and bridges numbers and
/// booleans differently on Darwin and Linux.
struct LexJSONParser {
    let bytes: [UInt8]
    let options: LexValue.ParseOptions
    var index = 0

    mutating func parseDocument() throws -> LexValue {
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            index = 3
        }
        skipWhitespace()
        let value = try parseValue(path: "", depth: 0)
        skipWhitespace()
        guard index == bytes.count else {
            throw malformed("unexpected trailing content at byte \(index)", path: "")
        }
        return value
    }

    private func malformed(_ message: String, path: String) -> LexValueError {
        LexValueError(.malformedJSON, path: path, message)
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D:
                index += 1
            default:
                return
            }
        }
    }

    private mutating func parseValue(path: String, depth: Int) throws -> LexValue {
        guard index < bytes.count else {
            throw malformed("unexpected end of input", path: path)
        }
        switch bytes[index] {
        case UInt8(ascii: "{"):
            return try parseObject(path: path, depth: depth)
        case UInt8(ascii: "["):
            return try parseArray(path: path, depth: depth)
        case UInt8(ascii: "\""):
            return try .string(parseString(path: path))
        case UInt8(ascii: "t"):
            try expectLiteral("true", path: path)
            return .boolean(true)
        case UInt8(ascii: "f"):
            try expectLiteral("false", path: path)
            return .boolean(false)
        case UInt8(ascii: "n"):
            try expectLiteral("null", path: path)
            return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return try parseNumber(path: path)
        default:
            throw malformed("unexpected byte 0x\(String(bytes[index], radix: 16)) at offset \(index)", path: path)
        }
    }

    private mutating func expectLiteral(_ literal: String, path: String) throws {
        let expected = Array(literal.utf8)
        guard index + expected.count <= bytes.count, Array(bytes[index ..< index + expected.count]) == expected else {
            throw malformed("invalid literal at offset \(index)", path: path)
        }
        index += expected.count
    }

    private mutating func parseArray(path: String, depth: Int) throws -> LexValue {
        guard depth < options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        index += 1
        var items: [LexValue] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return .array(items)
        }
        while true {
            skipWhitespace()
            try items.append(parseValue(path: LexPath.appending(path, items.count), depth: depth + 1))
            skipWhitespace()
            guard index < bytes.count else {
                throw malformed("unterminated array", path: path)
            }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array(items)
            }
            throw malformed("expected ',' or ']' at offset \(index)", path: path)
        }
    }

    private mutating func parseObject(path: String, depth: Int) throws -> LexValue {
        guard depth < options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        index += 1
        var fields: [String: LexValue] = [:]
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return .object(fields)
        }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else {
                throw malformed("expected a string key at offset \(index)", path: path)
            }
            let key = try parseString(path: path)
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else {
                throw malformed("expected ':' at offset \(index)", path: path)
            }
            index += 1
            skipWhitespace()
            let childPath = LexPath.appending(path, key)
            let value = try parseValue(path: childPath, depth: depth + 1)
            guard fields.updateValue(value, forKey: key) == nil else {
                throw LexValueError(.duplicateKey, path: childPath, "object repeats the key \"\(key)\"")
            }
            skipWhitespace()
            guard index < bytes.count else {
                throw malformed("unterminated object", path: path)
            }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "}") {
                index += 1
                return try LexValue.normalizedObject(fields, path: path, options: options, fromJSON: true)
            }
            throw malformed("expected ',' or '}' at offset \(index)", path: path)
        }
    }

    private mutating func parseString(path: String) throws -> String {
        index += 1
        var scalars = [UInt8]()
        while true {
            guard index < bytes.count else {
                throw malformed("unterminated string", path: path)
            }
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "\""):
                index += 1
                guard let string = String(validatingUTF8Bytes: scalars) else {
                    throw malformed("string is not valid UTF-8", path: path)
                }
                return string
            case UInt8(ascii: "\\"):
                index += 1
                try parseEscape(into: &scalars, path: path)
            case 0x00 ..< 0x20:
                throw malformed("unescaped control character in string at offset \(index)", path: path)
            default:
                scalars.append(byte)
                index += 1
            }
        }
    }

    private mutating func parseEscape(into output: inout [UInt8], path: String) throws {
        guard index < bytes.count else {
            throw malformed("unterminated escape", path: path)
        }
        let byte = bytes[index]
        index += 1
        switch byte {
        case UInt8(ascii: "\""): output.append(UInt8(ascii: "\""))
        case UInt8(ascii: "\\"): output.append(UInt8(ascii: "\\"))
        case UInt8(ascii: "/"): output.append(UInt8(ascii: "/"))
        case UInt8(ascii: "b"): output.append(0x08)
        case UInt8(ascii: "f"): output.append(0x0C)
        case UInt8(ascii: "n"): output.append(0x0A)
        case UInt8(ascii: "r"): output.append(0x0D)
        case UInt8(ascii: "t"): output.append(0x09)
        case UInt8(ascii: "u"):
            let first = try parseHex4(path: path)
            var scalarValue = UInt32(first)
            if (0xD800 ... 0xDBFF).contains(first) {
                guard index + 1 < bytes.count, bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") else {
                    throw malformed("lone high surrogate in string", path: path)
                }
                index += 2
                let second = try parseHex4(path: path)
                guard (0xDC00 ... 0xDFFF).contains(second) else {
                    throw malformed("invalid surrogate pair in string", path: path)
                }
                scalarValue = 0x10000 + ((UInt32(first) - 0xD800) << 10) + (UInt32(second) - 0xDC00)
            } else if (0xDC00 ... 0xDFFF).contains(first) {
                throw malformed("lone low surrogate in string", path: path)
            }
            guard let scalar = Unicode.Scalar(scalarValue) else {
                throw malformed("invalid unicode escape", path: path)
            }
            output.append(contentsOf: Array(String(Character(scalar)).utf8))
        default:
            throw malformed("invalid escape sequence", path: path)
        }
    }

    private mutating func parseHex4(path: String) throws -> UInt16 {
        guard index + 4 <= bytes.count else {
            throw malformed("truncated unicode escape", path: path)
        }
        var value: UInt16 = 0
        for offset in 0 ..< 4 {
            let byte = bytes[index + offset]
            let digit: UInt16
            switch byte {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"): digit = UInt16(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a") ... UInt8(ascii: "f"): digit = UInt16(byte - UInt8(ascii: "a")) + 10
            case UInt8(ascii: "A") ... UInt8(ascii: "F"): digit = UInt16(byte - UInt8(ascii: "A")) + 10
            default: throw malformed("invalid unicode escape", path: path)
            }
            value = value << 4 | digit
        }
        index += 4
        return value
    }

    private mutating func parseNumber(path: String) throws -> LexValue {
        let start = index
        if bytes[index] == UInt8(ascii: "-") {
            index += 1
        }
        guard index < bytes.count, isDigit(bytes[index]) else {
            throw malformed("invalid number at offset \(start)", path: path)
        }
        if bytes[index] == UInt8(ascii: "0") {
            index += 1
        } else {
            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }
        var isIntegerLiteral = true
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            isIntegerLiteral = false
            index += 1
            guard index < bytes.count, isDigit(bytes[index]) else {
                throw malformed("invalid number at offset \(start)", path: path)
            }
            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }
        if index < bytes.count, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
            isIntegerLiteral = false
            index += 1
            if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") {
                index += 1
            }
            guard index < bytes.count, isDigit(bytes[index]) else {
                throw malformed("invalid number at offset \(start)", path: path)
            }
            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
        }
        let literal = String(decoding: bytes[start ..< index], as: UTF8.self)
        if isIntegerLiteral {
            guard let value = Int64(literal) else {
                throw LexValueError(.integerOutOfRange, path: path, "\(literal) does not fit in a signed 64-bit integer")
            }
            return .integer(value)
        }
        // A fraction or exponent is still an integer when it reduces to one
        // ("123.0", "1e3"): the official data-model-valid.json vector
        // "float, but integer-like" requires this.
        guard let double = Double(literal), double.isFinite, double.rounded(.towardZero) == double else {
            throw LexValueError(.floatNotAllowed, path: path, "\(literal) is not an integer; floats are not part of the data model")
        }
        guard let value = Int64(exactly: double) else {
            throw LexValueError(.integerOutOfRange, path: path, "\(literal) does not fit in a signed 64-bit integer")
        }
        return .integer(value)
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}

// MARK: - Writer

enum LexJSONWriter {
    static func write(_ value: LexValue, into output: inout [UInt8]) {
        switch value {
        case .null:
            output.append(contentsOf: Array("null".utf8))
        case let .boolean(flag):
            output.append(contentsOf: Array((flag ? "true" : "false").utf8))
        case let .integer(number):
            output.append(contentsOf: Array(String(number).utf8))
        case let .string(string):
            writeString(string, into: &output)
        case let .bytes(data):
            output.append(contentsOf: Array("{\"$bytes\":".utf8))
            writeString(LexBase64.encode(data), into: &output)
            output.append(UInt8(ascii: "}"))
        case let .cidLink(cid):
            output.append(contentsOf: Array("{\"$link\":".utf8))
            writeString(cid.string, into: &output)
            output.append(UInt8(ascii: "}"))
        case let .array(items):
            output.append(UInt8(ascii: "["))
            for (index, item) in items.enumerated() {
                if index > 0 {
                    output.append(UInt8(ascii: ","))
                }
                write(item, into: &output)
            }
            output.append(UInt8(ascii: "]"))
        case let .object(fields):
            output.append(UInt8(ascii: "{"))
            for (index, key) in fields.keys.sorted().enumerated() {
                if index > 0 {
                    output.append(UInt8(ascii: ","))
                }
                writeString(key, into: &output)
                output.append(UInt8(ascii: ":"))
                if let child = fields[key] {
                    write(child, into: &output)
                }
            }
            output.append(UInt8(ascii: "}"))
        }
    }

    private static let hexDigits = Array("0123456789abcdef".utf8)

    static func writeString(_ string: String, into output: inout [UInt8]) {
        output.append(UInt8(ascii: "\""))
        for byte in string.utf8 {
            switch byte {
            case UInt8(ascii: "\""):
                output.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "\"")])
            case UInt8(ascii: "\\"):
                output.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "\\")])
            case 0x0A:
                output.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "n")])
            case 0x0D:
                output.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "r")])
            case 0x09:
                output.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "t")])
            case 0x00 ..< 0x20:
                output.append(contentsOf: Array("\\u00".utf8))
                output.append(hexDigits[Int(byte >> 4)])
                output.append(hexDigits[Int(byte & 0x0F)])
            default:
                output.append(byte)
            }
        }
        output.append(UInt8(ascii: "\""))
    }
}

// MARK: - Codable

extension LexValue: Codable {
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? {
            nil
        }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            return nil
        }
    }

    /// Decodes from any `Decoder` and applies the same data-model rules as
    /// ``init(json:options:)`` (with ``ParseOptions/standard``).
    ///
    /// Prefer ``init(json:options:)`` for JSON input: a generic `Decoder`
    /// cannot report duplicate keys, and `JSONDecoder` decides on its own
    /// which numbers are integers.
    public init(from decoder: Decoder) throws {
        do {
            self = try LexValue.decode(from: decoder, depth: 0)
        } catch let error as LexValueError {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: error.description, underlyingError: error)
            )
        }
    }

    private static func decode(from decoder: Decoder, depth: Int) throws -> LexValue {
        let options = ParseOptions.standard
        let path = decoder.codingPath.reduce(into: "") { partial, key in
            partial += "/" + LexPath.escape(key.intValue.map(String.init) ?? key.stringValue)
        }
        guard depth <= options.maximumDepth else {
            throw LexValueError(.depthLimitExceeded, path: path, "value nests deeper than \(options.maximumDepth)")
        }
        if let keyed = try? decoder.container(keyedBy: AnyKey.self) {
            var fields: [String: LexValue] = [:]
            for key in keyed.allKeys {
                fields[key.stringValue] = try decode(from: keyed.superDecoder(forKey: key), depth: depth + 1)
            }
            return try normalizedObject(fields, path: path, options: options, fromJSON: true)
        }
        if var unkeyed = try? decoder.unkeyedContainer() {
            var items: [LexValue] = []
            while !unkeyed.isAtEnd {
                try items.append(decode(from: unkeyed.superDecoder(), depth: depth + 1))
            }
            return .array(items)
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            return .null
        }
        if let flag = try? single.decode(Bool.self) {
            return .boolean(flag)
        }
        if let number = try? single.decode(Int64.self) {
            return .integer(number)
        }
        if let double = try? single.decode(Double.self) {
            guard double.isFinite, double.rounded(.towardZero) == double, let number = Int64(exactly: double) else {
                throw LexValueError(.floatNotAllowed, path: path, "\(double) is not a 64-bit integer; floats are not part of the data model")
            }
            return .integer(number)
        }
        if let string = try? single.decode(String.self) {
            return .string(string)
        }
        throw LexValueError(.malformedJSON, path: path, "unsupported value")
    }

    /// Encodes using the JSON conventions of the data model (`$link`,
    /// `$bytes`).
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .boolean(flag):
            var container = encoder.singleValueContainer()
            try container.encode(flag)
        case let .integer(number):
            var container = encoder.singleValueContainer()
            try container.encode(number)
        case let .string(string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case let .bytes(data):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(LexBase64.encode(data), forKey: AnyKey(stringValue: "$bytes"))
        case let .cidLink(cid):
            var container = encoder.container(keyedBy: AnyKey.self)
            try container.encode(cid.string, forKey: AnyKey(stringValue: "$link"))
        case let .array(items):
            var container = encoder.unkeyedContainer()
            for item in items {
                try container.encode(item)
            }
        case let .object(fields):
            var container = encoder.container(keyedBy: AnyKey.self)
            for key in fields.keys.sorted() {
                if let child = fields[key] {
                    try container.encode(child, forKey: AnyKey(stringValue: key))
                }
            }
        }
    }
}
