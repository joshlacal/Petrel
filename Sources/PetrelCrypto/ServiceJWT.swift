import Crypto
import Foundation
@preconcurrency import secp256k1

/// Standard ATProto inter-service authentication claims.
public struct ServiceJWTClaims: Codable, Sendable, Equatable {
    public let iss: String
    public let aud: String
    public let iat: Int64?
    public let exp: Int64
    public let lxm: String?
    public let jti: String?

    enum CodingKeys: String, CodingKey {
        case iss, aud, iat, exp, lxm, jti
    }

    public init(
        iss: String,
        aud: String,
        iat: Int64? = nil,
        exp: Int64,
        lxm: String? = nil,
        jti: String? = nil
    ) {
        self.iss = iss
        self.aud = aud
        self.iat = iat
        self.exp = exp
        self.lxm = lxm
        self.jti = jti
    }
}

/// Inspection result for an unverified compact service JWT.
public struct ServiceJWTInspection: Sendable, Equatable {
    public let issuer: String
    public let algorithm: String
    public let claims: ServiceJWTClaims

    public init(issuer: String, algorithm: String, claims: ServiceJWTClaims) {
        self.issuer = issuer
        self.algorithm = algorithm
        self.claims = claims
    }
}

/// Supported signing private keys for minting ATProto service JWTs.
public enum ServiceJWTSigningKey: @unchecked Sendable {
    case p256(P256.Signing.PrivateKey)
    case secp256k1(secp256k1.Signing.PrivateKey)
}

/// ATProto inter-service JWT minting, inspection, and verification.
///
/// Supports both ES256 (P-256) and ES256K (secp256k1) algorithms, with
/// low-S canonical signature normalization/enforcement and strict claim validation.
public enum ServiceJWT {
    public typealias Claims = ServiceJWTClaims
    public typealias Inspection = ServiceJWTInspection
    public typealias SigningKey = ServiceJWTSigningKey

    public static let maximumCompactBytes = 32 * 1024
    public static let defaultLifetime: TimeInterval = 60
    public static let maximumLifetime: TimeInterval = 60

    private struct Header: Codable, Sendable {
        let alg: String
        let typ: String?
        let kid: String?
        let crit: [String]?
        let b64: Bool?

        init(alg: String, typ: String? = "JWT", kid: String? = nil, crit: [String]? = nil, b64: Bool? = nil) {
            self.alg = alg
            self.typ = typ
            self.kid = kid
            self.crit = crit
            self.b64 = b64
        }
    }

    private struct Parsed: Sendable {
        let header: Header
        let claims: Claims
        let signingInput: Data
        let signature: Data
    }

    /// Mints a service JWT bound to the given issuer, audience, method (lxm),
    /// and eventID (jti) using the provided signing key (P-256 for ES256 or secp256k1 for ES256K).
    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: ServiceJWTSigningKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        guard isValidDID(issuer),
              isPrintable(audience, maximumBytes: 4096),
              isValidNSID(method),
              isPrintable(eventID, maximumBytes: 256),
              lifetime > 0, lifetime <= maximumLifetime,
              lifetime.rounded(.towardZero) == lifetime,
              now.timeIntervalSince1970.isFinite else {
            throw PetrelCryptoError.malformed("service authentication claims are invalid")
        }
        guard let iat = integerServiceTimestamp(now) else {
            throw PetrelCryptoError.malformed("service authentication current time is invalid")
        }
        let (exp, overflow) = iat.addingReportingOverflow(Int64(lifetime))
        guard !overflow else {
            throw PetrelCryptoError.malformed("service authentication expiry is invalid")
        }

        let alg: String
        switch key {
        case .p256: alg = "ES256"
        case .secp256k1: alg = "ES256K"
        }

