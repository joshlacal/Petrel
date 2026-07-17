import HTTPTypes
import Hummingbird

// Nested inside OriginPolicyMiddleware<Context> these would be static stored
// properties of a generic type, which Swift disallows — hoisted to file scope.
private enum Header {
  static let origin = HTTPField.Name("Origin")!
  static let allowOrigin = HTTPField.Name("Access-Control-Allow-Origin")!
  static let allowMethods = HTTPField.Name("Access-Control-Allow-Methods")!
  static let allowHeaders = HTTPField.Name("Access-Control-Allow-Headers")!
  static let exposeHeaders = HTTPField.Name("Access-Control-Expose-Headers")!
  static let maxAge = HTTPField.Name("Access-Control-Max-Age")!
  static let vary = HTTPField.Name("Vary")!
}

/// Enforces the configured Origin policy and answers CORS for browser
/// clients. Requests without an Origin header (native apps, curl) pass
/// unless `requireOrigin` is set. Custom implementation (not hummingbird's
/// CORSMiddleware) so refusals are 403s and DPoP-Nonce is always exposed.
struct OriginPolicyMiddleware<Context: RequestContext>: RouterMiddleware {
  let allowedOrigins: Set<String>
  let requireOrigin: Bool

  func handle(
    _ request: Request, context: Context,
    next: (Request, Context) async throws -> Response
  ) async throws -> Response {
    let origin = request.headers[Header.origin]

    if requireOrigin, origin == nil {
      return Self.forbidden("Origin header required")
    }
    if let origin, !allowedOrigins.contains(origin), !allowedOrigins.contains("*") {
      // With no configured origins, any browser origin is refused —
      // configure allowed_origins to serve browser clients. A literal "*"
      // entry allows any origin through, but the response below always
      // echoes the concrete request Origin (never the literal "*"), since
      // credentialed/DPoP requests require a specific origin value.
      return Self.forbidden("origin not allowed")
    }

    if request.method == .options, let origin {
      var headers = HTTPFields()
      headers[Header.allowOrigin] = origin
      headers[Header.allowMethods] = "POST, GET, OPTIONS"
      headers[Header.allowHeaders] = "Content-Type, DPoP"
      headers[Header.exposeHeaders] = "DPoP-Nonce"
      headers[Header.maxAge] = "3600"
      headers[Header.vary] = "Origin"
      return Response(status: .noContent, headers: headers)
    }

    var response = try await next(request, context)
    if let origin {
      response.headers[Header.allowOrigin] = origin
      response.headers[Header.exposeHeaders] = "DPoP-Nonce"
      response.headers[Header.vary] = "Origin"
    }
    return response
  }

  static func forbidden(_ detail: String) -> Response {
    let body = #"{"error":"access_denied","error_description":"\#(detail)"}"#
    return Response(
      status: .forbidden,
      headers: [.contentType: "application/json"],
      body: .init(byteBuffer: ByteBuffer(string: body))
    )
  }
}
