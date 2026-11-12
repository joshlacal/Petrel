import Foundation
@testable import PetrelLexicon
import Testing

/// Access to the official `atproto-interop-tests` files vendored byte-identical
/// under `Vectors/`.
enum Vectors {
    static let root: URL = {
        guard let url = Bundle.module.url(forResource: "Vectors", withExtension: nil) else {
            fatalError("Vectors resource directory is missing from the test bundle")
        }
        return url
    }()

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(relativePath))
    }

    /// The elements of a vector file whose top level is a JSON array.
    static func cases(_ relativePath: String) throws -> [RawJSON] {
        let document = try RawJSON.parse(data(relativePath))
        guard case let .array(items) = document.node else {
            throw VectorError.unexpectedShape("\(relativePath): top level is not an array")
        }
        return items
    }

    /// The data lines of a syntax vector file: every line that is not empty
    /// and is not a `#` comment. Lines are not trimmed, because leading and
    /// trailing whitespace is exactly what some of them test.
    static func lines(_ relativePath: String) throws -> [String] {
        let text = try String(decoding: data(relativePath), as: UTF8.self)
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasPrefix("#") }
    }

    /// Names of the JSON files in a vector directory, sorted.
    static func jsonFiles(in relativeDirectory: String) throws -> [String] {
        let directory = root.appendingPathComponent(relativeDirectory)
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .map { relativeDirectory + "/" + $0 }
    }
}

enum VectorError: Error {
    case unexpectedShape(String)
    case malformed(String)
}

/// A JSON tree that remembers the exact source bytes of every value.
///
/// The vector files deliberately contain data the strict parser must reject
/// (floats, malformed `$link` objects…), and re-serializing a case through
/// Foundation would silently rewrite it (`123.0` becomes `123`). Slicing the
/// original bytes hands each case to the code under test untouched.
struct RawJSON {
    indirect enum Node {
        case object([(key: String, value: RawJSON)])
        case array([RawJSON])
        case scalar
    }

    let node: Node
    /// The value's source text, exactly as written in the file.
    let source: Data

    subscript(key: String) -> RawJSON? {
        guard case let .object(members) = node else { return nil }
        return members.first { $0.key == key }?.value
    }

    /// The value as a Swift string, for the `name` / `note` / `cid` fields.
    var string: String? {
        guard case .scalar = node, source.first == UInt8(ascii: "\"") else { return nil }
        return try? JSONDecoder().decode(String.self, from: source)
    }

    static func parse(_ data: Data) throws -> RawJSON {
        var scanner = Scanner(bytes: [UInt8](data))
        scanner.skipWhitespace()
        let value = try scanner.value()
        scanner.skipWhitespace()
        guard scanner.index == scanner.bytes.count else {
            throw VectorError.malformed("trailing content")
        }
        return value
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0

        mutating func skipWhitespace() {
            while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) {
                index += 1
            }
        }

        mutating func value() throws -> RawJSON {
            guard index < bytes.count else { throw VectorError.malformed("unexpected end") }
            let start = index
            switch bytes[index] {
            case UInt8(ascii: "{"):
                index += 1
                var members: [(key: String, value: RawJSON)] = []
                skipWhitespace()
                if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
                    index += 1
                } else {
                    while true {
                        skipWhitespace()
                        let keyStart = index
                        try skipString()
                        let key = try JSONDecoder().decode(String.self, from: Data(bytes[keyStart ..< index]))
                        skipWhitespace()
                        guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else {
                            throw VectorError.malformed("expected ':'")
                        }
                        index += 1
                        skipWhitespace()
                        try members.append((key, value()))
                        skipWhitespace()
                        guard index < bytes.count else { throw VectorError.malformed("unterminated object") }
                        if bytes[index] == UInt8(ascii: ",") {
                            index += 1
                            continue
                        }
                        guard bytes[index] == UInt8(ascii: "}") else { throw VectorError.malformed("expected '}'") }
                        index += 1
                        break
                    }
                }
                return RawJSON(node: .object(members), source: Data(bytes[start ..< index]))
            case UInt8(ascii: "["):
                index += 1
                var items: [RawJSON] = []
                skipWhitespace()
                if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
                    index += 1
                } else {
                    while true {
                        skipWhitespace()
                        try items.append(value())
                        skipWhitespace()
                        guard index < bytes.count else { throw VectorError.malformed("unterminated array") }
                        if bytes[index] == UInt8(ascii: ",") {
                            index += 1
                            continue
                        }
                        guard bytes[index] == UInt8(ascii: "]") else { throw VectorError.malformed("expected ']'") }
                        index += 1
                        break
                    }
                }
                return RawJSON(node: .array(items), source: Data(bytes[start ..< index]))
            case UInt8(ascii: "\""):
                try skipString()
                return RawJSON(node: .scalar, source: Data(bytes[start ..< index]))
            default:
                while index < bytes.count, ![0x20, 0x09, 0x0A, 0x0D, 0x2C, 0x5D, 0x7D].contains(bytes[index]) {
                    index += 1
                }
                guard index > start else { throw VectorError.malformed("unexpected byte") }
                return RawJSON(node: .scalar, source: Data(bytes[start ..< index]))
            }
        }

        mutating func skipString() throws {
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else {
                throw VectorError.malformed("expected a string")
            }
            index += 1
            while index < bytes.count {
                if bytes[index] == UInt8(ascii: "\\") {
                    index += 2
                    continue
                }
                if bytes[index] == UInt8(ascii: "\"") {
                    index += 1
                    return
                }
                index += 1
            }
            throw VectorError.malformed("unterminated string")
        }
    }
}

/// Standard base64 decoding through Foundation, independent of the decoder
/// under test, for the `cbor_base64` fixture field.
func foundationBase64(_ unpadded: String) -> Data? {
    let padding = String(repeating: "=", count: (4 - unpadded.utf8.count % 4) % 4)
    return Data(base64Encoded: unpadded + padding)
}
