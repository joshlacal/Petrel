import Crypto
import Foundation
import PetrelCore
import PetrelCrypto

public struct PLCService: Codable, Sendable, Equatable {
    public let type: String
    public let endpoint: String

    public init(type: String, endpoint: String) {
        self.type = type
        self.endpoint = endpoint
    }
}

public struct PLCUnsignedRegularOperation: Sendable, Equatable {
    public let rotationKeys: [String]
    public let verificationMethods: [String: String]
    public let alsoKnownAs: [String]
    public let services: [String: PLCService]
    public let prev: String?

    public init(
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService],
        prev: String?
    ) throws {
        self.rotationKeys = rotationKeys
        self.verificationMethods = verificationMethods
        self.alsoKnownAs = alsoKnownAs
        self.services = services
        self.prev = prev
        try PLCOperationCodec.validate(self)
    }
}

public struct PLCUnsignedTombstoneOperation: Sendable, Equatable {
    public let prev: String

    public init(prev: String) throws {
        try PLCOperationCodec.validatePreviousCID(prev)
        self.prev = prev
    }
}

public enum PLCUnsignedOperation: Sendable, Equatable {
    case regular(PLCUnsignedRegularOperation)
    case tombstone(PLCUnsignedTombstoneOperation)
}

public struct PLCSignedRegularOperation: Sendable, Equatable {
    public let rotationKeys: [String]
    public let verificationMethods: [String: String]
    public let alsoKnownAs: [String]
    public let services: [String: PLCService]
    public let prev: String?
    public let signature: String

    fileprivate var unsigned: PLCUnsignedRegularOperation {
        get throws {
            try .init(
                rotationKeys: rotationKeys,
                verificationMethods: verificationMethods,
                alsoKnownAs: alsoKnownAs,
                services: services,
                prev: prev
            )
        }
    }
}

public struct PLCSignedTombstoneOperation: Sendable, Equatable {
    public let prev: String
    public let signature: String

    fileprivate var unsigned: PLCUnsignedTombstoneOperation {
        get throws { try .init(prev: prev) }
    }
}

public enum PLCSignedOperation: Sendable, Equatable {
    case regularOperation(PLCSignedRegularOperation)
    case tombstoneOperation(PLCSignedTombstoneOperation)

    public var regular: PLCSignedRegularOperation? {
        guard case let .regularOperation(operation) = self else { return nil }
        return operation
    }

    public var prev: String? {
        switch self {
        case let .regularOperation(operation): operation.prev
        case let .tombstoneOperation(operation): operation.prev
        }
    }

    public var signingDAGCBOR: Data {
        get throws {
            switch self {
            case let .regularOperation(operation):
                try PLCOperationCodec.encodeSigningBytes(.regular(operation.unsigned))
            case let .tombstoneOperation(operation):
                try PLCOperationCodec.encodeSigningBytes(.tombstone(operation.unsigned))
            }
        }
    }

    public var canonicalDAGCBOR: Data {
        get throws { try PLCOperationCodec.encodeSigned(self) }
    }

    public var canonicalJSON: Data {
        get throws { try PLCOperationCodec.encodeSignedJSON(self) }
    }

    public var cid: CID {
        get throws { CID.fromDAGCBOR(try canonicalDAGCBOR) }
    }
}

public enum PLCATProfile {
    public static func regularOperation(
        handle: String,
        signingPublicKey: P256.Signing.PublicKey,
        rotationPublicKeys: [P256.Signing.PublicKey],
        pdsOrigin: URL,
        prev: String?
    ) throws -> PLCUnsignedRegularOperation {
        let canonicalHandle = try AccountIdentifiers.canonicalHandle(handle)
        let origin = try canonicalPDSOrigin(pdsOrigin)
        return try PLCUnsignedRegularOperation(
            rotationKeys: rotationPublicKeys.map { P256DIDKey(publicKey: $0).value },
            verificationMethods: ["atproto": P256DIDKey(publicKey: signingPublicKey).value],
            alsoKnownAs: ["at://\(canonicalHandle)"],
            services: [
                "atproto_pds": .init(
                    type: "AtprotoPersonalDataServer",
                    endpoint: origin
                ),
            ],
            prev: prev
        )
    }

