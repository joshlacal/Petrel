import Foundation
import Petrel

/// Why a JSON document is not a valid AT Protocol data-model value.
public enum RepositoryRecordJSONError: Error, Sendable, Equatable {
    /// The text is not well-formed JSON (RFC 8259), or has trailing content.
    case malformedJSON
    /// An object repeats a key.
    case duplicateKey(String)
    /// A number has a fractional part or is outside the 64-bit integer range.
    /// The data model has no floating-point type.
    case nonIntegerNumber
    /// A `$link` object is not exactly `{"$link": "<cid>"}` with a valid CID.
    case invalidLink
    /// A `$bytes` object is not exactly `{"$bytes": "<base64>"}`.
    case invalidBytes
    /// A `$type: "blob"` object lacks `ref`, `mimeType` or `size`, or one of
    /// them has the wrong type.
    case invalidBlob
    /// A record's top level is not an object with a non-empty string `$type`.
    case invalidRecord
    /// The document nests more deeply than the limit.
    case nestingTooDeep
}

public extension PublicRecordValue {
    /// Parses the JSON representation of a data-model value.
    ///
    /// Applies the data model's JSON conventions: `{"$link": cid}` becomes a
    /// link, `{"$bytes": base64}` becomes bytes, a number must be an integer
    /// (`123.0` is accepted as 123; `123.456` is not), and a blob object must
    /// have a link `ref`, a string `mimeType` and an integer `size`.
    ///
    /// The parser is strict JSON: no duplicate keys, no trailing content, no
    /// lone surrogates.
    ///
    /// - Parameters:
    ///   - json: UTF-8 JSON text.
    ///   - maximumDepth: Deepest allowed nesting of arrays and objects.
    /// - Throws: ``RepositoryRecordJSONError``.
    init(json: Data, maximumDepth: Int = 64) throws {
        var parser = DataModelJSONParser(bytes: Array(json), maximumDepth: maximumDepth)
        self = try parser.parseDocument()
    }

    /// The JSON representation of this value, with object keys sorted.
    func jsonData() -> Data {
        var output = [UInt8]()
        DataModelJSONWriter.write(self, to: &output)
        return Data(output)
    }

    /// Encodes this value as canonical DAG-CBOR (DRISL).
    ///
    /// The encoder is strict, as the specification asks of writers: integers
    /// must be within ±(2^53 − 1) and links must be blessed CIDs.
    ///
    /// - Throws: ``PublicRepositoryDomainError``.
    func dagCBOR(maximumDepth: Int = 64) throws -> Data {
        try PublicRepositoryRecordCodec.encodeValue(self, maximumDepth: maximumDepth)
    }

    /// Strictly decodes a DAG-CBOR map into a data-model value.
    ///
    /// Rejects everything DAG-CBOR forbids: floats, indefinite lengths,
    /// non-minimal integers and lengths, map keys that are unsorted,
    /// duplicated or not strings, tags other than 42, a tag 42 that is not a
    /// CID, and trailing bytes.
    ///
    /// - Parameters:
    ///   - dagCBOR: The encoded map.
    ///   - policy: What to tolerate in integers and links.
    ///   - maximumDepth: Deepest allowed nesting.
    /// - Throws: ``RepositoryMSTValidationError/invalidRecordBlock`` or
    ///   ``RepositoryMSTValidationError/unsupportedRecordLink``.
    init(
        dagCBOR: Data,
        policy: RepositoryReadPolicy = .dataModel,
        maximumDepth: Int = 64
    ) throws {
        let container = try RepositoryRecordBlockValidator.decodeObject(
            dagCBOR, maximumDepth: maximumDepth, policy: policy
        )
        self = try PublicRecordValue(dataModel: container)
    }

