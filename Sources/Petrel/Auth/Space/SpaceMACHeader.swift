import Foundation
import PetrelCrypto
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// RFC 9421 / RFC 9651 MAC request and response handling for Spaces.
enum SpaceMACHeader {
    enum Profile: String {
        case commit = "atproto-space-commit"
        case record = "atproto-space-record"

        var responseHeader: String {
            switch self {
            case .commit: "Atproto-Space-Commit"
            case .record: "Atproto-Space-Record"
            }
        }
    }

    static func request(profile: Profile, keyShare: String) -> String {
        let component = Item(
            bare: .string(profile.rawValue),
            parameters: [("sf", .boolean(true))]
        )
        let params: Parameters = [
            ("keyid", .string(keyShare)),
            ("tag", .string(profile.rawValue)),
        ]
        return "mac=\(serialize(.innerList([component], params)))"
    }

    static func verifyCommit(
        response: HTTPURLResponse,
        keyShare: String,
        sharedSecret: Data,
        space: SpaceRef,
        repo: String,
        revision: String,
        data: Data
    ) throws {
        let fields = try verify(
            profile: .commit,
            response: response,
            keyShare: keyShare,
            sharedSecret: sharedSecret
        )
        guard fields.bare("ver") == .integer(1),
              fields.bare("repo") == .string(repo),
              fields.bare("space") == .string(space.uriString()),
              fields.bare("rev") == .string(revision),
              fields.bare("data") == .bytes(data)
        else {
            throw SpaceVerificationError.invalidCommit
        }
    }

    static func verifyRecord(
        response: HTTPURLResponse,
        keyShare: String,
        sharedSecret: Data,
        uri: String,
        cid: CID
    ) throws {
        let fields = try verify(
            profile: .record,
            response: response,
            keyShare: keyShare,
            sharedSecret: sharedSecret
        )
        guard fields.bare("uri") == .string(uri),
              fields.bare("cid") == .string(cid.string)
        else {
            throw SpaceVerificationError.invalidRecord
        }
    }

    private static func verify(
        profile: Profile,
        response: HTTPURLResponse,
        keyShare: String,
        sharedSecret: Data
    ) throws -> Dictionary {
        let inputs = try parse(response.value(forHTTPHeaderField: "Signature-Input"))
        let signatures = try parse(response.value(forHTTPHeaderField: "Signature"))

        let tagged = inputs.members.compactMap { label, member -> (String, [Item], Parameters)? in
            guard case let .innerList(components, parameters) = member,
                  parameter("tag", in: parameters) == .string(profile.rawValue)
            else {
                return nil
            }
            return (label, components, parameters)
        }
        guard tagged.count == 1 else { throw SpaceVerificationError.malformedHeader }
        let (label, components, parameters) = tagged[0]
        guard components.count == 1,
              components[0].bare == .string(profile.rawValue),
              components[0].parameters.count == 1,
              components[0].parameters[0].0 == "sf",
              components[0].parameters[0].1 == .boolean(true)
        else {
            throw SpaceVerificationError.malformedHeader
        }
        if let algorithm = parameter("alg", in: parameters) {
            guard algorithm == .string("hmac-sha256") else {
                throw SpaceVerificationError.malformedHeader
            }
        }
        if let responseKey = parameter("keyid", in: parameters) {
            guard responseKey == .string(keyShare) else {
                throw SpaceVerificationError.malformedHeader
            }
        }

        guard case let .item(signatureItem)? = signatures.member(label),
              signatureItem.parameters.isEmpty,
              case let .bytes(authenticationCode) = signatureItem.bare
        else {
            throw SpaceVerificationError.malformedHeader
        }

        let fields = try parse(response.value(forHTTPHeaderField: profile.responseHeader))
        let signatureParams = serialize(.innerList(components, parameters))
        let base = Data(
            "\"\(profile.rawValue)\";sf: \(serialize(fields))\n\"@signature-params\": \(signatureParams)".utf8
        )
        try SpaceMAC.verify(
            authenticationCode: authenticationCode,
            message: base,
            sharedSecret: sharedSecret
        )
        return fields
    }

