import Crypto
import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import PetrelOAuthServer
import PetrelOAuthServerHummingbird
import X509

/// An HTTPS server on 127.0.0.1 presenting a certificate for `name`, issued by
/// the run's test authority. It serves `documents` by path, and `fallback`
/// for any other path (404 without one), and records the paths requested.
final class TLSFixtureServer: Sendable {
  let channel: any Channel
  private let requested: NIOLockedValueBox<[String]>
  var port: Int { channel.localAddress!.port! }
  /// The paths requested so far, in order.
  var requestedPaths: [String] { requested.withLockedValue { $0 } }

  convenience init(name: String, body: Data) async throws {
    try await self.init(name: name, documents: [:], fallback: body)
  }

  init(name: String, documents: [String: Data], fallback: Data? = nil) async throws {
    let leaf = try TLSFixtures.authority.issue(for: name)
    let certificate = try NIOSSLCertificate(bytes: Array(leaf.certificatePEM.utf8), format: .pem)
    let key = try NIOSSLPrivateKey(bytes: Array(leaf.keyPEM.utf8), format: .pem)
    let context = try NIOSSLContext(
      configuration: .makeServerConfiguration(
        certificateChain: [.certificate(certificate)], privateKey: .privateKey(key)
      )
    )
    let requested = NIOLockedValueBox<[String]>([])
    self.requested = requested
    channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
      .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        channel.eventLoop.makeCompletedFuture {
          try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: context))
          try channel.pipeline.syncOperations.configureHTTPServerPipeline()
          try channel.pipeline.syncOperations.addHandler(
            Responder(documents: documents, fallback: fallback, requested: requested)
          )
        }
      }
      .bind(host: "127.0.0.1", port: 0)
      .get()
  }

  func close() async throws {
    try await channel.close()
  }

  private final class Responder: ChannelInboundHandler, Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    let documents: [String: Data]
    let fallback: Data?
    let requested: NIOLockedValueBox<[String]>

    init(documents: [String: Data], fallback: Data?, requested: NIOLockedValueBox<[String]>) {
      self.documents = documents
      self.fallback = fallback
      self.requested = requested
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      guard case let .head(request) = unwrapInboundIn(data) else { return }
      let path = String(request.uri.prefix { $0 != "?" })
      requested.withLockedValue { $0.append(path) }
      let body = documents[path] ?? fallback
      var headers = HTTPHeaders()
      headers.add(name: "Content-Type", value: "application/json")
      headers.add(name: "Content-Length", value: "\(body?.count ?? 0)")
      headers.add(name: "X-Seen-Host", value: request.headers["Host"].first ?? "")
      let head = HTTPResponseHead(version: .http1_1, status: body == nil ? .notFound : .ok, headers: headers)
      context.write(wrapOutboundOut(.head(head)), promise: nil)
      if let body {
        context.write(wrapOutboundOut(.body(.byteBuffer(ByteBuffer(bytes: body)))), promise: nil)
      }
      context.writeAndFlush(wrapOutboundOut(.end(nil))).assumeIsolated().whenComplete { _ in context.close(promise: nil) }
    }
  }
}

/// A certificate authority made for one test run and trusted only by it.
/// Nothing is written to disk.
struct TestAuthority: Sendable {
  let certificatePEM: String
  private let name: DistinguishedName
  private let keyPEM: String

  init() throws {
    let key = P256.Signing.PrivateKey()
    name = try DistinguishedName { CommonName("Petrel test CA") }
    let now = Date()
    let certificate = try Certificate(
      version: .v3,
      serialNumber: Certificate.SerialNumber(),
      publicKey: Certificate.PublicKey(key.publicKey),
      notValidBefore: now.addingTimeInterval(-3600),
      notValidAfter: now.addingTimeInterval(3600),
      issuer: name,
      subject: name,
      signatureAlgorithm: .ecdsaWithSHA256,
      extensions: Certificate.Extensions {
        Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
        Critical(KeyUsage(keyCertSign: true))
      },
      issuerPrivateKey: Certificate.PrivateKey(key)
    )
    certificatePEM = try certificate.serializeAsPEM().pemString
    keyPEM = key.pemRepresentation
  }