        let claims = Claims(
            iss: issuer,
            aud: audience,
            iat: iat,
            exp: exp,
            lxm: method,
            jti: eventID
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let headerData = try encoder.encode(Header(alg: alg, typ: "JWT"))
        let claimsData = try encoder.encode(claims)

        let headerPart = JWTBase64URL.encode(headerData)
        let payloadPart = JWTBase64URL.encode(claimsData)
        let signingInput = "\(headerPart).\(payloadPart)"
        let signingInputData = Data(signingInput.utf8)

        let signatureData: Data
        switch key {
        case let .p256(p256Key):
            signatureData = try P256WireSignature.sign(signingInputData, using: p256Key)
        case let .secp256k1(secpKey):
            let ecdsaSig = try secpKey.signature(for: signingInputData)
            let compact = try ecdsaSig.compactRepresentation
            guard ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(compact) else {
                throw PetrelCryptoError.malformed("secp256k1 signature is not canonical low-S")
            }
            signatureData = compact
        }

        return "\(signingInput).\(JWTBase64URL.encode(signatureData))"
    }

    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: secp256k1.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .secp256k1(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: secp256k1.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .secp256k1(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func inspect(_ compact: String) throws -> Inspection {
        let parsed = try parse(compact)
        try validateShape(parsed.header, claims: parsed.claims)
        return Inspection(
            issuer: parsed.claims.iss,
            algorithm: parsed.header.alg,
            claims: parsed.claims
        )
    }

    public static func verify(
        _ compact: String,
        publicKey: ATProtoJWTVerificationKey,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        guard clockSkew >= 0, clockSkew <= 5 * 60,
              maximumLifetime > 0, maximumLifetime <= 10 * 60,
              clockSkew.isFinite, maximumLifetime.isFinite else {
            throw PetrelCryptoError.malformed("service authentication time policy is invalid")
        }
        let parsed = try parse(compact)
        try validateShape(parsed.header, claims: parsed.claims)
        guard try publicKey.verify(
            signature: parsed.signature,
            signingInput: parsed.signingInput,
            algorithm: parsed.header.alg
        ) else {
            throw PetrelCryptoError.unauthorized("service authentication signature is invalid")
        }
        guard let nowSeconds = integerServiceTimestamp(now) else {
            throw PetrelCryptoError.malformed("service authentication current time is invalid")
        }
        let skew = Int64(clockSkew)
        let expirationCutoff = nowSeconds.subtractingReportingOverflow(skew)
        guard !expirationCutoff.overflow else {
            throw PetrelCryptoError.malformed("service authentication time policy is invalid")
        }
        guard parsed.claims.exp >= expirationCutoff.partialValue else {
            throw PetrelCryptoError.expired
        }
        let latestIssuedAt = nowSeconds.addingReportingOverflow(skew)
        let latestExpiration = latestIssuedAt.partialValue
            .addingReportingOverflow(Int64(maximumLifetime))
        guard !latestIssuedAt.overflow,
              !latestExpiration.overflow,
              parsed.claims.exp <= latestExpiration.partialValue else {
            throw PetrelCryptoError.unauthorized("service authentication time claims are invalid")
        }
        if let issuedAt = parsed.claims.iat {
            let lifetime = parsed.claims.exp.subtractingReportingOverflow(issuedAt)
            guard issuedAt <= latestIssuedAt.partialValue,
                  parsed.claims.exp >= issuedAt,
                  !lifetime.overflow,
                  lifetime.partialValue <= Int64(maximumLifetime) else {
                throw PetrelCryptoError.unauthorized("service authentication time claims are invalid")
            }
        }
        return parsed.claims
    }

    public static func verify(
        _ compact: String,
        publicKey: PLCDIDVerificationKey,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        try verify(
            compact,
            publicKey: ATProtoJWTVerificationKey(publicKey),
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    public static func verify(
        _ compact: String,
        didKey: String,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        let key = try PLCDIDKeyCodec.decode(didKey)
        return try verify(
            compact,
            publicKey: key,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    private static func integerServiceTimestamp(_ date: Date) -> Int64? {
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite,
              timestamp >= Double(Int64.min),
              timestamp < Double(Int64.max) else {
            return nil
        }
        return Int64(timestamp)
    }

    private static func parse(_ compact: String) throws -> Parsed {
        guard !compact.isEmpty, compact.utf8.count <= maximumCompactBytes else {
            throw PetrelCryptoError.malformed("service authentication token is invalid")
        }
        let pieces = compact.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3,
              pieces.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 16 * 1024 }),
              let headerData = try? JWTBase64URL.decode(String(pieces[0]), maxBytes: 4 * 1024),
              let payload = try? JWTBase64URL.decode(String(pieces[1]), maxBytes: 16 * 1024),
              let signature = try? JWTBase64URL.decode(String(pieces[2]), maxBytes: 64),
              signature.count == 64 else {
            throw PetrelCryptoError.malformed("service authentication token is invalid")
        }
        let header = try StrictJSON.decode(Header.self, from: headerData)
        let claims = try StrictJSON.decode(Claims.self, from: payload)
        return Parsed(
            header: header,
            claims: claims,
            signingInput: Data("\(pieces[0]).\(pieces[1])".utf8),
            signature: signature
        )
    }

    private static func validateShape(_ header: Header, claims: Claims) throws {
        guard header.crit == nil, header.b64 == nil,
              header.alg == "ES256" || header.alg == "ES256K",
              !["at+jwt", "refresh+jwt", "dpop+jwt"].contains(header.typ?.lowercased() ?? ""),
              serviceIssuerDID(claims.iss) != nil,
              validServiceAudience(claims.aud),
              validServiceMethod(claims.lxm ?? ""),
              validServiceEventID(claims.jti ?? "") else {
            throw PetrelCryptoError.unauthorized("service authentication token is invalid")
        }
    }

    public static func isNSID(_ value: String) -> Bool { isValidNSID(value) }

    private static func serviceIssuerDID(_ value: String) -> String? {
        let parts = value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard (1 ... 2).contains(parts.count),
              !parts[0].isEmpty,
              (parts.count == 1 || (!parts[1].isEmpty && parts[1].utf8.count <= 512)),
              isValidDID(String(parts[0])) else {
            return nil
        }
        return String(parts[0])
    }

    private static func validServiceAudience(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 4_096 && value.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7e }
    }

    private static func validServiceMethod(_ value: String) -> Bool {
        value.isEmpty || isValidNSID(value)
    }

    private static func validServiceEventID(_ value: String) -> Bool {
        value.isEmpty || (!value.isEmpty && value.utf8.count <= 256 && value.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7e })
    }

    private static func isPrintable(_ value: String, maximumBytes: Int) -> Bool {
        !value.isEmpty && value.utf8.count <= maximumBytes
            && value.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7E }
    }

    private static func isValidDID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count <= 2_048,
              bytes.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            return false
        }
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count >= 3, components[0] == "did" else {
            return false
        }