    /// Converts the plain data-model cases of Petrel's generic value
    /// container. Typed (`knownType`) and error cases are not data-model
    /// values and are refused.
    internal init(dataModel container: ATProtocolValueContainer) throws {
        switch container {
        case .null: self = .null
        case let .bool(value): self = .bool(value)
        case let .number(value): self = .integer(value)
        case let .string(value): self = .string(value)
        case let .bytes(value): self = .bytes(value.data)
        case let .link(value): self = .link(value.cid)
        case let .array(values):
            self = .array(try values.map { try PublicRecordValue(dataModel: $0) })
        case let .object(fields):
            self = .object(try fields.mapValues { try PublicRecordValue(dataModel: $0) })
        default:
            throw RepositoryMSTValidationError.invalidRecordBlock
        }
    }
}

public extension PublicRecord {
    /// Parses a record from its JSON representation.
    ///
    /// The top level must be an object whose `$type` is a non-empty string.
    ///
    /// - Throws: ``RepositoryRecordJSONError``.
    init(json: Data, maximumDepth: Int = 64) throws {
        guard case let .object(fields) = try PublicRecordValue(json: json, maximumDepth: maximumDepth),
              case let .string(type)? = fields["$type"], !type.isEmpty else {
            throw RepositoryRecordJSONError.invalidRecord
        }
        self.init(fields)
    }

    /// The record's `$type`, if it has one.
    var type: String? {
        if case let .string(type)? = fields["$type"] { return type }
        return nil
    }

    /// The JSON representation of this record, with object keys sorted.
    func jsonData() -> Data {
        PublicRecordValue.object(fields).jsonData()
    }
}

// MARK: - Parser

/// A strict RFC 8259 parser that produces data-model values directly, so no
/// intermediate number type can blur the line between `1`, `1.0` and `true`.
private struct DataModelJSONParser {
    let bytes: [UInt8]
    let maximumDepth: Int
    var offset = 0

    mutating func parseDocument() throws -> PublicRecordValue {
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard offset == bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
        return value
    }

    private mutating func skipWhitespace() {
        while offset < bytes.count,
              bytes[offset] == 0x20 || bytes[offset] == 0x09
              || bytes[offset] == 0x0a || bytes[offset] == 0x0d {
            offset += 1
        }
    }

