import Foundation

/// Restricted RFC 9651 dictionary reader for the Spaces MAC fields. Values keep
/// their wire types; quoted "1", booleans, duplicate keys and inner lists cannot
/// masquerade as a version integer. Member parameters are parsed and ignored.
enum SpaceMACHeader {
    static func parse(_ header: String?, type: String) throws -> Data {
        guard let header, header.utf8.count <= 8192 else { throw SpaceVerificationError.malformedHeader }
        var parser = Parser(bytes: Array(header.utf8))
        let fields = try parser.dictionary()
        guard fields["type"] == .string(type), fields["ver"] == .integer(1),
              case let .bytes(mac)? = fields["mac"], mac.count == 32 else { throw SpaceVerificationError.malformedHeader }
        return mac
    }

    private enum Value: Equatable {
        case string(String), integer(Int), bytes(Data), boolean(Bool), token(String)
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0
        var current: UInt8? { index < bytes.count ? bytes[index] : nil }
        mutating func spaces() { while current == 32 || current == 9 { index += 1 } }
        mutating func take(_ byte: UInt8) throws {
            guard current == byte else { throw SpaceVerificationError.malformedHeader }
            index += 1
        }
        mutating func key() throws -> String {
            let start = index
            guard current == 42 || current.map({ (97...122).contains($0) }) == true else { throw SpaceVerificationError.malformedHeader }
            index += 1
            while let byte = current, (97...122).contains(byte) || (48...57).contains(byte) || [95, 45, 46, 42].contains(byte) { index += 1 }
            return String(decoding: bytes[start..<index], as: UTF8.self)
        }
        mutating func item() throws -> Value {
            guard let byte = current else { throw SpaceVerificationError.malformedHeader }
            if byte == 34 {
                index += 1
                var value: [UInt8] = []
                while let next = current, next != 34 {
                    index += 1
                    if next == 92 {
                        guard let escaped = current, escaped == 34 || escaped == 92 else { throw SpaceVerificationError.malformedHeader }
                        value.append(escaped); index += 1
                    } else {
                        guard (32...126).contains(next) else { throw SpaceVerificationError.malformedHeader }
                        value.append(next)
                    }
                }
                try take(34)
                return .string(String(decoding: value, as: UTF8.self))
            }
            if byte == 58 {
                index += 1
                let start = index
                while let next = current, next != 58 {
                    guard (65...90).contains(next) || (97...122).contains(next) || (48...57).contains(next) || [43, 47, 61].contains(next) else { throw SpaceVerificationError.malformedHeader }
                    index += 1
                }
                var encoded = String(decoding: bytes[start..<index], as: UTF8.self)
                try take(58)
                while encoded.count % 4 != 0 { encoded += "=" }
                guard let data = Data(base64Encoded: encoded) else { throw SpaceVerificationError.malformedHeader }
                return .bytes(data)
            }
            if byte == 63 {
                index += 1
                guard current == 48 || current == 49 else { throw SpaceVerificationError.malformedHeader }
                let value = current == 49; index += 1
                return .boolean(value)
            }
            if byte == 45 || (48...57).contains(byte) {
                let start = index
                if byte == 45 { index += 1 }
                let digits = index
                while let next = current, (48...57).contains(next) { index += 1 }
                guard index > digits, index - digits <= 15,
                      let value = Int(String(decoding: bytes[start..<index], as: UTF8.self)) else { throw SpaceVerificationError.malformedHeader }
                return .integer(value)
            }
            let start = index
            guard byte == 42 || (65...90).contains(byte) || (97...122).contains(byte) else { throw SpaceVerificationError.malformedHeader }
            while let next = current, (65...90).contains(next) || (97...122).contains(next) || (48...57).contains(next) || "!#$%&'*+-.^_`|~:/".utf8.contains(next) { index += 1 }
            return .token(String(decoding: bytes[start..<index], as: UTF8.self))
        }
        mutating func dictionary() throws -> [String: Value] {
            var fields: [String: Value] = [:]
            spaces()
            while current != nil {
                let name = try key()
                guard fields[name] == nil else { throw SpaceVerificationError.malformedHeader }
                let value: Value
                if current == 61 { index += 1; value = try item() } else { value = .boolean(true) }
                fields[name] = value
                while current == 59 {
                    index += 1
                    while current == 32 { index += 1 }
                    _ = try key()
                    if current == 61 { index += 1; _ = try item() }
                }
                spaces()
                if current == nil { break }
                try take(44); spaces()
                guard current != nil else { throw SpaceVerificationError.malformedHeader }
            }
            return fields
        }
    }
}