    /// Validates and canonicalizes the PDS service origin carried by a PLC
    /// operation. Exposed so operator surfaces can reject malformed input
    /// before opening durable storage or creating key envelopes.
    public static func canonicalPDSOrigin(_ url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw PetrelPLCError.malformed("PLC PDS endpoint must be an origin")
        }
        let isLiteralLoopback = scheme == "http" && isLoopbackLiteral(host)
        guard scheme == "https" || isLiteralLoopback else {
            throw PetrelPLCError.malformed("PLC PDS endpoint must use HTTPS")
        }
        if scheme == "https", components.port != nil, components.port != 443 {
            throw PetrelPLCError.malformed("PLC PDS endpoint port is invalid")
        }
        if isLiteralLoopback {
            guard let port = components.port, (1 ... 65_535).contains(port) else {
                throw PetrelPLCError.malformed("PLC lab PDS endpoint requires an explicit port")
            }
        }
        var normalized = components
        normalized.path = ""
        guard let value = normalized.url?.absoluteString, !value.hasSuffix("/") else {
            throw PetrelPLCError.malformed("PLC PDS endpoint is malformed")
        }
        return value
    }
}

public enum PLCOperationCodec {
    public static let maximumDAGCBORBytes = 7_500

    /// Reconstructs the one regular `prev: null` operation shape persisted by
    /// account preparation. Validation here is the same Task 13 codec path
    /// used for decoded and freshly signed PLC operations.
    public static func reconstructGenesis(
        signingDIDKey: String,
        rotationDIDKey: String,
        canonicalHandle: String,
        pdsOrigin: String,
        signature: String
    ) throws -> PLCSignedOperation {
        let unsigned = try PLCUnsignedRegularOperation(
            rotationKeys: [rotationDIDKey],
            verificationMethods: ["atproto": signingDIDKey],
            alsoKnownAs: ["at://\(canonicalHandle)"],
            services: [
                "atproto_pds": PLCService(
                    type: "AtprotoPersonalDataServer",
                    endpoint: pdsOrigin
                ),
            ],
            prev: nil
        )
        let operation = PLCSignedOperation.regularOperation(.init(
            rotationKeys: unsigned.rotationKeys,
            verificationMethods: unsigned.verificationMethods,
            alsoKnownAs: unsigned.alsoKnownAs,
            services: unsigned.services,
            prev: nil,
            signature: signature
        ))
        try validateSigned(operation)
        return operation
    }

    public static func sign(
        _ operation: PLCUnsignedOperation,
        using key: P256.Signing.PrivateKey
    ) throws -> PLCSignedOperation {
        let signingBytes = try encodeSigningBytes(operation)
        let signature = try P256WireSignature.sign(signingBytes, using: key)
        let encoded = signature.plcBase64URL
        let signed: PLCSignedOperation
        switch operation {
        case let .regular(value):
            signed = .regularOperation(.init(
                rotationKeys: value.rotationKeys,
                verificationMethods: value.verificationMethods,
                alsoKnownAs: value.alsoKnownAs,
                services: value.services,
                prev: value.prev,
                signature: encoded
            ))
        case let .tombstone(value):
            signed = .tombstoneOperation(.init(prev: value.prev, signature: encoded))
        }
        try validateSigned(signed)
        return signed
    }

    public static func genesisDID(for operation: PLCSignedOperation) throws -> String {
        guard operation.prev == nil, operation.regular != nil else {
            throw PetrelPLCError.malformed("PLC genesis must be a regular operation with null prev")
        }
        let digest = Data(SHA256.hash(data: try operation.canonicalDAGCBOR))
        return "did:plc:" + String(base32Encode(digest).prefix(24))
    }

    public static func verifyGenesis(
        _ operation: PLCSignedOperation,
        expectedDID: String
    ) throws {
        try validateCanonicalDID(expectedDID)
        guard try genesisDID(for: operation) == expectedDID,
              let regular = operation.regular else {
            throw PetrelPLCError.unauthorized("PLC genesis DID does not match operation")
        }
        _ = try verify(operation, authorizedRotationKeys: regular.rotationKeys)
    }

