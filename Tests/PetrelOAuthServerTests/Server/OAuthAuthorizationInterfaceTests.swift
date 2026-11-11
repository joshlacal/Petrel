import Foundation
@testable import PetrelOAuthServer
import Testing

@Suite("Authorization server: Authorization Interface")
struct OAuthAuthorizationInterfaceTests {
    private typealias Path = OAuthAuthorizationServer.Path

    @Test("the authorization endpoint refuses a request that is not a pushed request")
    func nonPARRefused() async throws {
        let harness = try TestServer()
        let response = await harness.get(
            Path.authorize,
            query: "client_id=\(OAuthForm.encodeComponent(TestServer.webClientID))&response_type=code&scope=atproto"
                + "&redirect_uri=\(OAuthForm.encodeComponent(TestServer.webRedirect))&state=x&code_challenge=y"
        )
        #expect(response.status == 400)
        #expect(response.headers["Location"] == nil, "an unverified request is never redirected")
        #expect(response.text.contains("pushed authorization"))
    }

    @Test("an unknown, foreign or expired request_uri shows an error page and never redirects")
    func invalidRequestURI() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let requestURI = try await client.pushRequest()
        let browser = TestBrowser(harness)

        let unknown = await browser.open(
            requestURI: "urn:ietf:params:oauth:request_uri:" + String(repeating: "A", count: 43), clientID: client.clientID
        )
        #expect(unknown.status == 400)
        let foreign = await browser.open(requestURI: requestURI, clientID: TestServer.confidentialClientID)
        #expect(foreign.status == 400)
        harness.clock.advance(301)
        let expired = await browser.open(requestURI: requestURI, clientID: client.clientID)
        #expect(expired.status == 400)
        for response in [unknown, foreign, expired] {
            #expect(response.headers["Location"] == nil)
        }
    }

    @Test("pages carry clickjacking, caching and content-security headers")
    func securityHeaders() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let page = try await TestBrowser(harness).open(requestURI: client.pushRequest(), clientID: client.clientID)
        #expect(page.status == 200)
        #expect(page.headers["X-Frame-Options"] == "DENY")
        #expect(page.headers["Cache-Control"] == "no-store")
        #expect(page.headers["Referrer-Policy"] == "no-referrer")
        #expect(page.headers["X-Content-Type-Options"] == "nosniff")
        let csp = try #require(page.headers["Content-Security-Policy"])
        #expect(csp.contains("frame-ancestors 'none'"))
        #expect(csp.contains("default-src 'none'"))
        #expect(csp.contains("form-action 'self' https://app.example.test"))
        let cookie = try #require(page.headers.values(for: "Set-Cookie").first)
        #expect(cookie.contains("HttpOnly") && cookie.contains("Secure") && cookie.contains("SameSite=Lax"))
        #expect(cookie.contains("Path=/oauth/authorize"))
    }

    @Test("approval redirects with 303 to the exact redirect_uri carrying code, state and iss")
    func approvalRedirect() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let browser = TestBrowser(harness)
        await browser.open(requestURI: try await client.pushRequest(), clientID: client.clientID)
        let consent = await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "alice-password")])
        #expect(consent.status == 200)
        #expect(consent.text.contains("alice.test"))
        #expect(consent.text.contains("Broad access"), "the consent page describes the requested scopes")
        let response = await browser.submit(Path.consent, [("decision", "approve")])
        #expect(response.status == 303)
        let location = try #require(response.headers["Location"])
        #expect(location.hasPrefix(TestServer.webRedirect + "?"))
        let parameters = TestBrowser.redirectParameters(response)
        #expect(parameters["state"] == client.state)
        #expect(parameters["iss"] == TestServer.issuer)
        #expect(parameters["code"]?.count == 43)
        #expect(parameters["error"] == nil)
    }

    @Test("response_mode=fragment returns the parameters in the fragment, as browser clients ask")
    func fragmentResponseMode() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let browser = TestBrowser(harness)
        await browser.open(
            requestURI: try await client.pushRequest(overrides: ["response_mode": "fragment"]), clientID: client.clientID
        )
        await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "alice-password")])
        let response = await browser.submit(Path.consent, [("decision", "approve")])
        let location = try #require(response.headers["Location"])
        #expect(location.hasPrefix(TestServer.webRedirect + "#"))
        #expect(!location.contains("?"))
        let fragment = try #require(URLComponents(string: location)?.fragment)
        let parameters = try #require(URLComponents(string: "?" + fragment)?.queryItems)
        #expect(parameters.first { $0.name == "iss" }?.value == TestServer.issuer)
        #expect(parameters.first { $0.name == "state" }?.value == client.state)
        let code = try #require(parameters.first { $0.name == "code" }?.value)
        #expect(try await client.exchange(code: code).status == 200)
    }

    @Test("denial redirects with access_denied, state and iss, and issues no code")
    func denial() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let browser = TestBrowser(harness)
        await browser.open(requestURI: try await client.pushRequest(), clientID: client.clientID)
        await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "alice-password")])
        let response = await browser.submit(Path.consent, [("decision", "deny")])
        #expect(response.status == 303)
        let parameters = TestBrowser.redirectParameters(response)
        #expect(parameters["error"] == "access_denied")
        #expect(parameters["state"] == client.state)
        #expect(parameters["iss"] == TestServer.issuer)
        #expect(parameters["code"] == nil)
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).isEmpty)
    }

    @Test("a request_uri yields at most one code")
    func requestURISingleUse() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let requestURI = try await client.pushRequest()
        let browser = TestBrowser(harness)
        _ = try await browser.approve(
            requestURI: requestURI, clientID: client.clientID, account: TestAccounts.alice, password: "alice-password"
        )
        let again = await browser.open(requestURI: requestURI, clientID: client.clientID)
        #expect(again.status == 400)
    }

    @Test("wrong credentials re-show the sign-in page and never reach consent")
    func wrongPassword() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let browser = TestBrowser(harness)
        await browser.open(requestURI: try await client.pushRequest(), clientID: client.clientID)
        let response = await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "nope")])
        #expect(response.status == 401)
        #expect(response.text.contains("name=\"password\""))
        let consent = await browser.submit(Path.consent, [("decision", "approve")])
        #expect(consent.status == 400, "consent without an authenticated account is refused")
        #expect(consent.headers["Location"] == nil)
    }

    @Test("forms require the CSRF token, the flow cookie and a same-origin submission")
    func csrfProtection() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let requestURI = try await client.pushRequest()
        let credentials = [("identifier", "alice.test"), ("password", "alice-password")]

        let wrongToken = TestBrowser(harness)
        await wrongToken.open(requestURI: requestURI, clientID: client.clientID)
        #expect(await wrongToken.submit(Path.signIn, credentials, csrf: "forged").status == 400)

        let noCookie = TestBrowser(harness)
        await noCookie.open(requestURI: requestURI, clientID: client.clientID)
        let token = noCookie.csrf
        noCookie.cookies = [:]
        #expect(await noCookie.submit(Path.signIn, credentials, csrf: token).status == 400)

        let crossSite = TestBrowser(harness)
        await crossSite.open(requestURI: requestURI, clientID: client.clientID)
        let forged = await harness.post(
            Path.signIn, [("csrf", crossSite.csrf)] + credentials,
            headers: [
                ("Cookie", crossSite.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")),
                ("Origin", "https://attacker.example"),
            ]
        )
        #expect(forged.status == 403)
        #expect(harness.accounts.signInAttempts == 0, "no rejected form reached the account system")
    }

    @Test("login_hint pre-fills the identifier and restricts the request to that account")
    func loginHint() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let requestURI = try await client.pushRequest(overrides: ["login_hint": "alice.test"])
        let browser = TestBrowser(harness)
        let page = await browser.open(requestURI: requestURI, clientID: client.clientID)
        #expect(page.text.contains("value=\"alice.test\""))
        let asBob = await browser.submit(Path.signIn, [("identifier", "bob.test"), ("password", "bob-password")])
        #expect(asBob.status == 403)
        #expect(asBob.text.contains("different account"))
        let asAlice = await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "alice-password")])
        #expect(asAlice.status == 200)
        #expect(asAlice.text.contains("name=\"decision\""))
    }

    @Test("a browser that already signed in is offered account selection, without a password")
    func accountSelection() async throws {
        let harness = try TestServer()
        let browser = TestBrowser(harness)
        let first = try TestClient(harness)
        _ = try await browser.approve(
            requestURI: first.pushRequest(), clientID: first.clientID,
            account: TestAccounts.alice, password: "alice-password"
        )
        let attempts = harness.accounts.signInAttempts

        let second = try TestClient.loopback(harness)
        let page = await browser.open(requestURI: try await second.pushRequest(), clientID: second.clientID)
        #expect(page.text.contains("name=\"account\" value=\"\(TestAccounts.alice.did)\""))
        // An account this browser never signed in to cannot be selected.
        let forged = await browser.submit(Path.selectAccount, [("account", TestAccounts.bob.did)])
        #expect(forged.status == 400)
        let consent = await browser.submit(Path.selectAccount, [("account", TestAccounts.alice.did)])
        #expect(consent.text.contains("name=\"decision\""))
        let response = await browser.submit(Path.consent, [("decision", "approve")])
        #expect(TestBrowser.redirectParameters(response)["code"] != nil)
        #expect(harness.accounts.signInAttempts == attempts)

        // "Use another account" returns to the sign-in form.
        let third = try TestClient(harness)
        await browser.open(requestURI: try await third.pushRequest(), clientID: third.clientID)
        let other = await browser.submit(Path.selectAccount, [("account", "")])
        #expect(other.text.contains("name=\"password\""))
    }

    @Test("a second factor is required before consent when the account system asks for one")
    func secondFactor() async throws {
        let harness = try TestServer()
        harness.accounts.requireSecondFactor(TestAccounts.alice.did, code: "246810")
        let client = try TestClient(harness)
        let browser = TestBrowser(harness)
        await browser.open(requestURI: try await client.pushRequest(), clientID: client.clientID)
        let challenge = await browser.submit(Path.signIn, [("identifier", "alice.test"), ("password", "alice-password")])
        #expect(challenge.text.contains("name=\"code\""))
        // Consent is not reachable with only the first factor.
        let probe = TestBrowser(harness)
        probe.cookies = browser.cookies
        probe.lastPage = browser.lastPage
        let early = await probe.submit(Path.consent, [("decision", "approve")])
        #expect(early.headers["Location"] == nil)
        let wrong = await browser.submit(Path.secondFactor, [("code", "000000")])
        #expect(wrong.status == 401)
        let right = await browser.submit(Path.secondFactor, [("code", "246810")])
        #expect(right.text.contains("name=\"decision\""))
        let done = await browser.submit(Path.consent, [("decision", "approve")])
        #expect(TestBrowser.redirectParameters(done)["code"] != nil)
    }

    @Test("an untrusted client's self-declared name and logo are not shown; its client_id always is")
    func untrustedClientPresentation() async throws {
        let untrusted = try TestServer()
        let client = try TestClient(untrusted)
        let page = try await TestBrowser(untrusted).open(requestURI: client.pushRequest(), clientID: client.clientID)
        #expect(page.text.contains(TestServer.webClientID))
        #expect(!page.text.contains("Example App"))
        #expect(!page.text.contains("logo.png"))

        let trusted = try TestServer(trustedClientIDs: [TestServer.webClientID])
        let trustedClient = try TestClient(trusted)
        let trustedPage = try await TestBrowser(trusted).open(
            requestURI: trustedClient.pushRequest(), clientID: trustedClient.clientID
        )
        #expect(trustedPage.text.contains(TestServer.webClientID))
        #expect(trustedPage.text.contains("Example App"))
    }

    @Test("the default pages escape everything they interpolate")
    func escaping() {
        let page = OAuthDefaultInterface(serviceName: "<b>svc</b>").render(
            .error(.init(title: "<script>alert(1)</script>", message: "a & b \"quoted\"")),
            nonce: "n", languages: []
        )
        #expect(!page.contains("<script>alert(1)</script>"))
        #expect(page.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(page.contains("a &amp; b &quot;quoted&quot;"))
        #expect(!page.contains("<b>svc</b>"))
    }

    @Test("a custom renderer replaces the pages and still receives the server's security headers")
    func customRenderer() async throws {
        struct Custom: OAuthInterfaceRendering {
            func render(_ page: OAuthInterfacePage, nonce _: String, languages _: [String]) -> String {
                if case let .signIn(model) = page {
                    return "CUSTOM sign-in for \(model.client.host) csrf name=\"csrf\" value=\"\(model.csrfToken)\""
                }
                return "CUSTOM"
            }
        }
        let base = try TestServer()
        let server = try OAuthAuthorizationServer(
            configuration: base.server.configuration, store: base.store, accounts: base.accounts,
            clients: base.clients, interface: Custom(), clock: base.clock
        )
        let client = try TestClient(base)
        let requestURI = try await client.pushRequest()
        let response = await server.handle(OAuthHTTPRequest(
            method: "GET", path: Path.authorize,
            query: "client_id=\(OAuthForm.encodeComponent(client.clientID))&request_uri=\(OAuthForm.encodeComponent(requestURI))"
        ))
        #expect(response.text.hasPrefix("CUSTOM sign-in for app.example.test"))
        #expect(response.headers["X-Frame-Options"] == "DENY")
    }

    @Test("a scope is marked sensitive by what it grants, not by whether its string contains *")
    func sensitivityByMeaning() throws {
        func sensitive(_ scope: String) throws -> Bool {
            let lines = OAuthScopeDescription.summarize(requestedScopes: ["atproto", scope])
            return try #require(lines.first { $0.scopes.contains(scope) }, "\(scope)").isSensitive
        }
        // Wildcards, however they are spelled.
        for scope in ["repo:*", "repo?collection=*", "repo?collection=%2A", "rpc:*?aud=did:web:api.example.com%23svc",
                      "rpc:app.example.getFeed?aud=*", "rpc?lxm=%2A&aud=did:web:api.example.com%23svc"]
        {
            if (try? ATProtoScope.parse(scope)) == nil { continue } // spelling the grammar refuses
            #expect(try sensitive(scope), "\(scope)")
        }
        // A specific grant, even with * or an escape inside a value.
        for scope in ["repo:app.bsky.feed.post", "rpc:app.example.getFeed?aud=did:web:api.example.com%23svc%2A"] {
            #expect(try !sensitive(scope), "\(scope)")
        }
    }
}
