import Crypto
import Foundation
import PetrelCrypto

/// Why a DPoP proof was not accepted. The cases are the distinctions an
/// endpoint needs to choose its response.
public enum OAuthDPoPError: Error, Sendable, Equatable {
    /// The proof carried no `nonce`, or one that is not current. The client
    /// must retry with the nonce from the `DPoP-Nonce` response header
    /// (`use_dpop_nonce`).
    case useNonce
    /// The proof is malformed, wrongly signed, bound to another request, too
    /// old, or replayed (`invalid_dpop_proof`). The associated text is an
    /// operator-facing reason and is safe to return as `error_description`.
    case invalidProof(String)
    /// The replay store could not answer.
    case unavailable
}

/// A DPoP proof that passed every check.
public struct OAuthValidatedDPoPProof: Sendable, Equatable {
    /// The RFC 7638 thumbprint of the proof's public key (`jkt`).
    public let keyThumbprint: String
    /// The proof's public key.
    public let key: OAuthJSONWebKey
    /// The proof's `jti`.
    public let jwtID: String
    /// The proof's `iat`.
    public let issuedAt: Date
}

/// Verifies DPoP proofs (RFC 9449 §4.3) for any endpoint and method.
///
/// A thumbprint is produced only after the signature, embedded JWK, `htm`,
/// `htu`, `iat` window, server nonce, access-token hash and `jti` replay
/// checks all pass. Signatures verify with either `s` encoding, because JOSE
/// does not canonicalise it.
public struct OAuthDPoPProofValidator: Sendable {
    /// The required `typ` of a DPoP proof.
    public static let proofType = "dpop+jwt"

    private let nonceService: OAuthDPoPNonceService
    private let replayStore: any OAuthReplayStore
    private let digest: OAuthKeyedDigest
    private let proofLifetime: TimeInterval
    private let clockSkew: TimeInterval

    /// Creates a validator.
    ///
    /// - Parameters:
    ///   - secret: the server secret `jti` values are digested under before
    ///     they reach the replay store.
    ///   - nonceService: the nonces this server issues.
    ///   - replayStore: where `jti` values are reserved.
    ///   - proofLifetime: how old a proof's `iat` may be, at most 600 seconds.
    ///   - clockSkew: tolerance for a client clock that runs ahead.
    public init(
        secret: Data,
        nonceService: OAuthDPoPNonceService,
        replayStore: any OAuthReplayStore,
        proofLifetime: TimeInterval = 300,
        clockSkew: TimeInterval = 60
    ) throws {
        guard proofLifetime > 0, proofLifetime <= 600, proofLifetime.isFinite,
              clockSkew >= 0, clockSkew <= 120, clockSkew.isFinite
        else {
            throw OAuthServerError.malformed("DPoP validation lifetime is invalid")
        }
        digest = try OAuthKeyedDigest(secret: secret)
        self.nonceService = nonceService
        self.replayStore = replayStore
        self.proofLifetime = proofLifetime
        self.clockSkew = clockSkew
    }

