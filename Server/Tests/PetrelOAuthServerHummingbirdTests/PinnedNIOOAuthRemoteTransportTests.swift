import Crypto
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import PetrelOAuthServer
import PetrelOAuthServerHummingbird
import Testing
import X509

/// A one-route HTTPS server on 127.0.0.1 presenting the certificate for `name`.
private final class TLSFixtureServer: Sendable {
  let channel: any Channel
  var port: Int { channel.localAddress!.port! }

  init(name: String, body: Data) async throws {
    let leaf = try Fixtures.authority.issue(for: name)
    let certificate = try NIOSSLCertificate(bytes: Array(leaf.certificatePEM.utf8), format: .pem)
    let key = try NIOSSLPrivateKey(bytes: Array(leaf.keyPEM.utf8), format: .pem)
    let context = try NIOSSLContext(
      configuration: .makeServerConfiguration(
        certificateChain: [.certificate(certificate)], privateKey: .privateKey(key)
      )
    )
    channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
      .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        channel.eventLoop.makeCompletedFuture {
          try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: context))
          try channel.pipeline.syncOperations.configureHTTPServerPipeline()
          try channel.pipeline.syncOperations.addHandler(Responder(body: body))
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
    let body: Data

    init(body: Data) { self.body = body }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      guard case let .head(request) = unwrapInboundIn(data) else { return }
      var headers = HTTPHeaders()
      headers.add(name: "Content-Type", value: "application/json")
      headers.add(name: "Content-Length", value: "\(body.count)")
      headers.add(name: "X-Seen-Host", value: request.headers["Host"].first ?? "")
      context.write(wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: .ok, headers: headers))), promise: nil)
      context.write(wrapOutboundOut(.body(.byteBuffer(ByteBuffer(bytes: body)))), promise: nil)
      context.writeAndFlush(wrapOutboundOut(.end(nil))).assumeIsolated().whenComplete { _ in context.close(promise: nil) }
    }
  }
}

/// A certificate authority made for one test run and trusted only by it.
/// Nothing is written to disk.
private struct TestAuthority: Sendable {
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

private enum Fixtures {
  static let authority: TestAuthority = try! TestAuthority()

  static func transport() throws -> PinnedNIOOAuthRemoteTransport {
    try PinnedNIOOAuthRemoteTransport(
      trustRoots: .certificates([NIOSSLCertificate(bytes: Array(authority.certificatePEM.utf8), format: .pem)])
    )
  }
}

@Suite("PinnedNIOOAuthRemoteTransport: connects only to approved addresses")
struct PinnedNIOOAuthRemoteTransportTests {
  private let loopback: Set<OAuthIPAddress> = [OAuthIPAddress(literal: "127.0.0.1")!]

  @Test("it connects to the approved address, never resolving the name, and still checks TLS for the name")
  func connectsToApprovedAddress() async throws {
    let body = Data(#"{"ok":true}"#.utf8)
    let server = try await TLSFixtureServer(name: "pinned.example.test", body: body)
    defer { Task { try? await server.close() } }
    // pinned.example.test resolves nowhere (.test is reserved), so a transport
    // that looked the name up could not have reached the server.
    let url = try #require(URL(string: "https://pinned.example.test:\(server.port)/client-metadata.json"))
    let transport = try Fixtures.transport()
    #expect(transport.pinsConnectionsToApprovedPeers)
    let response = try await transport.get(url: url, approvedPeers: loopback, timeout: 5, maximumBodyBytes: 1024)
    #expect(response.status == 200)
    #expect(response.body == body)
    #expect(response.connectedPeerAddress == OAuthIPAddress(literal: "127.0.0.1"))
    #expect(response.headers["content-type"] == ["application/json"])
    #expect(response.headers["x-seen-host"] == ["pinned.example.test:\(server.port)"])
  }

  @Test("a certificate for another name is refused")
  func wrongCertificateName() async throws {
    let server = try await TLSFixtureServer(name: "other.example.test", body: Data("{}".utf8))
    defer { Task { try? await server.close() } }
    let url = try #require(URL(string: "https://pinned.example.test:\(server.port)/client-metadata.json"))
    let error = await #expect(throws: (any Error).self) {
      _ = try await Fixtures.transport().get(url: url, approvedPeers: loopback, timeout: 5, maximumBodyBytes: 1024)
    }
    // Refused by the TLS layer, not by anything after the handshake.
    #expect(error is NIOSSLError || error is NIOSSLExtraError, "\(String(describing: error))")
  }

  @Test("a body over the limit is refused")
  func oversizedBody() async throws {
    let server = try await TLSFixtureServer(name: "pinned.example.test", body: Data(repeating: 0x20, count: 4096))
    defer { Task { try? await server.close() } }
    let url = try #require(URL(string: "https://pinned.example.test:\(server.port)/client-metadata.json"))
    await #expect(throws: OAuthServerError.self) {
      _ = try await Fixtures.transport().get(url: url, approvedPeers: loopback, timeout: 5, maximumBodyBytes: 1024)
    }
  }

  @Test("with no approved address nothing is attempted")
  func noApprovedAddress() async throws {
    let url = try #require(URL(string: "https://pinned.example.test/client-metadata.json"))
    await #expect(throws: OAuthServerError.self) {
      _ = try await Fixtures.transport().get(url: url, approvedPeers: [], timeout: 5, maximumBodyBytes: 1024)
    }
  }

  @Test("the fetcher accepts it under the default policy and fetches through it end to end")
  func throughFetcher() async throws {
    let body = Data(#"{"client_id":"x"}"#.utf8)
    let server = try await TLSFixtureServer(name: "pinned.example.test", body: body)
    defer { Task { try? await server.close() } }
    let fetcher = try OAuthRemoteDocumentFetcher(
      policy: OAuthRemoteFetchPolicy(networkAllowlist: .init(addresses: loopback)),
      resolver: FixedResolver(),
      transport: Fixtures.transport()
    )
    let url = try #require(URL(string: "https://pinned.example.test:\(server.port)/client-metadata.json"))
    #expect(try await fetcher.fetchJSON(from: url) == body)
  }

  private struct FixedResolver: OAuthHostnameResolving {
    func resolve(host _: String) async throws -> [OAuthIPAddress] {
      [OAuthIPAddress(literal: "127.0.0.1")!]
    }
  }
}
