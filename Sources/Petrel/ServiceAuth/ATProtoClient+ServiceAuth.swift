import Foundation
import PetrelCrypto

/// A service-auth token a PDS issued on behalf of the signed-in account.
///
/// The token is opaque to the client that requested it — only the service
/// it is addressed to can verify it — but its claims are readable, and are
/// exposed here so the caller can see what it was given and when it runs
/// out.
public struct ServiceAuthToken: Sendable, Equatable {
    /// The compact JWT.
    public let token: String
    /// The token's unverified contents.
    public let inspection: ServiceJWTInspection

    /// Wraps a token string, decoding its claims.
    ///
    /// - Throws: `PetrelCryptoError` if `token` is not a service JWT.
    public init(token: String) throws {
        self.token = token
        inspection = try ServiceJWT.inspect(token)
    }

    /// The value for the `Authorization` header: `Bearer <token>`.
    public var authorizationHeaderValue: String { ServiceJWT.bearerAuthorization(token) }

    /// The account the token speaks for (`iss`, without any fragment).
    public var issuer: String { inspection.issuerDID }

    /// The service the token is addressed to (`aud`).
    public var audience: String { inspection.claims.aud }

    /// The endpoint the token is bound to (`lxm`), if any.
    public var lexiconMethod: String? { inspection.claims.lxm }

    /// When the token stops being accepted (`exp`).
    public var expiresAt: Date { inspection.expiresAt }

    /// Whether the token has expired, or will within `margin` seconds.
    public func isExpired(at date: Date = Date(), margin: TimeInterval = 0) -> Bool {
        expiresAt <= date.addingTimeInterval(margin)
    }
}

/// Why a service-auth token could not be obtained from the PDS.
public enum ServiceAuthRequestError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The request was not sent because an argument is invalid.
    case invalidRequest(String)
    /// The PDS answered with a status other than 200 and no declared error.
    case requestFailed(statusCode: Int)
    /// The PDS answered 200 with something that is not a service JWT.
    case invalidToken(String)
    /// The PDS issued a token for a different audience or method than the
    /// one requested.
    case unexpectedClaims(String)

    /// A description of the failure. It never contains the token.
    public var description: String {
        switch self {
        case let .invalidRequest(reason):
            return "Invalid service auth request: \(reason)"
        case let .requestFailed(statusCode):
            return "Service auth request failed with HTTP \(statusCode)"
        case let .invalidToken(reason):
            return "PDS returned an invalid service auth token: \(reason)"
        case let .unexpectedClaims(reason):
            return "PDS returned a service auth token with unexpected claims: \(reason)"
        }
    }
}