        switch components[1] {
        case "plc":
            return components.count == 3
                && components[2].utf8.count == 24
                && components[2].utf8.allSatisfy {
                    ($0 >= 97 && $0 <= 122) || ($0 >= 50 && $0 <= 55)
                }
        case "web":
            return validateWebDIDComponents(components)
        case "key":
            return (try? PLCDIDKeyCodec.decode(value)) != nil
        default:
            return components.allSatisfy { segment in
                !segment.isEmpty && segment.utf8.allSatisfy {
                    ($0 >= 97 && $0 <= 122) || ($0 >= 65 && $0 <= 90) || ($0 >= 48 && $0 <= 57) || $0 == 45 || $0 == 46 || $0 == 95
                }
            }
        }
    }

    private static func validateWebDIDComponents(_ components: [Substring]) -> Bool {
        let authority = String(components[2])
        let authorityParts = authority.components(separatedBy: "%3A")
        guard (1 ... 2).contains(authorityParts.count),
              !authorityParts[0].contains("%") else {
            return false
        }
        guard validateCanonicalDNSName(authorityParts[0]) else {
            return false
        }
        if authorityParts.count == 2 {
            let port = authorityParts[1]
            guard !port.isEmpty, !port.contains("%"),
                  port.count == 1 || port.first != "0",
                  let value = UInt16(port), value > 0 else {
                return false
            }
        }

        for component in components.dropFirst(3) {
            guard !component.isEmpty, component != ".", component != ".." else {
                return false
            }
            guard validateCanonicalWebPathSegment(component) else {
                return false
            }
        }
        return true
    }

    private static func validateCanonicalDNSName(_ name: String) -> Bool {
        guard name.utf8.count <= 253,
              name.utf8.allSatisfy({
                  ($0 >= 97 && $0 <= 122)
                      || ($0 >= 48 && $0 <= 57)
                      || $0 == 45
                      || $0 == 46
              }) else {
            return false
        }
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({
                  !$0.isEmpty
                      && $0.utf8.count <= 63
                      && $0.first != "-"
                      && $0.last != "-"
              }),
              labels.last?.allSatisfy(\.isNumber) == false else {
            return false
        }
        return true
    }

    private static func validateCanonicalWebPathSegment(_ segment: Substring) -> Bool {
        let bytes = Array(segment.utf8)
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x25 {
                guard index + 2 < bytes.count,
                      isUppercaseHex(bytes[index + 1]),
                      isUppercaseHex(bytes[index + 2]),
                      let decoded = decodedHex(bytes[index + 1], bytes[index + 2]),
                      !isUnreserved(decoded) else {
                    return false
                }
                index += 3
            } else {
                guard isUnreserved(bytes[index]) else {
                    return false
                }
                index += 1
            }
        }
        return true
    }

    private static func isUnreserved(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90)
            || (byte >= 97 && byte <= 122)
            || (byte >= 48 && byte <= 57)
            || byte == 45
            || byte == 46
            || byte == 95
            || byte == 126
    }

    private static func isUppercaseHex(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 70)
    }

    private static func decodedHex(_ first: UInt8, _ second: UInt8) -> UInt8? {
        guard let high = hexValue(first), let low = hexValue(second) else { return nil }
        return high * 16 + low
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        if byte >= 48, byte <= 57 { return byte - 48 }
        if byte >= 65, byte <= 70 { return byte - 55 }
        return nil
    }

    private static func isValidNSID(_ value: String) -> Bool {
        guard value.utf8.count <= 317 else { return false }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 3 else { return false }
        return segments.allSatisfy { segment in
            !segment.isEmpty
                && segment.utf8.allSatisfy {
                    ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z"))
                        || ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z"))
                        || ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9"))
                        || $0 == UInt8(ascii: "-")
                }
        }
    }
}

/// Backward compatibility / Swan compatibility types
public enum ProxyServiceJWT {
    public static let maximumLifetime: TimeInterval = ServiceJWT.maximumLifetime

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = maximumLifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: secp256k1.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = maximumLifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .secp256k1(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func isNSID(_ value: String) -> Bool {
        ServiceJWT.isNSID(value)
    }
}

public enum SpaceServiceJWT {
    public typealias Claims = ServiceJWTClaims
    public typealias Inspection = ServiceJWTInspection

    public static let maximumCompactBytes = ServiceJWT.maximumCompactBytes
    public static let lifetime: TimeInterval = ServiceJWT.defaultLifetime

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = lifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        key: secp256k1.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = lifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            key: .secp256k1(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func inspect(_ compact: String) throws -> Inspection {
        try ServiceJWT.inspect(compact)
    }

    public static func verify(
        _ compact: String,
        publicKey: ATProtoJWTVerificationKey,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        try ServiceJWT.verify(
            compact,
            publicKey: publicKey,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    public static func verify(
        _ compact: String,
        publicKey: PLCDIDVerificationKey,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        try ServiceJWT.verify(
            compact,
            publicKey: publicKey,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }
}