    private static func parse(_ header: String?) throws -> Dictionary {
        guard let header, header.utf8.count <= 8192 else {
            throw SpaceVerificationError.malformedHeader
        }
        do {
            var parser = Parser(bytes: Array(header.utf8))
            return try parser.dictionary()
        } catch let error as SpaceVerificationError {
            throw error
        } catch {
            throw SpaceVerificationError.malformedHeader
        }
    }

    private enum Bare: Equatable {
        case string(String)
        case integer(Int64)
        case bytes(Data)
        case boolean(Bool)
        case token(String)
    }

    private typealias Parameters = [(String, Bare)]

    private struct Item {
        let bare: Bare
        let parameters: Parameters
    }

    private enum Member {
        case item(Item)
        case innerList([Item], Parameters)
    }

    private struct Dictionary {
        let members: [(String, Member)]

        func member(_ key: String) -> Member? {
            members.first(where: { $0.0 == key })?.1
        }

        func bare(_ key: String) -> Bare? {
            guard case let .item(item)? = member(key) else { return nil }
            return item.bare
        }
    }

    private static func parameter(_ name: String, in parameters: Parameters) -> Bare? {
        parameters.first(where: { $0.0 == name })?.1
    }

    private static func serialize(_ dictionary: Dictionary) -> String {
        dictionary.members.map { key, member in
            if case let .item(item) = member, item.bare == .boolean(true) {
                return key + serialize(item.parameters)
            }
            return "\(key)=\(serialize(member))"
        }.joined(separator: ", ")
    }

    private static func serialize(_ member: Member) -> String {
        switch member {
        case let .item(item):
            return serialize(item)
        case let .innerList(items, parameters):
            return "(\(items.map(serialize).joined(separator: " ")))\(serialize(parameters))"
        }
    }

    private static func serialize(_ item: Item) -> String {
        serialize(item.bare) + serialize(item.parameters)
    }

    private static func serialize(_ parameters: Parameters) -> String {
        parameters.map { name, value in
            value == .boolean(true) ? ";\(name)" : ";\(name)=\(serialize(value))"
        }.joined()
    }