    public static func verify(
        _ operation: PLCSignedOperation,
        authorizedRotationKeys: [String]
    ) throws -> Int {
        try validateSigned(operation)
        guard Set(authorizedRotationKeys).count == authorizedRotationKeys.count,
              !authorizedRotationKeys.isEmpty,
              authorizedRotationKeys.count <= 5 else {
            throw PetrelPLCError.malformed("PLC authorized rotation keys are invalid")
        }
        let signatureText: String
        switch operation {
        case let .regularOperation(value): signatureText = value.signature
        case let .tombstoneOperation(value): signatureText = value.signature
        }
        let signatureBytes = try decodeCanonicalSignature(signatureText)
        let signingBytes = try operation.signingDAGCBOR
        for (index, keyText) in authorizedRotationKeys.enumerated() {
            let key = try PLCDIDKeyCodec.decode(keyText)
            switch key {
            case let .p256(p256Key):
                let signature = try P256WireSignature.decodeCanonical(signatureBytes)
                if p256Key.isValidSignature(signature, for: signingBytes) {
                    return index
                }
            case .secp256k1:
                guard ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(signatureBytes) else {
                    throw PetrelPLCError.unauthorized("PLC operation signature is not low-S")
                }
                if (try? key.verify(signature: signatureBytes, signingInput: signingBytes, algorithm: "ES256K")) == true {
                    return index
                }
            }
        }
        throw PetrelPLCError.unauthorized("PLC operation signature is invalid")
    }

    public static func decodeSignedJSON(_ data: Data) throws -> PLCSignedOperation {
        guard !data.isEmpty, data.count <= 32 * 1_024 else {
            throw PetrelPLCError.malformed("PLC operation JSON exceeds its bound")
        }
        try StrictJSON.validate(data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            throw PetrelPLCError.malformed("PLC operation JSON is malformed")
        }
        let operation: PLCSignedOperation
        switch type {
        case "plc_operation":
            let expected = Set([
                "type", "rotationKeys", "verificationMethods", "alsoKnownAs",
                "services", "prev", "sig",
            ])
            guard Set(object.keys) == expected,
                  let rotationKeys = object["rotationKeys"] as? [String],
                  let verificationMethods = object["verificationMethods"] as? [String: String],
                  let alsoKnownAs = object["alsoKnownAs"] as? [String],
                  let rawServices = object["services"] as? [String: Any],
                  let signature = object["sig"] as? String else {
                throw PetrelPLCError.malformed("PLC regular operation JSON is malformed")
            }
            let prev: String?
            if object["prev"] is NSNull {
                prev = nil
            } else if let value = object["prev"] as? String {
                prev = value
            } else {
                throw PetrelPLCError.malformed("PLC operation prev is malformed")
            }
            var services = [String: PLCService]()
            for (name, rawService) in rawServices {
                guard let service = rawService as? [String: Any],
                      Set(service.keys) == ["type", "endpoint"],
                      let serviceType = service["type"] as? String,
                      let endpoint = service["endpoint"] as? String else {
                    throw PetrelPLCError.malformed("PLC operation service is malformed")
                }
                services[name] = .init(type: serviceType, endpoint: endpoint)
            }
            let unsigned = try PLCUnsignedRegularOperation(
                rotationKeys: rotationKeys,
                verificationMethods: verificationMethods,
                alsoKnownAs: alsoKnownAs,
                services: services,
                prev: prev
            )
            operation = .regularOperation(.init(
                rotationKeys: unsigned.rotationKeys,
                verificationMethods: unsigned.verificationMethods,
                alsoKnownAs: unsigned.alsoKnownAs,
                services: unsigned.services,
                prev: unsigned.prev,
                signature: signature
            ))
        case "plc_tombstone":
            guard Set(object.keys) == ["type", "prev", "sig"],
                  let prev = object["prev"] as? String,
                  let signature = object["sig"] as? String else {
                throw PetrelPLCError.malformed("PLC tombstone JSON is malformed")
            }
            _ = try PLCUnsignedTombstoneOperation(prev: prev)
            operation = .tombstoneOperation(.init(prev: prev, signature: signature))
        default:
            throw PetrelPLCError.malformed("PLC operation type is unsupported")
        }
        try validateSigned(operation)
        return operation
    }