    private mutating func parseValue(depth: Int) throws -> PublicRecordValue {
        guard offset < bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
        switch bytes[offset] {
        case UInt8(ascii: "{"):
            return try parseObject(depth: depth)
        case UInt8(ascii: "["):
            return try parseArray(depth: depth)
        case UInt8(ascii: "\""):
            return .string(try parseString())
        case UInt8(ascii: "t"):
            try expect("true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try expect("false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try expect("null")
            return .null
        default:
            return .integer(try parseNumber())
        }
    }

    private mutating func expect(_ literal: String) throws {
        let expected = Array(literal.utf8)
        guard bytes.count - offset >= expected.count,
              Array(bytes[offset ..< offset + expected.count]) == expected else {
            throw RepositoryRecordJSONError.malformedJSON
        }
        offset += expected.count
    }

    private mutating func parseArray(depth: Int) throws -> PublicRecordValue {
        guard depth < maximumDepth else { throw RepositoryRecordJSONError.nestingTooDeep }
        offset += 1
        var values: [PublicRecordValue] = []
        skipWhitespace()
        if offset < bytes.count, bytes[offset] == UInt8(ascii: "]") {
            offset += 1
            return .array(values)
        }
        while true {
            skipWhitespace()
            values.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            guard offset < bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
            if bytes[offset] == UInt8(ascii: ",") {
                offset += 1
            } else if bytes[offset] == UInt8(ascii: "]") {
                offset += 1
                return .array(values)
            } else {
                throw RepositoryRecordJSONError.malformedJSON
            }
        }
    }

    private mutating func parseObject(depth: Int) throws -> PublicRecordValue {
        guard depth < maximumDepth else { throw RepositoryRecordJSONError.nestingTooDeep }
        offset += 1
        var fields: [String: PublicRecordValue] = [:]
        skipWhitespace()
        if offset < bytes.count, bytes[offset] == UInt8(ascii: "}") {
            offset += 1
            return .object(fields)
        }
        while true {
            skipWhitespace()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: "\"") else {
                throw RepositoryRecordJSONError.malformedJSON
            }
            let key = try parseString()
            skipWhitespace()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: ":") else {
                throw RepositoryRecordJSONError.malformedJSON
            }
            offset += 1
            skipWhitespace()
            let value = try parseValue(depth: depth + 1)
            guard fields.updateValue(value, forKey: key) == nil else {
                throw RepositoryRecordJSONError.duplicateKey(key)
            }
            skipWhitespace()
            guard offset < bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
            if bytes[offset] == UInt8(ascii: ",") {
                offset += 1
            } else if bytes[offset] == UInt8(ascii: "}") {
                offset += 1
                return try Self.interpret(fields)
            } else {
                throw RepositoryRecordJSONError.malformedJSON
            }
        }
    }

    /// Applies the data model's reserved-key conventions to a JSON object.
    private static func interpret(
        _ fields: [String: PublicRecordValue]
    ) throws -> PublicRecordValue {
        if let link = fields["$link"] {
            guard fields.count == 1, case let .string(text) = link,
                  let cid = try? CID.parse(text) else {
                throw RepositoryRecordJSONError.invalidLink
            }
            return .link(cid)
        }
        if let encoded = fields["$bytes"] {
            guard fields.count == 1, case let .string(text) = encoded,
                  let data = decodeBase64(text) else {
                throw RepositoryRecordJSONError.invalidBytes
            }
            return .bytes(data)
        }
        if let type = fields["$type"] {
            // `$type` is always a non-empty string wherever it appears.
            guard case let .string(name) = type, !name.isEmpty else {
                throw RepositoryRecordJSONError.invalidRecord
            }
            if name == "blob" {
                guard case .link? = fields["ref"],
                      case .string? = fields["mimeType"],
                      case let .integer(size)? = fields["size"], size >= 0 else {
                    throw RepositoryRecordJSONError.invalidBlob
                }
            }
        }
        return .object(fields)
    }

    /// RFC 4648 §4 base64; padding is optional, as the data model allows.
    private static func decodeBase64(_ text: String) -> Data? {
        var unpadded = Substring(text)
        while unpadded.hasSuffix("=") { unpadded.removeLast() }
        guard !unpadded.contains("="), unpadded.utf8.count % 4 != 1 else { return nil }
        let padding = String(repeating: "=", count: (4 - unpadded.utf8.count % 4) % 4)
        return Data(base64Encoded: String(unpadded) + padding)
    }

    private mutating func parseNumber() throws -> Int {
        let start = offset
        let isNegative = offset < bytes.count && bytes[offset] == UInt8(ascii: "-")
        if isNegative { offset += 1 }
        let integerStart = offset
        while offset < bytes.count, (0x30 ... 0x39).contains(bytes[offset]) { offset += 1 }
        let integerEnd = offset
        let integerDigits = integerEnd - integerStart
        guard integerDigits > 0,
              integerDigits == 1 || bytes[integerStart] != UInt8(ascii: "0") else {
            throw RepositoryRecordJSONError.malformedJSON
        }
        var fraction = offset ..< offset
        if offset < bytes.count, bytes[offset] == UInt8(ascii: ".") {
            offset += 1
            let fractionStart = offset
            while offset < bytes.count, (0x30 ... 0x39).contains(bytes[offset]) { offset += 1 }
            guard offset > fractionStart else { throw RepositoryRecordJSONError.malformedJSON }
            fraction = fractionStart ..< offset
        }
        var exponent: (isNegative: Bool, digits: Range<Int>)?
        if offset < bytes.count, bytes[offset] == UInt8(ascii: "e") || bytes[offset] == UInt8(ascii: "E") {
            offset += 1
            var exponentIsNegative = false
            if offset < bytes.count,
               bytes[offset] == UInt8(ascii: "+") || bytes[offset] == UInt8(ascii: "-") {
                exponentIsNegative = bytes[offset] == UInt8(ascii: "-")
                offset += 1
            }
            let exponentStart = offset
            while offset < bytes.count, (0x30 ... 0x39).contains(bytes[offset]) { offset += 1 }
            guard offset > exponentStart else { throw RepositoryRecordJSONError.malformedJSON }
            exponent = (exponentIsNegative, exponentStart ..< offset)
        }
        if fraction.isEmpty, exponent == nil {
            let text = String(decoding: bytes[start ..< offset], as: UTF8.self)
            guard let value = Int(text) else { throw RepositoryRecordJSONError.nonIntegerNumber }
            return value
        }
        // Written with a fraction or exponent: accepted only when the decimal
        // value is exactly a whole number in range. Decided on the digits
        // themselves; a floating-point intermediate would round
        // `1.00000000000000001` or `1e-9999` into an integer.
        return try Self.exactInteger(
            isNegative: isNegative,
            digits: Array(bytes[integerStart ..< integerEnd]) + Array(bytes[fraction]),
            fractionDigits: fraction.count,
            exponent: exponent.map { (isNegative: $0.isNegative, digits: Array(bytes[$0.digits])) }
        )
    }

    /// The integer `±digits × 10^(exponent − fractionDigits)`, or
    /// `nonIntegerNumber` if that value is not a whole number in `Int`'s range.
    private static func exactInteger(
        isNegative: Bool,
        digits: [UInt8],
        fractionDigits: Int,
        exponent: (isNegative: Bool, digits: [UInt8])?
    ) throws -> Int {
        // Significant digits: no leading zeros, trailing zeros folded into
        // the scale.
        var significand = digits.drop { $0 == UInt8(ascii: "0") }
        if significand.isEmpty { return 0 } // zero in any spelling
        var scale = -fractionDigits
        while significand.last == UInt8(ascii: "0") {
            significand.removeLast()
            scale += 1
        }
        // Any exponent this large makes a nonzero value either fractional or
        // far outside Int's 19 digits; parsing it exactly is unnecessary.
        if let exponent {
            let magnitude = exponent.digits.drop { $0 == UInt8(ascii: "0") }
            guard magnitude.count <= 9 else { throw RepositoryRecordJSONError.nonIntegerNumber }
            let value = Int(String(decoding: magnitude, as: UTF8.self)) ?? 0
            scale += exponent.isNegative ? -value : value
        }
        guard scale >= 0, significand.count + scale <= 19 else {
            throw RepositoryRecordJSONError.nonIntegerNumber
        }
        let text = (isNegative ? "-" : "")
            + String(decoding: significand, as: UTF8.self)
            + String(repeating: "0", count: scale)
        guard let value = Int(text) else { throw RepositoryRecordJSONError.nonIntegerNumber }
        return value
    }

    private mutating func parseString() throws -> String {
        offset += 1
        var scalars = String.UnicodeScalarView()
        var raw: [UInt8] = []
        func flush() throws {
            guard !raw.isEmpty else { return }
            guard let text = String(validating: raw, as: UTF8.self) else {
                throw RepositoryRecordJSONError.malformedJSON
            }
            scalars.append(contentsOf: text.unicodeScalars)
            raw.removeAll(keepingCapacity: true)
        }
        while true {
            guard offset < bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
            let byte = bytes[offset]
            offset += 1
            switch byte {
            case UInt8(ascii: "\""):
                try flush()
                return String(scalars)
            case UInt8(ascii: "\\"):
                try flush()
                guard offset < bytes.count else { throw RepositoryRecordJSONError.malformedJSON }
                let escape = bytes[offset]
                offset += 1
                switch escape {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "b"): scalars.append("\u{08}")
                case UInt8(ascii: "f"): scalars.append("\u{0C}")
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "u"):
                    var code = try parseHex4()
                    if (0xD800 ... 0xDBFF).contains(code) {
                        guard bytes.count - offset >= 2,
                              bytes[offset] == UInt8(ascii: "\\"),
                              bytes[offset + 1] == UInt8(ascii: "u") else {
                            throw RepositoryRecordJSONError.malformedJSON
                        }
                        offset += 2
                        let low = try parseHex4()
                        guard (0xDC00 ... 0xDFFF).contains(low) else {
                            throw RepositoryRecordJSONError.malformedJSON
                        }
                        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                    }
                    guard let scalar = Unicode.Scalar(code) else {
                        throw RepositoryRecordJSONError.malformedJSON
                    }
                    scalars.append(scalar)
                default:
                    throw RepositoryRecordJSONError.malformedJSON
                }
            case 0x00 ... 0x1f:
                throw RepositoryRecordJSONError.malformedJSON
            default:
                raw.append(byte)
            }
        }
    }

    private mutating func parseHex4() throws -> UInt32 {
        guard bytes.count - offset >= 4 else { throw RepositoryRecordJSONError.malformedJSON }
        var value: UInt32 = 0
        for byte in bytes[offset ..< offset + 4] {
            let digit: UInt32
            switch byte {
            case 0x30 ... 0x39: digit = UInt32(byte - 0x30)
            case 0x41 ... 0x46: digit = UInt32(byte - 0x41 + 10)
            case 0x61 ... 0x66: digit = UInt32(byte - 0x61 + 10)
            default: throw RepositoryRecordJSONError.malformedJSON
            }
            value = value << 4 | digit
        }
        offset += 4
        return value
    }
}

