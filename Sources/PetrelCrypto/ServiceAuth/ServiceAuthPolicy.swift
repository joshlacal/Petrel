import Foundation

/// Which `aud` claims a receiving service accepts.
///
/// The specification: "Receiving services must verify that the audience
/// field matches their own DID and service type, to prevent reuse or
/// forwarding of tokens." New tokens carry the service fragment
/// (`did:web:feed.example.com#bsky_fg`); older software sends the bare DID,
/// which a service may accept for compatibility but which "is not the same
/// as a wildcard".
///
/// ```swift
/// // Only did:web:feed.example.com#bsky_fg
/// let strict = ServiceAuthAudience.service(did: "did:web:feed.example.com", id: "bsky_fg")
/// // Also the bare DID, for PDSes that still strip the fragment
/// let lenient = ServiceAuthAudience.service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true)
/// ```
public struct ServiceAuthAudience: Sendable, Hashable {
    /// The exact `aud` strings accepted, or `nil` if the check is disabled.
    public let acceptedValues: Set<String>?

    private init(acceptedValues: Set<String>?) {
        self.acceptedValues = acceptedValues
    }

    /// Accepts exactly one `aud` string.
    public static func exactly(_ value: String) -> ServiceAuthAudience {
        ServiceAuthAudience(acceptedValues: [value])
    }

    /// Accepts any of the given `aud` strings.
    public static func anyOf(_ values: Set<String>) -> ServiceAuthAudience {
        ServiceAuthAudience(acceptedValues: values)
    }

    /// Accepts this service's DID with its service identifier.
    ///
    /// - Parameters:
    ///   - did: The service's own DID.
    ///   - id: The service identifier from the DID document's `service`
    ///     array, with or without the leading `#` (`bsky_fg`,
    ///     `atproto_labeler`, `bsky_appview`).
    ///   - acceptBareDID: Also accept `did` alone. The reference PDS sent
    ///     bare DIDs when proxying until Spring 2026, so services that
    ///     receive proxied requests usually need `true` for now.
    public static func service(did: String, id: String, acceptBareDID: Bool = false) -> ServiceAuthAudience {
        let fragment = id.hasPrefix("#") ? String(id.dropFirst()) : id
        var values: Set<String> = ["\(did)#\(fragment)"]
        if acceptBareDID {
            values.insert(did)
        }
        return ServiceAuthAudience(acceptedValues: values)
    }

    /// Disables the audience check. A token minted for any service is
    /// accepted, so this is only appropriate for tools that inspect tokens,
    /// never for a service authenticating requests.
    public static let unchecked = ServiceAuthAudience(acceptedValues: nil)

    /// Whether `audience` passes this policy.
    public func accepts(_ audience: String) -> Bool {
        guard let acceptedValues else { return true }
        return acceptedValues.contains(audience)
    }
}

/// How a receiving service checks the `lxm` ("lexicon method") claim.
///
/// `lxm` binds a token to one XRPC endpoint. The specification makes the
/// claim optional in the token but "required for all authenticated XRPC
/// endpoint requests", so an endpoint handler should normally use
/// ``exactly(_:)`` with its own NSID.
public enum ServiceAuthMethodPolicy: Sendable, Hashable {
    /// `lxm` must be present and equal to this NSID. What the reference
    /// `verifyJwt(jwt, ownDid, lxm, …)` does when given a method.
    case exactly(String)
    /// `lxm` must equal this NSID when present; a token without `lxm` is
    /// accepted. For endpoints that still take the method-less tokens a
    /// PDS issues with a lifetime of at most one minute.
    case exactlyIfPresent(String)
    /// `lxm` must be present; the caller compares it itself (for example a
    /// router that authenticates before it dispatches).
    case required
    /// `lxm` is not checked. What the reference does when given `null`.
    case optional