    fileprivate static func validate(_ operation: PLCUnsignedRegularOperation) throws {
        guard (1 ... 5).contains(operation.rotationKeys.count),
              Set(operation.rotationKeys).count == operation.rotationKeys.count else {
            throw PetrelPLCError.malformed("PLC operation must contain 1...5 unique rotation keys")
        }
        try operation.rotationKeys.forEach { _ = try PLCDIDKeyCodec.decode($0) }
        guard !operation.verificationMethods.isEmpty,
              operation.verificationMethods.count <= 32,
              operation.alsoKnownAs.count <= 32,
              operation.services.count <= 32 else {
            throw PetrelPLCError.malformed("PLC operation map or array bound is invalid")
        }
        for (name, value) in operation.verificationMethods {
            try validateMapName(name)
            _ = try PLCDIDKeyCodec.decode(value)
        }
        for alias in operation.alsoKnownAs {
            try validateWireString(alias, field: "alsoKnownAs")
        }
        for (name, service) in operation.services {
            try validateMapName(name)
            try validateWireString(service.type, field: "service type")
            try validateWireString(service.endpoint, field: "service endpoint")
        }
        if let prev = operation.prev {
            try validatePreviousCID(prev)
        }
        guard try encodeSigningBytes(.regular(operation)).count <= maximumDAGCBORBytes else {
            throw PetrelPLCError.malformed("PLC operation exceeds 7,500 DAG-CBOR bytes")
        }
    }

    fileprivate static func validatePreviousCID(_ value: String) throws {
        do {
            let cid = try CID.parse(value)
            guard cid.string == value,
                  cid.codec == .dagCBOR,
                  cid.multihash.algorithm == Multihash.sha256Code,
                  cid.multihash.length == Multihash.sha256Length,
                  cid.multihash.digest.count == Int(Multihash.sha256Length) else {
                throw PetrelPLCError.invalidIdentifier("PLC previous operation CID")
            }
        } catch let error as PetrelPLCError {
            throw error
        } catch {
            throw PetrelPLCError.invalidIdentifier("PLC previous operation CID")
        }
    }

