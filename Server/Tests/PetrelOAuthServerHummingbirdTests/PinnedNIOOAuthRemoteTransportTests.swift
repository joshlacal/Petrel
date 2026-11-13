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
    let transport = try TLSFixtures.transport()
    #expect(transport.pinsConnectionsToApprovedPeers)
    let response = try await transport.get(url: url, approvedPeers: loopback, timeout: TLSFixtures.exchangeTimeout, maximumBodyBytes: 1024)
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
      _ = try await TLSFixtures.transport().get(url: url, approvedPeers: loopback, timeout: TLSFixtures.exchangeTimeout, maximumBodyBytes: 1024)
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
      _ = try await TLSFixtures.transport().get(url: url, approvedPeers: loopback, timeout: TLSFixtures.exchangeTimeout, maximumBodyBytes: 1024)
    }
  }

  @Test("with no approved address nothing is attempted")
  func noApprovedAddress() async throws {
    let url = try #require(URL(string: "https://pinned.example.test/client-metadata.json"))
    await #expect(throws: OAuthServerError.self) {
      _ = try await TLSFixtures.transport().get(url: url, approvedPeers: [], timeout: TLSFixtures.exchangeTimeout, maximumBodyBytes: 1024)
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
      transport: TLSFixtures.transport()
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