    /// Validates one proof for one request.
    ///
    /// - Parameters:
    ///   - proof: the value of the single `DPoP` request header.
    ///   - method: the HTTP method of the request.
    ///   - target: the URL of the request as the client addressed it. Query and
    ///     fragment are ignored, as RFC 9449 requires.
    ///   - accessToken: when the request presents an access token, the token;
    ///     the proof's `ath` must then be its SHA-256 hash.
    ///   - now: the evaluation instant.
    public func validate(
        _ proof: String,
        method: String,
        target: URL,
        accessToken: String? = nil,
        now: Date = Date()
    ) async throws(OAuthDPoPError) -> OAuthValidatedDPoPProof {
        let verified: OAuthVerifiedJWT
        let jwk: OAuthJSONWebKey
        do {
            let header = try OAuthCompactJWT.unverifiedHeader(proof)
            guard let embedded = header.jwk else {
                throw OAuthServerError.malformed("DPoP proof lacks a public jwk")
            }
            jwk = embedded
            verified = try OAuthCompactJWT.verify(
                proof,
                key: jwk,
                expectedType: Self.proofType,
                signatureEncoding: .joseInteroperable,
                constraints: .init(
                    now: now,
                    clockSkew: clockSkew,
                    requireIssuedAt: true,
                    maximumAge: proofLifetime
                )
            )
        } catch let error as OAuthServerError {
            throw .invalidProof(Self.reason(error))
        } catch {
            throw .invalidProof("DPoP proof is malformed")
        }

        let claims: Claims
        do {
            claims = try OAuthCompactJWT.decodeClaims(Claims.self, from: verified)
        } catch {
            throw .invalidProof("DPoP proof claims are malformed")
        }
        guard let jwtID = claims.jwtID, Self.isValidJTI(jwtID) else {
            throw .invalidProof("DPoP proof jti is missing or invalid")
        }
        guard let htm = claims.method, htm == method.uppercased() else {
            throw .invalidProof("DPoP proof htm does not match the request method")
        }
        guard let htu = claims.target,
              let expected = try? Self.normalizedTarget(target),
              let presented = try? Self.normalizedTarget(htu),
              ConstantTime.equal(expected, presented)
        else {
            throw .invalidProof("DPoP proof htu does not match the request URL")
        }
        if let accessToken {
            let expectedHash = JWTBase64URL.encode(Data(SHA256.hash(data: Data(accessToken.utf8))))
            guard let ath = claims.accessTokenHash, ConstantTime.equal(ath, expectedHash) else {
                throw .invalidProof("DPoP proof ath does not match the access token")
            }
        }
        // The nonce is checked after the signature so that only the holder of
        // the key learns whether a nonce is current, and before the replay
        // reservation so that a `use_dpop_nonce` retry can reuse nothing.
        guard let nonce = claims.nonce, nonceService.isValid(nonce, now: now) else {
            throw .useNonce
        }
        guard let issuedAt = verified.registeredClaims.issuedAt else {
            throw .invalidProof("DPoP proof lacks iat")
        }
        let replayExpiresAt = Date(timeIntervalSince1970: TimeInterval(issuedAt) + proofLifetime + clockSkew)
        guard replayExpiresAt > now else { throw .invalidProof("DPoP proof is too old") }
        let claimed: Bool
        do {
            claimed = try await replayStore.claim(
                namespace: .dpopProof,
                digest: digest.digest("\(jwk.thumbprint()).\(jwtID)", purpose: .dpopProof),
                expiresAt: replayExpiresAt,
                now: now
            )
        } catch {
            throw .unavailable
        }
        guard claimed else { throw .invalidProof("DPoP proof was replayed") }
        return OAuthValidatedDPoPProof(
            keyThumbprint: jwk.thumbprint(),
            key: jwk,
            jwtID: jwtID,
            issuedAt: Date(timeIntervalSince1970: TimeInterval(issuedAt))
        )
    }

    /// The `htu` comparison form of a URL (RFC 9449 §4.3, RFC 3986 §6.2):
    /// lowercased scheme and host, default port removed, dot segments resolved,
    /// percent-encoding hex digits uppercased, and query and fragment dropped.
    public static func normalizedTarget(_ url: URL) throws -> String {
        try normalizedTarget(url.absoluteString)
    }

    /// The `htu` comparison form of a URL given as text. See
    /// ``normalizedTarget(_:)-(URL)``.
    public static func normalizedTarget(_ text: String) throws -> String {
        guard text.utf8.count <= 2048,
              let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil
        else {
            throw OAuthServerError.malformed("DPoP request target is invalid")
        }
        let hostText = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        let defaultPort = scheme == "https" ? 443 : 80
        let port = components.port.flatMap { $0 == defaultPort ? nil : $0 }.map { ":\($0)" } ?? ""
        let path = normalizedPath(components.percentEncodedPath)
        return "\(scheme)://\(hostText)\(port)\(path)"
    }

    /// RFC 3986 §5.2.4 dot-segment removal and §6.2.2.1 case normalisation of
    /// percent-encoded octets.
    static func normalizedPath(_ path: String) -> String {
        guard !path.isEmpty else { return "/" }
        var output: [Substring] = []
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        for (index, segment) in segments.enumerated() {
            if index == 0 { continue } // the empty segment before the leading "/"
            switch segment {
            case ".":
                if index == segments.count - 1 { output.append("") }
            case "..":
                if !output.isEmpty { output.removeLast() }
                if index == segments.count - 1 { output.append("") }
            default:
                output.append(segment)
            }
        }
        let joined = "/" + output.joined(separator: "/")
        var normalized = ""
        normalized.reserveCapacity(joined.count)
        var remainingHex = 0
        for character in joined {
            if character == "%" {
                remainingHex = 2
                normalized.append(character)
            } else if remainingHex > 0 {
                remainingHex -= 1
                normalized.append(contentsOf: character.uppercased())
            } else {
                normalized.append(character)
            }
        }
        return normalized
    }

    private struct Claims: Decodable, Sendable {
        let jwtID: String?
        let method: String?
        let target: String?
        let nonce: String?
        let accessTokenHash: String?

        private enum CodingKeys: String, CodingKey {
            case jwtID = "jti"
            case method = "htm"
            case target = "htu"
            case nonce
            case accessTokenHash = "ath"
        }
    }

    private static func isValidJTI(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 512 && value.utf8.allSatisfy { $0 >= 0x20 && $0 != 0x7F }
    }

    private static func reason(_ error: OAuthServerError) -> String {
        switch error {
        case .expired: "DPoP proof is too old"
        case let .malformed(text), let .unauthorized(text), let .invalidIdentifier(text), let .unavailable(text):
            text.replacingOccurrences(of: "JWT", with: "DPoP proof")
        }
    }
}
