#if OAuthServerHummingbird
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
        ///
        /// The client's address reaches the server as
        /// ``OAuthHTTPRequest/remoteAddress`` and from there the account
        /// authenticator, which needs it to limit sign-in attempts. It is read from
        /// the connection when `Context` conforms to `RemoteAddressRequestContext`
        /// (``OAuthServerRequestContext`` does; Hummingbird's `BasicRequestContext`
        /// does not), and from `X-Forwarded-For` only as `clientAddress` allows.
        public static func addRoutes<Context: RequestContext>(
            to router: Router<Context>,
            server: OAuthAuthorizationServer,
            maximumBodyBytes: Int = 64 * 1024,
            clientAddress: OAuthClientAddressPolicy = .connection
        ) {
            for route in OAuthAuthorizationServer.routes {
                guard let method = HTTPRequest.Method(route.method) else { continue }
                router.on(RouterPath(route.path), method: method) { request, context -> Response in
                    let peer = (context as? any RemoteAddressRequestContext)?.remoteAddress?.ipAddress
                    guard let converted = await convert(
                        request,
                        maximumBodyBytes: maximumBodyBytes,
                        remoteAddress: clientAddress.clientAddress(peer: peer, headers: headers(request))
                    ) else {
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

        static func convert(_ request: Request, maximumBodyBytes: Int, remoteAddress: String?) async -> OAuthHTTPRequest? {
            var request = request
            guard let buffer = try? await request.collectBody(upTo: maximumBodyBytes) else { return nil }
            return OAuthHTTPRequest(
                method: request.method.rawValue,
                path: request.uri.path,
                query: request.uri.query,
                headers: headers(request),
                body: Data(buffer.readableBytesView),
                remoteAddress: remoteAddress
            )
        }
    }

    /// Where the adapter takes the client's network address from.
    public enum OAuthClientAddressPolicy: Sendable, Equatable {
        /// The address of the connection's peer. Correct when clients connect to
        /// this process directly.
        case connection
        /// Behind reverse proxies: when the connection comes from one of
        /// `trustedProxies` (literal IP addresses), the address is the right-most
        /// `X-Forwarded-For` entry that is not itself a trusted proxy. A request
        /// from any other peer is attributed to that peer, so a client cannot
        /// choose its own address by sending the header.
        case forwardedFor(trustedProxies: Set<String>)

        /// The client address for a request from `peer` with `headers`.
        public func clientAddress(peer: String?, headers: OAuthHTTPHeaders) -> String? {
            guard case let .forwardedFor(trustedProxies) = self, let peer, trustedProxies.contains(peer) else {
                return peer
            }
            // Every X-Forwarded-For field, in order; each proxy appends on the right.
            let hops = headers.values(for: "X-Forwarded-For")
                .flatMap { $0.split(separator: ",") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
            for hop in hops.reversed() where !trustedProxies.contains(hop) {
                return hop.isEmpty ? peer : hop
            }
            return peer
        }
    }

    /// A Hummingbird request context that records the connection's peer address,
    /// so ``OAuthServerHummingbird/addRoutes(to:server:maximumBodyBytes:clientAddress:)``
    /// can pass it to the authorization server.
    public struct OAuthServerRequestContext: RequestContext, RemoteAddressRequestContext {
        /// Hummingbird's per-request storage.
        public var coreContext: CoreRequestContextStorage
        /// The connection's peer.
        public let remoteAddress: SocketAddress?

        /// Creates the context for a request on `source.channel`.
        public init(source: ApplicationRequestContextSource) {
            coreContext = .init(source: source)
            remoteAddress = source.channel.remoteAddress
        }
    }

    /// The response to send when a resource request is not authorized: `401` or
    /// `403` with the `WWW-Authenticate: DPoP` challenge and a fresh nonce.
    public struct OAuthResourceChallenge: Error, Sendable {
        /// The challenge response.
        public let response: Response
    }
#endif
