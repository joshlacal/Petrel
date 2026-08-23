import Foundation

/// Duplicate-member-free JSON validation shared by cryptographic verifiers.
/// It validates complete UTF-8 JSON before Codable would otherwise accept
/// duplicate keys with last-value-wins semantics.
public enum StrictJSON {
    public static func validate(_ data: Data) throws {
        var parser = Parser(bytes: Array(data), topLevelIntegerMembers: [])
        try parser.parseDocument()
    }

    /// Validates complete duplicate-free JSON while additionally requiring
    /// the named members of the root object to use JSON integer tokens.
    public static func validateTopLevelIntegerMembers(
        _ members: Set<String>,
        in data: Data
    ) throws {
        var parser = Parser(
            bytes: Array(data),
            topLevelIntegerMembers: members
        )
        try parser.parseDocument()
    }

    public static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        try validate(data)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as PetrelCryptoError {
            throw error
        } catch {
            throw PetrelCryptoError.malformed("invalid JSON")
        }
    }

    private struct Parser {
        static let maximumNestingDepth = 64

        let bytes: [UInt8]
        let topLevelIntegerMembers: Set<String>
        var index = 0

        mutating func parseDocument() throws {
            skipWhitespace()
            try parseValue(isTopLevel: true)
            skipWhitespace()
            guard index == bytes.count else { throw PetrelCryptoError.malformed("invalid JSON") }
        }

        mutating func parseValue(
            isTopLevel: Bool = false,
            requiresIntegerToken: Bool = false,
            nestingDepth: Int = 0
        ) throws {
            skipWhitespace()
            guard let byte = bytes[safe: index] else { throw PetrelCryptoError.malformed("invalid JSON") }
            if requiresIntegerToken,
               byte != 0x2D,
               !(0x30 ... 0x39).contains(byte) {
                throw PetrelCryptoError.malformed("JSON member must be an integer")
            }
            switch byte {
            case 0x7B:
                guard !requiresIntegerToken else {
                    throw PetrelCryptoError.malformed("JSON member must be an integer")
                }
                let nestedDepth = try nextNestingDepth(after: nestingDepth)
                try parseObject(
                    isTopLevel: isTopLevel,
                    nestingDepth: nestedDepth
                )
            case 0x5B:
                guard !requiresIntegerToken else {
                    throw PetrelCryptoError.malformed("JSON member must be an integer")
                }
                let nestedDepth = try nextNestingDepth(after: nestingDepth)
                try parseArray(nestingDepth: nestedDepth)
            case 0x22: _ = try parseString()
            case 0x74: try consumeLiteral("true")
            case 0x66: try consumeLiteral("false")
            case 0x6E: try consumeLiteral("null")
            case 0x2D, 0x30 ... 0x39:
                try parseNumber(requiresIntegerToken: requiresIntegerToken)
            default: throw PetrelCryptoError.malformed("invalid JSON")
            }
            if requiresIntegerToken,
               !(byte == 0x2D || (0x30 ... 0x39).contains(byte)) {
                throw PetrelCryptoError.malformed("JSON member must be an integer")
            }
        }

        mutating func parseObject(
            isTopLevel: Bool,
            nestingDepth: Int
        ) throws {
            try consume(0x7B)
            skipWhitespace()
            if consumeIf(0x7D) { return }
            var keys = Set<String>()
            while true {
                skipWhitespace()
                let key = try parseString()
                guard keys.insert(key).inserted else { throw PetrelCryptoError.malformed("duplicate JSON member") }
                skipWhitespace()
                try consume(0x3A)
                try parseValue(
                    requiresIntegerToken: isTopLevel
                        && topLevelIntegerMembers.contains(key),
                    nestingDepth: nestingDepth
                )
                skipWhitespace()
                if consumeIf(0x7D) { return }
                try consume(0x2C)
            }
        }

        mutating func parseArray(nestingDepth: Int) throws {
            try consume(0x5B)
            skipWhitespace()
            if consumeIf(0x5D) { return }
            while true {
                try parseValue(nestingDepth: nestingDepth)
                skipWhitespace()
                if consumeIf(0x5D) { return }
                try consume(0x2C)
            }
        }

        func nextNestingDepth(after currentDepth: Int) throws -> Int {
            guard currentDepth < Self.maximumNestingDepth else {
                throw PetrelCryptoError.malformed("JSON exceeds maximum nesting depth")
            }
            return currentDepth + 1
        }

        mutating func parseString() throws -> String {
            try consume(0x22)
            var result = ""
            var chunkStart = index
            while let byte = bytes[safe: index] {
                if byte == 0x22 {
                    try appendUTF8Chunk(start: chunkStart, to: index, into: &result)
                    index += 1
                    return result
                }
                if byte == 0x5C {
                    try appendUTF8Chunk(start: chunkStart, to: index, into: &result)
                    index += 1
                    guard let escape = bytes[safe: index] else { throw PetrelCryptoError.malformed("invalid JSON string") }
                    index += 1
                    switch escape {
                    case 0x22: result.append("\"")
                    case 0x5C: result.append("\\")
                    case 0x2F: result.append("/")
                    case 0x62: result.append("\u{08}")
                    case 0x66: result.append("\u{0C}")
                    case 0x6E: result.append("\n")
                    case 0x72: result.append("\r")
                    case 0x74: result.append("\t")
                    case 0x75: try appendUnicodeEscape(into: &result)
                    default: throw PetrelCryptoError.malformed("invalid JSON string")
                    }
                    chunkStart = index
                } else {
                    guard byte >= 0x20 else { throw PetrelCryptoError.malformed("invalid JSON string") }
                    index += 1
                }
            }
            throw PetrelCryptoError.malformed("invalid JSON string")
        }

        mutating func appendUnicodeEscape(into output: inout String) throws {
            let first = try parseHex16()
            if (0xD800 ... 0xDBFF).contains(first) {
                guard consumeIf(0x5C), consumeIf(0x75) else { throw PetrelCryptoError.malformed("invalid JSON surrogate") }
                let second = try parseHex16()
                guard (0xDC00 ... 0xDFFF).contains(second) else { throw PetrelCryptoError.malformed("invalid JSON surrogate") }
                let scalar = 0x10000 + ((UInt32(first) - 0xD800) << 10) + (UInt32(second) - 0xDC00)
                guard let value = UnicodeScalar(scalar) else { throw PetrelCryptoError.malformed("invalid JSON scalar") }
                output.unicodeScalars.append(value)
            } else {
                guard !(0xDC00 ... 0xDFFF).contains(first), let value = UnicodeScalar(UInt32(first)) else {
                    throw PetrelCryptoError.malformed("invalid JSON surrogate")
                }
                output.unicodeScalars.append(value)
            }
        }

        mutating func parseHex16() throws -> UInt16 {
            guard index + 4 <= bytes.count else { throw PetrelCryptoError.malformed("invalid JSON escape") }
            var result: UInt16 = 0
            for _ in 0 ..< 4 {
                guard let byte = bytes[safe: index] else { throw PetrelCryptoError.malformed("invalid JSON escape") }
                let nibble: UInt16
                switch byte {
                case 0x30 ... 0x39: nibble = UInt16(byte - 0x30)
                case 0x41 ... 0x46: nibble = UInt16(byte - 0x41 + 10)
                case 0x61 ... 0x66: nibble = UInt16(byte - 0x61 + 10)
                default: throw PetrelCryptoError.malformed("invalid JSON escape")
                }
                result = (result << 4) | nibble
                index += 1
            }
            return result
        }

        mutating func parseNumber(requiresIntegerToken: Bool) throws {
            _ = consumeIf(0x2D)
            guard let first = bytes[safe: index] else { throw PetrelCryptoError.malformed("invalid JSON number") }
            if first == 0x30 {
                index += 1
            } else if (0x31 ... 0x39).contains(first) {
                index += 1
                while let digit = bytes[safe: index], (0x30 ... 0x39).contains(digit) { index += 1 }
            } else {
                throw PetrelCryptoError.malformed("invalid JSON number")
            }
            let hasFraction = consumeIf(0x2E)
            if hasFraction {
                guard let digit = bytes[safe: index], (0x30 ... 0x39).contains(digit) else {
                    throw PetrelCryptoError.malformed("invalid JSON number")
                }
                while let digit = bytes[safe: index], (0x30 ... 0x39).contains(digit) { index += 1 }
            }
            var hasExponent = false
            if let exponent = bytes[safe: index], exponent == 0x45 || exponent == 0x65 {
                hasExponent = true
                index += 1
                _ = consumeIf(0x2B) || consumeIf(0x2D)
                guard let digit = bytes[safe: index], (0x30 ... 0x39).contains(digit) else {
                    throw PetrelCryptoError.malformed("invalid JSON number")
                }
                while let digit = bytes[safe: index], (0x30 ... 0x39).contains(digit) { index += 1 }
            }
            guard !requiresIntegerToken || (!hasFraction && !hasExponent) else {
                throw PetrelCryptoError.malformed("JSON member must be an integer")
            }
        }

        mutating func consumeLiteral(_ literal: String) throws {
            for byte in literal.utf8 { try consume(byte) }
        }

        mutating func skipWhitespace() {
            while let byte = bytes[safe: index], byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        mutating func consume(_ expected: UInt8) throws {
            guard consumeIf(expected) else { throw PetrelCryptoError.malformed("invalid JSON") }
        }

        mutating func consumeIf(_ expected: UInt8) -> Bool {
            guard bytes[safe: index] == expected else { return false }
            index += 1
            return true
        }

        func appendUTF8Chunk(start: Int, to end: Int, into output: inout String) throws {
            guard start <= end, let chunk = String(bytes: bytes[start ..< end], encoding: .utf8) else {
                throw PetrelCryptoError.malformed("invalid JSON UTF-8")
            }
            output.append(chunk)
        }
    }
}

private extension Array where Element == UInt8 {
    subscript(safe index: Int) -> UInt8? {
        indices.contains(index) ? self[index] : nil
    }
}