// MARK: - Writer

private enum DataModelJSONWriter {
    static func write(_ value: PublicRecordValue, to output: inout [UInt8]) {
        switch value {
        case .null:
            output.append(contentsOf: "null".utf8)
        case let .bool(flag):
            output.append(contentsOf: (flag ? "true" : "false").utf8)
        case let .integer(number):
            output.append(contentsOf: String(number).utf8)
        case let .string(text):
            writeString(text, to: &output)
        case let .bytes(data):
            output.append(contentsOf: "{\"$bytes\":".utf8)
            let encoded = data.base64EncodedString().replacingOccurrences(of: "=", with: "")
            writeString(encoded, to: &output)
            output.append(UInt8(ascii: "}"))
        case let .link(cid):
            output.append(contentsOf: "{\"$link\":".utf8)
            writeString(cid.string, to: &output)
            output.append(UInt8(ascii: "}"))
        case let .array(values):
            output.append(UInt8(ascii: "["))
            for (index, element) in values.enumerated() {
                if index > 0 { output.append(UInt8(ascii: ",")) }
                write(element, to: &output)
            }
            output.append(UInt8(ascii: "]"))
        case let .object(fields):
            output.append(UInt8(ascii: "{"))
            for (index, key) in fields.keys.sorted().enumerated() {
                if index > 0 { output.append(UInt8(ascii: ",")) }
                writeString(key, to: &output)
                output.append(UInt8(ascii: ":"))
                if let element = fields[key] {
                    write(element, to: &output)
                }
            }
            output.append(UInt8(ascii: "}"))
        }
    }

    private static func writeString(_ text: String, to output: inout [UInt8]) {
        output.append(UInt8(ascii: "\""))
        for byte in text.utf8 {
            switch byte {
            case UInt8(ascii: "\""): output.append(contentsOf: "\\\"".utf8)
            case UInt8(ascii: "\\"): output.append(contentsOf: "\\\\".utf8)
            case 0x0a: output.append(contentsOf: "\\n".utf8)
            case 0x0d: output.append(contentsOf: "\\r".utf8)
            case 0x09: output.append(contentsOf: "\\t".utf8)
            case 0x00 ... 0x1f:
                output.append(contentsOf: String(format: "\\u%04x", byte).utf8)
            default:
                output.append(byte)
            }
        }
        output.append(UInt8(ascii: "\""))
    }
}
