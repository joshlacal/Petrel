import Foundation
@testable import Petrel
import Testing

@Suite("OAuth granted scope tests")
struct OAuthGrantedScopeTests {
  @Test("token response preserves exact granted scopes")
  func tokenResponsePreservesGrantedScopes() throws {
    let response = try JSONDecoder().decode(
      TokenResponse.self,
      from: tokenResponse(scope: "atproto repo:app.bsky.feed.post space")
    )

    #expect(response.grantedScopes == ["atproto", "repo:app.bsky.feed.post", "space"])
  }

  @Test("token response rejects a missing scope")
  func tokenResponseRejectsMissingScope() {
    let data = Data(
      #"{"access_token":"access","token_type":"DPoP","expires_in":3600,"refresh_token":"refresh","sub":"did:plc:test"}"#
        .utf8
    )

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(TokenResponse.self, from: data)
    }
  }

  @Test("token response rejects a scope without atproto")
  func tokenResponseRejectsMissingAtproto() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        TokenResponse.self,
        from: tokenResponse(scope: "repo:app.bsky.feed.post space")
      )
    }
  }

  @Test("sessions written before granted scope persistence remain readable")
  func legacySessionRemainsReadable() throws {
    let data = Data(
      #"{"accessToken":"access","refreshToken":"refresh","createdAt":0,"expiresIn":3600,"tokenType":"dpop","did":"did:plc:test"}"#
        .utf8
    )

    let session = try JSONDecoder().decode(Session.self, from: data)
    #expect(session.grantedScopes.isEmpty)
  }

  @Test("session round-trips its granted scope set through Codable")
  func sessionRoundTripsGrantedScopes() throws {
    let session = Session(
      accessToken: "access",
      refreshToken: "refresh",
      createdAt: Date(timeIntervalSince1970: 0),
      expiresIn: 3600,
      tokenType: .dpop,
      did: "did:plc:test",
      grantedScopes: ["atproto", "transition:generic"]
    )

    let decoded = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
    #expect(decoded.grantedScopes == ["atproto", "transition:generic"])
    #expect(decoded == session)
  }

  private func tokenResponse(scope: String) -> Data {
    Data(
      """
      {
        "access_token": "access",
        "token_type": "DPoP",
        "expires_in": 3600,
        "refresh_token": "refresh",
        "scope": "\(scope)",
        "sub": "did:plc:test"
      }
      """.utf8
    )
  }
}
