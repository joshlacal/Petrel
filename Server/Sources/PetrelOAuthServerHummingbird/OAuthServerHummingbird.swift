import Foundation
import HTTPTypes
import Hummingbird
import NIOCore
import PetrelOAuthServer

/// Mounts a framework-agnostic ``OAuthAuthorizationServer`` on a Hummingbird
/// router, and adapts Hummingbird requests for the resource-server verifier.
public enum OAuthServerHummingbird {
  /// Registers every endpoint of `server` on `router`.
  ///
  /// Each route collects the request body under `maximumBodyBytes`, converts
  /// the request to an ``OAuthHTTPRequest``, calls
  /// ``OAuthAuthorizationServer/handle(_:)`` and converts the result back.
  /// The adapter adds no behaviour of its own.
  public static func addRoutes<Context: RequestContext>(
    to router: Router<Context>,
    server: OAuthAuthorizationServer,
    maximumBodyBytes: Int = 64 * 1024
  ) {
    for route in OAuthAuthorizationServer.routes {
      guard let method = HTTPRequest.Method(route.method) else { continue }
      router.on(RouterPath(route.path), method: method) { request, _ -> Response in
        guard let converted = await convert(request, maximumBodyBytes: maximumBodyBytes) else {
          return Response(status: .contentTooLarge)
        }
        return response(await server.handle(converted))
      }
    }
  }

  /// Verifies the access token and DPoP proof of a resource request.
  ///
  /// - Parameters:
  ///   - request: the incoming request.
  ///   - verifier: the resource-server verifier.
  ///   - publicOrigin: the origin clients address this server by, for example
  ///     `https://pds.example.com`. The DPoP `htu` is checked against this
  ///     origin plus the request path, never against the `Host` header.
  /// - Returns: the grant on success, or the challenge response to send.
  public static func authenticate(
    _ request: Request,
    verifier: OAuthResourceServerVerifier,
    publicOrigin: URL
  ) async -> Result<OAuthAccessGrant, OAuthResourceChallenge> {
    let base = publicOrigin.absoluteString.hasSuffix("/")
      ? String(publicOrigin.absoluteString.dropLast())
      : publicOrigin.absoluteString
    guard let url = URL(string: base + request.uri.path) else {
      return .failure(OAuthResourceChallenge(response: Response(status: .badRequest)))
    }
    do {
      let grant = try await verifier.authenticate(
        method: request.method.rawValue,
        url: url,
        headers: headers(request)
      )
      return .success(grant)
    } catch {
      return .failure(OAuthResourceChallenge(response: response(verifier.challenge(for: error))))
    }
  }

  /// Converts a core response to a Hummingbird response.
  public static func response(_ value: OAuthHTTPResponse) -> Response {
    var fields = HTTPFields()
    for field in value.headers.fields {
      guard let name = HTTPField.Name(field.name) else { continue }
      fields.append(HTTPField(name: name, value: field.value))
    }
    return Response(
      status: HTTPResponse.Status(code: value.status),
      headers: fields,
      body: ResponseBody(byteBuffer: ByteBuffer(bytes: value.body))
    )
  }

  static func headers(_ request: Request) -> OAuthHTTPHeaders {
    OAuthHTTPHeaders(request.headers.map { ($0.name.rawName, $0.value) })
  }

  static func convert(_ request: Request, maximumBodyBytes: Int) async -> OAuthHTTPRequest? {
    var request = request
    guard let buffer = try? await request.collectBody(upTo: maximumBodyBytes) else { return nil }
    return OAuthHTTPRequest(
      method: request.method.rawValue,
      path: request.uri.path,
      query: request.uri.query,
      headers: headers(request),
      body: Data(buffer.readableBytesView)
    )
  }
}

/// The response to send when a resource request is not authorized: `401` or
/// `403` with the `WWW-Authenticate: DPoP` challenge and a fresh nonce.
public struct OAuthResourceChallenge: Error, Sendable {
  /// The challenge response.
  public let response: Response
}