    fileprivate static func encodeSigningBytes(_ operation: PLCUnsignedOperation) throws -> Data {
        switch operation {
        case let .regular(value):
            return try DAGCBOR.encodeValue(regularMap(value, signature: nil))
        case let .tombstone(value):
            return try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
                (key: "type", value: "plc_tombstone"),
                (key: "prev", value: value.prev),
            ]))
        }
    }

    fileprivate static func encodeSigned(_ operation: PLCSignedOperation) throws -> Data {
        switch operation {
        case let .regularOperation(value):
            return try DAGCBOR.encodeValue(regularMap(try value.unsigned, signature: value.signature))
        case let .tombstoneOperation(value):
            return try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
                (key: "type", value: "plc_tombstone"),
                (key: "prev", value: value.prev),
                (key: "sig", value: value.signature),
            ]))
        }
    }

    fileprivate static func encodeSignedJSON(_ operation: PLCSignedOperation) throws -> Data {
        let object: [String: Any]
        switch operation {
        case let .regularOperation(value):
            object = regularJSONObject(value)
        case let .tombstoneOperation(value):
            object = [
                "type": "plc_tombstone",
                "prev": value.prev,
                "sig": value.signature,
            ]
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func validateCanonicalDID(_ did: String) throws {
        guard did.utf8.count == 32,
              did.hasPrefix("did:plc:"),
              did.dropFirst(8).utf8.allSatisfy({
                  ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z")) ||
                      ($0 >= UInt8(ascii: "2") && $0 <= UInt8(ascii: "7"))
              }) else {
            throw PetrelPLCError.invalidIdentifier("canonical did:plc")
        }
    }

    private static func validateSigned(_ operation: PLCSignedOperation) throws {
        let signature: String
        let rotationKeys: [String]?
        switch operation {
        case let .regularOperation(value):
            _ = try value.unsigned
            signature = value.signature
            rotationKeys = value.rotationKeys
        case let .tombstoneOperation(value):
            _ = try value.unsigned
            signature = value.signature
            rotationKeys = nil
        }
        let signatureBytes = try decodeCanonicalSignature(signature)
        if let rotationKeys {
            guard rotationKeys.contains(where: {
                guard let key = try? PLCDIDKeyCodec.decode($0) else { return false }
                switch key {
                case .p256:
                    return (try? P256WireSignature.decodeCanonical(signatureBytes)) != nil
                case .secp256k1:
                    return ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(signatureBytes)
                }
            }) else {
                throw PetrelPLCError.malformed("PLC operation signature is not canonical")
            }
        }
        guard try encodeSigned(operation).count <= maximumDAGCBORBytes else {
            throw PetrelPLCError.malformed("PLC operation exceeds 7,500 DAG-CBOR bytes")
        }
    }

    private static func decodeCanonicalSignature(_ value: String) throws -> Data {
        guard let decoded = Data(plcBase64URL: value),
              decoded.count == P256WireSignature.rawByteCount,
              decoded.plcBase64URL == value else {
            throw PetrelPLCError.malformed("PLC operation signature encoding is invalid")
        }
        return decoded
    }

    private static func regularMap(
        _ operation: PLCUnsignedRegularOperation,
        signature: String?
    ) -> OrderedCBORMap {
        let serviceValues: [String: Any] = operation.services.mapValues { service in
            OrderedCBORMap(entries: [
                (key: "type", value: service.type),
                (key: "endpoint", value: service.endpoint),
            ])
        }
        var entries: [(key: String, value: Any)] = [
            (key: "type", value: "plc_operation"),
            (key: "rotationKeys", value: operation.rotationKeys),
            (key: "verificationMethods", value: operation.verificationMethods),
            (key: "alsoKnownAs", value: operation.alsoKnownAs),
            (key: "services", value: serviceValues),
            (key: "prev", value: operation.prev ?? NSNull()),
        ]
        if let signature {
            entries.append((key: "sig", value: signature))
        }
        return OrderedCBORMap(entries: entries)
    }

    private static func regularJSONObject(_ operation: PLCSignedRegularOperation) -> [String: Any] {
        [
            "type": "plc_operation",
            "rotationKeys": operation.rotationKeys,
            "verificationMethods": operation.verificationMethods,
            "alsoKnownAs": operation.alsoKnownAs,
            "services": operation.services.mapValues { [
                "type": $0.type,
                "endpoint": $0.endpoint,
            ] },
            "prev": operation.prev ?? NSNull(),
            "sig": operation.signature,
        ]
    }

    private static func validateMapName(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 128,
              value.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw PetrelPLCError.malformed("PLC operation map key is invalid")
        }
    }

    private static func validateWireString(_ value: String, field: String) throws {
        guard !value.isEmpty, value.utf8.count <= 2_048,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw PetrelPLCError.malformed("PLC operation \(field) is invalid")
        }
    }
}

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
            while index < bytes.count {
                let byte = bytes[index]
                if byte == UInt8(ascii: "\""), !escaped {
                    let range = start ..< index
                    index += 1
                    guard let raw = String(bytes: bytes[range], encoding: .utf8),
                          let quoted = "\"\(raw)\"".data(using: .utf8),
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

private func isLoopbackLiteral(_ host: String) -> Bool {
    let canonical = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    if canonical == "::1" { return true }
    let parts = canonical.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4,
          let first = UInt8(parts[0]),
          parts.allSatisfy({ part in
              guard let value = UInt8(part) else { return false }
              return String(value) == part
          }) else {
        return false
    }
    return first == 127
}

private extension Data {
    init?(plcBase64URL value: String) {
        guard !value.isEmpty,
              !value.contains("="),
              value.utf8.allSatisfy({
                  ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z")) ||
                      ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z")) ||
                      ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) ||
                      $0 == UInt8(ascii: "-") || $0 == UInt8(ascii: "_")
              }) else {
            return nil
        }
        var padded = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        padded.append(String(repeating: "=", count: (4 - padded.count % 4) % 4))
        self.init(base64Encoded: padded)
    }

    var plcBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