public extension ATProtoClient {
    /// Asks the account's PDS for a service-auth token
    /// (`com.atproto.server.getServiceAuth`).
    ///
    /// Use this when your app talks to a service directly instead of
    /// through the PDS proxy — uploading video to a video service, calling
    /// a feed generator or labeler — and that service authenticates callers
    /// with inter-service JWTs. The PDS signs the token with the account's
    /// signing key.
    ///
    /// ```swift
    /// let token = try await client.getServiceAuthToken(
    ///     audience: ATProtoServiceReference("did:web:video.example.com#video_service"),
    ///     lexiconMethod: "com.example.video.upload",
    ///     lifetime: 30 * 60
    /// )
    /// request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
    /// ```
    ///
    /// - Parameters:
    ///   - audience: The service the token is for. Include the service
    ///     identifier (`did#service`) unless the service is known to expect
    ///     a bare DID.
    ///   - lexiconMethod: The NSID of the endpoint the token will be used
    ///     on. A PDS only issues method-less tokens (`nil`) for at most one
    ///     minute.
    ///   - lifetime: Seconds until the token expires; `nil` lets the PDS
    ///     choose (60 seconds). The reference PDS grants at most one hour.
    ///   - now: The clock the expiry is computed from.
    /// - Returns: The token, with its claims decoded.
    /// - Throws: `ServiceAuthRequestError`; the endpoint's declared error
    ///   (`BadExpiration`) as an `ATProtoError`; or a network error.
    func getServiceAuthToken(
        audience: ATProtoServiceReference,
        lexiconMethod: String?,
        lifetime: TimeInterval? = nil,
        now: Date = Date()
    ) async throws -> ServiceAuthToken {
        var method: NSID?
        if let lexiconMethod {
            guard ServiceJWT.isNSID(lexiconMethod), let nsid = try? NSID(nsidString: lexiconMethod) else {
                throw ServiceAuthRequestError.invalidRequest("lexicon method is not an NSID")
            }
            method = nsid
        }
        var expiration: Int?
        if let lifetime {
            guard lifetime.isFinite, lifetime >= 1, lifetime <= 24 * 60 * 60 else {
                throw ServiceAuthRequestError.invalidRequest("lifetime must be between one second and one day")
            }
            expiration = Int(now.timeIntervalSince1970.rounded(.down)) + Int(lifetime.rounded(.down))
        }

        let (responseCode, output) = try await com.atproto.server.getServiceAuth(
            input: ComAtprotoServerGetServiceAuth.Parameters(
                aud: audience.description, exp: expiration, lxm: method
            )
        )
        guard responseCode == 200, let output else {
            throw ServiceAuthRequestError.requestFailed(statusCode: responseCode)
        }

        let token: ServiceAuthToken
        do {
            token = try ServiceAuthToken(token: output.token)
        } catch {
            throw ServiceAuthRequestError.invalidToken(String(describing: error))
        }
        // The token is a credential for whatever it names. One addressed to
        // another service, or bound to another endpoint, is not the token
        // that was asked for; refuse to hand it on.
        guard let issued = try? ATProtoServiceReference(token.audience), issued.did == audience.did,
              issued.serviceID == nil || issued.serviceID == audience.serviceID else {
            throw ServiceAuthRequestError.unexpectedClaims("audience is \(token.audience)")
        }
        guard token.lexiconMethod == lexiconMethod else {
            throw ServiceAuthRequestError.unexpectedClaims(
                "lexicon method is \(token.lexiconMethod ?? "absent")"
            )
        }
        return token
    }

    /// Routes a lexicon namespace, or one endpoint, through the PDS proxy
    /// to a service.
    ///
    /// Requests whose NSID equals `prefix`, or starts with `prefix` plus a
    /// period, are sent to the PDS with
    /// `atproto-proxy: <did>#<service>`; the PDS forwards them with a
    /// service-auth token it signs for the account. The longest matching
    /// prefix wins, so one endpoint can be sent somewhere other than the
    /// rest of its namespace:
    ///
    /// ```swift
    /// // Everything under app.bsky goes to a self-hosted AppView…
    /// try await client.setServiceProxy(
    ///     ATProtoServiceReference("did:web:appview.example.com#bsky_appview"), for: "app.bsky"
    /// )
    /// // …and reports go to one labeler.
    /// try await client.setServiceProxy(
    ///     ATProtoServiceReference(did: "did:web:labeler.example.com", serviceID: "atproto_labeler"),
    ///     for: "com.atproto.moderation.createReport"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - service: The service to forward to. It must carry a service
    ///     identifier, which the PDS needs to find the endpoint.
    ///   - prefix: A lexicon namespace (`app.bsky`) or a full NSID.
    /// - Throws: `PetrelCryptoError.invalidIdentifier` if `service` has no
    ///   service identifier or `prefix` is empty.
    func setServiceProxy(_ service: ATProtoServiceReference, for prefix: String) async throws {
        let value = try service.proxyHeaderValue()
        guard !prefix.isEmpty else {
            throw PetrelCryptoError.invalidIdentifier("proxy prefix must be a lexicon namespace or NSID")
        }
        await setServiceDID(value, for: prefix)
    }

    /// The service a request to `nsid` is proxied to, if any.
    ///
    /// - Parameter nsid: The endpoint's NSID.
    /// - Returns: The `atproto-proxy` target, or `nil` if the request goes
    ///   to the PDS itself.
    func serviceProxy(for nsid: String) async -> ATProtoServiceReference? {
        guard let value = await networkService.getServiceDID(for: nsid) else { return nil }
        return try? ATProtoServiceReference(value)
    }
}
