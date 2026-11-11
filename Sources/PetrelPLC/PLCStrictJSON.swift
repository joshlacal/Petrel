import Foundation

/// Structural JSON validation applied before `JSONSerialization`: rejects
/// duplicate object keys, trailing data and hostile nesting depth.
enum StrictJSON {
    static func validate(_ data: Data) throws {
        var parser = Parser(bytes: Array(data))
        try parser.parseValue()
        parser.skipWhitespace()
        guard parser.index == parser.bytes.count else {
            throw PetrelPLCError.malformed("PLC JSON has trailing data")
        }
    }

    private struct Parser {
        static let maximumNestingDepth = 64

        let bytes: [UInt8]
        var index = 0

        mutating func parseValue(nestingDepth: Int = 0) throws {
            skipWhitespace()
            guard index < bytes.count else { throw malformed() }
            switch bytes[index] {
            case UInt8(ascii: "{"):
                let nestedDepth = try nextNestingDepth(after: nestingDepth)
                try parseObject(nestingDepth: nestedDepth)
            case UInt8(ascii: "["):
                let nestedDepth = try nextNestingDepth(after: nestingDepth)
                try parseArray(nestingDepth: nestedDepth)
            case UInt8(ascii: "\""): _ = try parseString()
            case UInt8(ascii: "t"): try consume("true")
            case UInt8(ascii: "f"): try consume("false")
            case UInt8(ascii: "n"): try consume("null")
            case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"): try parseNumber()
            default: throw malformed()
            }
        }

        mutating func parseObject(nestingDepth: Int) throws {
            index += 1
            skipWhitespace()
            if consumeIf(UInt8(ascii: "}")) { return }
            var keys = Set<String>()
            while true {
                skipWhitespace()
                let key = try parseString()
                guard keys.insert(key).inserted else {
                    throw PetrelPLCError.malformed("PLC JSON contains a duplicate map key")
                }
                skipWhitespace()
                guard consumeIf(UInt8(ascii: ":")) else { throw malformed() }
                try parseValue(nestingDepth: nestingDepth)
                skipWhitespace()
                if consumeIf(UInt8(ascii: "}")) { return }
                guard consumeIf(UInt8(ascii: ",")) else { throw malformed() }
            }
        }

        mutating func parseArray(nestingDepth: Int) throws {
            index += 1
            skipWhitespace()
            if consumeIf(UInt8(ascii: "]")) { return }
            while true {
                try parseValue(nestingDepth: nestingDepth)
                skipWhitespace()
                if consumeIf(UInt8(ascii: "]")) { return }
                guard consumeIf(UInt8(ascii: ",")) else { throw malformed() }
            }
        }

        func nextNestingDepth(after currentDepth: Int) throws -> Int {
            guard currentDepth < Self.maximumNestingDepth else {
                throw PetrelPLCError.malformed("PLC JSON exceeds maximum nesting depth")
            }
            return currentDepth + 1
        }

        mutating func parseString() throws -> String {
            guard consumeIf(UInt8(ascii: "\"")) else { throw malformed() }
            let start = index
            var escaped = false
            var sawEscape = false
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "\""), !escaped {
                    let range = start ..< index
                    index += 1
                    guard let raw = String(bytes: bytes[range], encoding: .utf8) else {
                        throw malformed()
                    }
                    // Without an escape the string denotes itself; only
                    // escaped strings need the JSON decoder.
                    guard sawEscape else { return raw }
                    guard let quoted = "\"\(raw)\"".data(using: .utf8),
                          let decoded = try JSONSerialization.jsonObject(
                              with: quoted,
                              options: [.fragmentsAllowed]
                          ) as? String else {
                        throw malformed()
                    }
                    return decoded
                }
                if byte < 0x20 { throw malformed() }
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                    sawEscape = true
                }
                index += 1
            }
            throw malformed()
        }

        mutating func parseNumber() throws {
            let start = index
            while index < bytes.count,
                  bytes[index] == UInt8(ascii: "-") ||
                  bytes[index] == UInt8(ascii: "+") ||
                  bytes[index] == UInt8(ascii: ".") ||
                  bytes[index] == UInt8(ascii: "e") ||
                  bytes[index] == UInt8(ascii: "E") ||
                  (bytes[index] >= UInt8(ascii: "0") && bytes[index] <= UInt8(ascii: "9")) {
                index += 1
            }
            guard index > start else { throw malformed() }
        }

        mutating func consume(_ literal: StaticString) throws {
            let expected = Array(String(describing: literal).utf8)
            guard index + expected.count <= bytes.count,
                  Array(bytes[index ..< index + expected.count]) == expected else {
                throw malformed()
            }
            index += expected.count
        }

        mutating func skipWhitespace() {
            while index < bytes.count, [0x20, 0x09, 0x0a, 0x0d].contains(bytes[index]) {
                index += 1
            }
        }

        mutating func consumeIf(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        private func malformed() -> PetrelPLCError {
            .malformed("PLC JSON is malformed")
        }
    }
}
