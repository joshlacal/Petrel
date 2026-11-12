import Foundation

/// A private ECDSA key that signs compact JWTs with ES256 or ES256K.
///
/// The key is held as its raw 32-byte scalar so the value is `Sendable` on
/// every platform. It is never encoded: the type is deliberately not
/// `Codable`, and its description redacts the scalar.
public struct OAuthSigningKey: Sendable, CustomStringConvertible {
    /// The algorithm this key signs with.
    public let algorithm: OAuthJWSAlgorithm
    /// The key identifier placed in the JWS header's `kid`.
    public let keyID: String?
    private let privateScalar: Data
    private let publicX: Data
    private let publicY: Data

    /// Wraps an existing private key.
    ///
    /// - Parameters:
    ///   - algorithm: `ES256` for a P-256 key, `ES256K` for secp256k1.
    ///   - rawRepresentation: the 32-byte big-endian private scalar.
    ///   - keyID: the `kid` this key is published under.
    /// - Throws: ``OAuthServerError/malformed(_:)`` when the scalar is not a
    ///   valid private key on the algorithm's curve.
    public init(
        algorithm: OAuthJWSAlgorithm = .es256,
        rawRepresentation: Data,
        keyID: String? = nil
    ) throws {
        let coordinates = try JOSECurveBackend.publicCoordinates(
            curve: algorithm.curve,
            privateKey: rawRepresentation
        )
        self.algorithm = algorithm
        self.keyID = keyID
        privateScalar = rawRepresentation
        publicX = coordinates.x
        publicY = coordinates.y
    }

    /// Generates a fresh key.
    public static func generate(
        algorithm: OAuthJWSAlgorithm = .es256,
        keyID: String? = nil
    ) throws -> OAuthSigningKey {
        try OAuthSigningKey(
            algorithm: algorithm,
            rawRepresentation: JOSECurveBackend.generatePrivateKey(curve: algorithm.curve),
            keyID: keyID
        )
    }

    /// The 32-byte private scalar, for persisting the key in a secret store.
    public var rawRepresentation: Data { privateScalar }

    /// The public half as a JWK, suitable for a JWKS document.
    public var publicJWK: OAuthJSONWebKey {
        get throws { try publicKey(includingKeyID: true) }
    }

    /// The RFC 7638 thumbprint of the public key.
    public var thumbprint: String {
        get throws { try publicKey(includingKeyID: false).thumbprint() }
    }

    func publicKey(includingKeyID: Bool) throws -> OAuthJSONWebKey {
        try OAuthJSONWebKey(
            curve: algorithm.curve,
            x: JWTBase64URLBridge.encode(publicX),
            y: JWTBase64URLBridge.encode(publicY),
            keyID: includingKeyID ? keyID : nil,
            algorithm: includingKeyID ? algorithm : nil,
            use: includingKeyID ? "sig" : nil
        )
    }

    /// Signs `signingInput` and returns the 64-byte low-S `r || s` signature.
    public func signature(for signingInput: Data) throws -> Data {
        try JOSECurveBackend.sign(
            curve: algorithm.curve,
            privateKey: privateScalar,
            signingInput: signingInput
        )
    }

    public var description: String {
        "OAuthSigningKey(\(algorithm.rawValue), kid: \(keyID ?? "nil"), [redacted])"
    }
}