  /// A server certificate for `dnsName`, and its private key.
  func issue(for dnsName: String) throws -> (certificatePEM: String, keyPEM: String) {
    let issuerKey = try P256.Signing.PrivateKey(pemRepresentation: keyPEM)
    let key = P256.Signing.PrivateKey()
    let now = Date()
    let certificate = try Certificate(
      version: .v3,
      serialNumber: Certificate.SerialNumber(),
      publicKey: Certificate.PublicKey(key.publicKey),
      notValidBefore: now.addingTimeInterval(-3600),
      notValidAfter: now.addingTimeInterval(3600),
      issuer: name,
      subject: DistinguishedName { CommonName(dnsName) },
      signatureAlgorithm: .ecdsaWithSHA256,
      extensions: Certificate.Extensions {
        Critical(BasicConstraints.notCertificateAuthority)
        SubjectAlternativeNames([.dnsName(dnsName)])
        try ExtendedKeyUsage([.serverAuth])
      },
      issuerPrivateKey: Certificate.PrivateKey(issuerKey)
    )
    return (try certificate.serializeAsPEM().pemString, key.pemRepresentation)
  }
}

enum TLSFixtures {
  static let authority: TestAuthority = try! TestAuthority()

  /// The loopback TLS server answers at once; a stalled CI runner freezes both
  /// ends while the clock runs, so a short deadline would turn the stall into a
  /// timeout instead of the outcome each test checks.
  static let exchangeTimeout: TimeInterval = 5 * 60

  /// The pinned transport, trusting only the run's test authority.
  static func transport() throws -> PinnedNIOOAuthRemoteTransport {
    try PinnedNIOOAuthRemoteTransport(
      trustRoots: .certificates([NIOSSLCertificate(bytes: Array(authority.certificatePEM.utf8), format: .pem)])
    )
  }

  /// A fetcher with the default policy, except that loopback is allowed and
  /// every name resolves to 127.0.0.1, over the pinned transport. Requests
  /// for `https://<name>/<path>` (no port, as client IDs must be) reach the
  /// fixture server on `port`.
  static func fetcher(reaching port: Int) throws -> OAuthRemoteDocumentFetcher {
    try OAuthRemoteDocumentFetcher(
      policy: OAuthRemoteFetchPolicy(networkAllowlist: .init(addresses: [OAuthIPAddress(literal: "127.0.0.1")!])),
      resolver: LoopbackResolver(),
      transport: PortMappingTransport(inner: transport(), port: port)
    )
  }

  struct LoopbackResolver: OAuthHostnameResolving {
    func resolve(host _: String) async throws -> [OAuthIPAddress] {
      [OAuthIPAddress(literal: "127.0.0.1")!]
    }
  }

  /// Sends each request to `port` instead of 443. The name, and so the TLS
  /// server name and certificate check, are unchanged.
  struct PortMappingTransport: OAuthRemoteTransport {
    let inner: PinnedNIOOAuthRemoteTransport
    let port: Int

    var pinsConnectionsToApprovedPeers: Bool { inner.pinsConnectionsToApprovedPeers }

    func get(
      url: URL,
      approvedPeers: Set<OAuthIPAddress>,
      timeout: TimeInterval,
      maximumBodyBytes: Int
    ) async throws -> OAuthRemoteHTTPResponse {
      guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.port == nil else {
        throw OAuthServerError.malformed("fixture URLs carry no port")
      }
      components.port = port
      guard let mapped = components.url else { throw OAuthServerError.malformed("fixture URL") }
      let response = try await inner.get(
        url: mapped, approvedPeers: approvedPeers, timeout: timeout, maximumBodyBytes: maximumBodyBytes
      )
      // Report the URL as asked for; everything else is the real response.
      guard response.responseURL == mapped else { return response }
      return OAuthRemoteHTTPResponse(
        status: response.status,
        headers: response.headers,
        body: response.body,
        responseURL: url,
        redirectCount: response.redirectCount,
        connectedPeerAddress: response.connectedPeerAddress
      )
    }
  }
}