    private static func serialize(_ bare: Bare) -> String {
        switch bare {
        case let .string(value):
            return "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        case let .integer(value):
            return String(value)
        case let .bytes(value):
            return ":\(value.base64EncodedString()):"
        case let .boolean(value):
            return value ? "?1" : "?0"
        case let .token(value):
            return value
        }
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0

        var current: UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        mutating func dictionary() throws -> Dictionary {
            var members: [(String, Member)] = []
            whitespace()
            guard current != nil else { throw SpaceVerificationError.malformedHeader }
            while true {
                let name = try key()
                guard !members.contains(where: { $0.0 == name }) else {
                    throw SpaceVerificationError.malformedHeader
                }
                let parsedMember: Member
                if current == 61 {
                    index += 1
                    parsedMember = try member()
                } else {
                    parsedMember = try .item(Item(bare: .boolean(true), parameters: parameters()))
                }
                members.append((name, parsedMember))
                whitespace()
                guard current != nil else { break }
                try take(44)
                whitespace()
                guard current != nil else { throw SpaceVerificationError.malformedHeader }
            }
            return Dictionary(members: members)
        }

        mutating func member() throws -> Member {
            if current == 40 {
                index += 1
                var items: [Item] = []
                while true {
                    while current == 32 {
                        index += 1
                    }
                    if current == 41 {
                        index += 1
                        return try .innerList(items, parameters())
                    }
                    guard items.isEmpty || bytes[index - 1] == 32 else {
                        throw SpaceVerificationError.malformedHeader
                    }
                    try items.append(item())
                    guard current == 32 || current == 41 else {
                        throw SpaceVerificationError.malformedHeader
                    }
                }
            }
            return try .item(item())
        }

        mutating func item() throws -> Item {
            try Item(bare: bare(), parameters: parameters())
        }

        mutating func parameters() throws -> Parameters {
            var result: Parameters = []
            while current == 59 {
                index += 1
                let name = try key()
                guard !result.contains(where: { $0.0 == name }) else {
                    throw SpaceVerificationError.malformedHeader
                }
                let value: Bare
                if current == 61 {
                    index += 1
                    value = try bare()
                } else {
                    value = .boolean(true)
                }
                result.append((name, value))
            }
            return result
        }

        mutating func bare() throws -> Bare {
            guard let byte = current else { throw SpaceVerificationError.malformedHeader }
            switch byte {
            case 34:
                return try string()
            case 58:
                return try byteSequence()
            case 63:
                index += 1
                guard current == 48 || current == 49 else {
                    throw SpaceVerificationError.malformedHeader
                }
                defer { index += 1 }
                return .boolean(current == 49)
            case 45, 48 ... 57:
                return try integer()
            default:
                return try token()
            }
        }

        mutating func string() throws -> Bare {
            try take(34)
            var value: [UInt8] = []
            while let byte = current, byte != 34 {
                index += 1
                if byte == 92 {
                    guard let escaped = current, escaped == 34 || escaped == 92 else {
                        throw SpaceVerificationError.malformedHeader
                    }
                    value.append(escaped)
                    index += 1
                } else {
                    guard (32 ... 126).contains(byte) else {
                        throw SpaceVerificationError.malformedHeader
                    }
                    value.append(byte)
                }
            }
            try take(34)
            return .string(String(decoding: value, as: UTF8.self))
        }

        mutating func byteSequence() throws -> Bare {
            try take(58)
            let start = index
            while let byte = current, byte != 58 {
                guard (65 ... 90).contains(byte) ||
                    (97 ... 122).contains(byte) ||
                    (48 ... 57).contains(byte) ||
                    [43, 47, 61].contains(byte)
                else {
                    throw SpaceVerificationError.malformedHeader
                }
                index += 1
            }
            let encoded = String(decoding: bytes[start ..< index], as: UTF8.self)
            try take(58)
            guard let data = Data(base64Encoded: encoded) else {
                throw SpaceVerificationError.malformedHeader
            }
            return .bytes(data)
        }

        mutating func integer() throws -> Bare {
            let start = index
            if current == 45 {
                index += 1
            }
            let digits = index
            while let byte = current, (48 ... 57).contains(byte) {
                index += 1
            }
            guard index > digits, index - digits <= 15,
                  let value = Int64(String(decoding: bytes[start ..< index], as: UTF8.self))
            else {
                throw SpaceVerificationError.malformedHeader
            }
            return .integer(value)
        }

        mutating func token() throws -> Bare {
            let start = index
            guard let byte = current,
                  byte == 42 || (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
            else {
                throw SpaceVerificationError.malformedHeader
            }
            index += 1
            let punctuation = Array("!#$%&'*+-.^_`|~:/".utf8)
            while let byte = current,
                  (65 ... 90).contains(byte) ||
                  (97 ... 122).contains(byte) ||
                  (48 ... 57).contains(byte) ||
                  punctuation.contains(byte)
            {
                index += 1
            }
            return .token(String(decoding: bytes[start ..< index], as: UTF8.self))
        }

        mutating func key() throws -> String {
            let start = index
            guard let byte = current,
                  byte == 42 || (97 ... 122).contains(byte)
            else {
                throw SpaceVerificationError.malformedHeader
            }
            index += 1
            while let byte = current,
                  (97 ... 122).contains(byte) ||
                  (48 ... 57).contains(byte) ||
                  [95, 45, 46, 42].contains(byte)
            {
                index += 1
            }
            return String(decoding: bytes[start ..< index], as: UTF8.self)
        }

        mutating func whitespace() {
            while current == 32 || current == 9 {
                index += 1
            }
        }

        mutating func take(_ byte: UInt8) throws {
            guard current == byte else { throw SpaceVerificationError.malformedHeader }
            index += 1
        }
    }
}
