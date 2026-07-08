import Foundation
import Hummingbird
import Logging

/// Assembles the configured server. `init` builds all stateful components;
/// `buildRouter()` wires routes; `buildApplication(logger:)` returns a
/// runnable app.
public struct CABServer: Sendable {
  public let config: ServerConfig
  public let keyStore: KeyStore
  let validator: DPoPValidator
  let replayStore: ReplayStore
  let nonceService: NonceService
  let deviceStore: any DeviceStore
  let minter: AssertionMinter
  let rateLimiter: RateLimiter?

  public init(config: ServerConfig) throws {
    self.config = config
    let loadedKeyStore = try KeyStore(config: config)
    keyStore = loadedKeyStore
    validator = DPoPValidator(
      endpointURL: Self.assertionEndpoint(publicUrl: config.publicUrl),
      iatWindow: TimeInterval(config.iatWindowSeconds)
    )
    replayStore = ReplayStore(ttl: TimeInterval(config.iatWindowSeconds))
    nonceService = NonceService(secretBase64: config.nonceSecretBase64)
    deviceStore = InMemoryDeviceStore(deniedJKTs: config.deniedJkts)
    minter = AssertionMinter(
      clientId: config.clientId,
      signingKey: loadedKeyStore.activeKey,
      ttl: TimeInterval(config.assertionTtlSeconds)
    )
    rateLimiter = config.rateLimit.map { RateLimiter(requestsPerMinute: $0.requestsPerMinute) }
  }

  static func assertionEndpoint(publicUrl: String) -> String {
    let base = publicUrl.hasSuffix("/") ? String(publicUrl.dropLast()) : publicUrl
    return base + "/oauth/client-assertion"
  }

  public func buildRouter() -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.middlewares.add(
      OriginPolicyMiddleware(
        allowedOrigins: Set(config.allowedOrigins),
        requireOrigin: config.requireOrigin
      )
    )

    router.get("/health") { _, _ in "OK" }

    // JWKS must be precomputable — fail at startup, not per request.
    let jwksBody = (try? keyStore.jwksDocument()) ?? Data()
    router.get("/.well-known/jwks.json") { _, _ -> Response in
      Response(
        status: .ok,
        headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
        body: .init(byteBuffer: ByteBuffer(data: jwksBody))
      )
    }

    if let metadata = config.clientMetadata {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let metadataBody = (try? encoder.encode(metadata)) ?? Data()
      router.get("/oauth-client-metadata.json") { _, _ -> Response in
        Response(
          status: .ok,
          headers: [.contentType: "application/json", .cacheControl: "public, max-age=300"],
          body: .init(byteBuffer: ByteBuffer(data: metadataBody))
        )
      }
    }

    let config = self.config
    let validator = self.validator
    let replayStore = self.replayStore
    let nonceService = self.nonceService
    let deviceStore = self.deviceStore
    let minter = self.minter
    let rateLimiter = self.rateLimiter

    router.post("/oauth/client-assertion") { request, context -> Response in
      do {
        guard let proof = request.headers[.dpop] else {
          throw CABRequestError.invalidDPoPProof("missing DPoP header")
        }
        let (validated, claims) = try validator.validate(proof: proof)

        if config.requireNonce {
          guard let nonce = claims.nonce, nonceService.isValid(nonce) else {
            throw CABRequestError.useDPoPNonce()
          }
        }
        guard await replayStore.checkAndInsert(validated.jti) else {
          throw CABRequestError.invalidDPoPProof("jti replayed")
        }
        if await deviceStore.isDenied(jkt: validated.jkt) {
          context.logger.warning(
            "device refused", metadata: ["jkt": .string(validated.jkt)]
          )
          throw CABRequestError.accessDenied("device refused by policy")
        }
        if let rateLimiter, await rateLimiter.allow(key: "jkt:\(validated.jkt)") == false {
          throw CABRequestError.rateLimited()
        }
        await deviceStore.record(jkt: validated.jkt, now: Date())

        struct AssertionForm: Decodable {
          let aud: String?
        }
        let form = try? await URLEncodedFormDecoder().decode(
          AssertionForm.self, from: request, context: context
        )
        guard let aud = form?.aud, !aud.isEmpty else {
          throw CABRequestError.invalidRequest("missing aud")
        }
        try CABServer.checkAud(aud, allowlist: config.audAllowlist)

        let assertion = try minter.mint(aud: aud, jkt: validated.jkt)
        context.logger.info(
          "assertion minted",
          metadata: ["jkt": .string(validated.jkt), "aud": .string(aud)]
        )

        struct ClientAssertionResponseBody: ResponseEncodable {
          let clientId: String
          let clientAssertion: String
          enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case clientAssertion = "client_assertion"
          }
        }
        let body = ClientAssertionResponseBody(
          clientId: config.clientId, clientAssertion: assertion
        )
        var response = try context.responseEncoder.encode(
          body, from: request, context: context
        )
        response.headers[.cacheControl] = "no-store"
        return response
      } catch let error as CABRequestError {
        if error.error != "use_dpop_nonce" {
          context.logger.notice(
            "assertion refused",
            metadata: ["error": .string(error.error), "detail": .string(error.description)]
          )
        }
        return CABServer.errorResponse(error, nonceService: nonceService)
      }
    }

    return router
  }

  static func checkAud(_ aud: String, allowlist: [String]?) throws {
    guard let url = URL(string: aud), let scheme = url.scheme, let host = url.host else {
      throw CABRequestError.invalidRequest("aud must be a valid URL")
    }
    let isLoopback = host == "127.0.0.1" || host == "localhost" || host == "::1"
    guard scheme == "https" || (scheme == "http" && isLoopback) else {
      throw CABRequestError.invalidRequest("aud must be an https URL")
    }
    if let allowlist, !allowlist.contains(aud) {
      throw CABRequestError.invalidRequest("aud not allowed by this backend")
    }
  }

  static func errorResponse(_ error: CABRequestError, nonceService: NonceService) -> Response {
    struct ErrorBody: Encodable {
      let error: String
      let errorDescription: String
      enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
      }
    }
    let data =
      (try? JSONEncoder().encode(
        ErrorBody(error: error.error, errorDescription: error.description)
      )) ?? Data()
    var headers: HTTPFields = [.contentType: "application/json", .cacheControl: "no-store"]
    if error.error == "use_dpop_nonce" {
      headers[.dpopNonce] = nonceService.issue()
    }
    return Response(
      status: .init(code: error.status, reasonPhrase: ""),
      headers: headers,
      body: .init(byteBuffer: ByteBuffer(data: data))
    )
  }

  public func buildApplication(logger: Logger) -> some ApplicationProtocol {
    Application(
      router: buildRouter(),
      configuration: .init(
        address: .hostname(config.host, port: config.port),
        serverName: "petrel-cab-server"
      ),
      logger: logger
    )
  }
}
