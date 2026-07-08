#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Testing

@Suite("PAR parameter construction")
struct PARParameterTests {
  private func makeCore(namespace: String) -> OAuthCore {
    OAuthCore(
      storage: KeychainStorage(namespace: namespace),
      accountManager: MockAccountManager(
        account: Account(
          did: "did:plc:test",
          handle: "test.example",
          pdsURL: URL(string: "https://pds.test")!
        )
      ),
      networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
      oauthConfig: OAuthConfig(
        clientId: "https://client.example/oauth-client-metadata.json",
        redirectUri: "https://client.example/callback",
        scope: "atproto"
      ),
      didResolver: MockDIDResolver()
    )
  }

  @Test("Base parameters match today's PAR body when no extras are given")
  func baseParameters() async {
    let core = makeCore(namespace: "test.par.base")
    let params = await core.buildPARParameters(
      codeChallenge: "challenge123",
      identifier: "alice.test",
      state: "state456",
      additionalParameters: nil
    )
    #expect(params["client_id"] == "https://client.example/oauth-client-metadata.json")
    #expect(params["redirect_uri"] == "https://client.example/callback")
    #expect(params["response_type"] == "code")
    #expect(params["code_challenge_method"] == "S256")
    #expect(params["code_challenge"] == "challenge123")
    #expect(params["state"] == "state456")
    #expect(params["scope"] == "atproto")
    #expect(params["login_hint"] == "alice.test")
    #expect(params["client_assertion"] == nil)
    #expect(params.count == 8)
  }

  @Test("login_hint is omitted when identifier is nil")
  func noLoginHint() async {
    let core = makeCore(namespace: "test.par.nohint")
    let params = await core.buildPARParameters(
      codeChallenge: "c", identifier: nil, state: "s", additionalParameters: nil
    )
    #expect(params["login_hint"] == nil)
    #expect(params.count == 7)
  }

  @Test("Additional parameters merge in (client assertion case)")
  func additionalParametersMerged() async {
    let core = makeCore(namespace: "test.par.extra")
    let params = await core.buildPARParameters(
      codeChallenge: "c", identifier: nil, state: "s",
      additionalParameters: [
        "client_assertion": "eyJ.assertion.sig",
        "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      ]
    )
    #expect(params["client_assertion"] == "eyJ.assertion.sig")
    #expect(params["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
    #expect(params["client_id"] == "https://client.example/oauth-client-metadata.json")
    #expect(params.count == 9)
  }
}