    /// Evaluates the policy against a token's `lxm` claim.
    ///
    /// - Throws: ``ServiceAuthError/lexiconMethodMismatch(expected:actual:)``.
    public func check(_ lexiconMethod: String?) throws(ServiceAuthError) {
        switch self {
        case let .exactly(expected):
            guard lexiconMethod == expected else {
                throw .lexiconMethodMismatch(expected: expected, actual: lexiconMethod)
            }
        case let .exactlyIfPresent(expected):
            guard lexiconMethod == nil || lexiconMethod == expected else {
                throw .lexiconMethodMismatch(expected: expected, actual: lexiconMethod)
            }
        case .required:
            guard lexiconMethod != nil else {
                throw .lexiconMethodMismatch(expected: nil, actual: nil)
            }
        case .optional:
            break
        }
    }
}

/// Claims and header fields the specification marks "required" that the
/// reference verifier nevertheless does not insist on.
///
/// The default (``reference``) accepts what `@atproto/xrpc-server` accepts,
/// so tokens from older or minimal issuers keep working. ``specification``
/// demands everything the specification lists.
public struct ServiceAuthRequiredClaims: OptionSet, Sendable, Hashable {
    /// The option bits.
    public let rawValue: Int

    /// Creates a set from raw option bits.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The `typ` header must be present.
    public static let type = ServiceAuthRequiredClaims(rawValue: 1 << 0)
    /// The `iat` claim must be present.
    public static let issuedAt = ServiceAuthRequiredClaims(rawValue: 1 << 1)
    /// The `jti` claim must be present. Implied when a replay store is
    /// configured.
    public static let nonce = ServiceAuthRequiredClaims(rawValue: 1 << 2)

    /// Only what the reference verifier requires: `iss`, `aud`, `exp`.
    public static let reference: ServiceAuthRequiredClaims = []
    /// Everything the specification marks required: `typ`, `iat`, `jti`.
    public static let specification: ServiceAuthRequiredClaims = [.type, .issuedAt, .nonce]
}

/// The outcome of a successful service-auth verification: who is calling,
/// and what the token was bound to.
public struct VerifiedServiceAuth: Sendable, Equatable {
    /// The issuer's DID, without any fragment. This is the account or
    /// service the request is made on behalf of.
    public let issuer: String
    /// The fragment a legacy token carried after the issuer DID
    /// (`atproto_labeler` in `did:plc:…#atproto_labeler`), without the `#`.
    /// `nil` for tokens that follow the current specification.
    public let issuerFragment: String?
    /// The verification method whose key verified the signature, as a
    /// fragment with its `#` (`#atproto` unless the token named another
    /// accepted key).
    public let keyID: String
    /// The `aud` claim, exactly as sent.
    public let audience: String
    /// The `lxm` claim: the endpoint the token authorizes, if bound.
    public let lexiconMethod: String?
    /// The `jti` claim: the token's unique nonce, if present.
    public let nonce: String?
    /// The `exp` claim.
    public let expiresAt: Date
    /// The `iat` claim, if present.
    public let issuedAt: Date?
    /// The header `alg`: `ES256` or `ES256K`.
    public let algorithm: String
    /// The key that verified the signature.
    public let signingKey: ATProtoPublicKey
    /// All decoded claims.
    public let claims: ServiceJWTClaims

    /// Creates a verification result. Verifiers build this; the initializer
    /// is public so services can construct one in their own tests.
    public init(
        issuer: String,
        issuerFragment: String? = nil,
        keyID: String = ServiceJWT.defaultKeyID,
        audience: String,
        lexiconMethod: String?,
        nonce: String?,
        expiresAt: Date,
        issuedAt: Date?,
        algorithm: String,
        signingKey: ATProtoPublicKey,
        claims: ServiceJWTClaims
    ) {
        self.issuer = issuer
        self.issuerFragment = issuerFragment
        self.keyID = keyID
        self.audience = audience
        self.lexiconMethod = lexiconMethod
        self.nonce = nonce
        self.expiresAt = expiresAt
        self.issuedAt = issuedAt
        self.algorithm = algorithm
        self.signingKey = signingKey
        self.claims = claims
    }
}
