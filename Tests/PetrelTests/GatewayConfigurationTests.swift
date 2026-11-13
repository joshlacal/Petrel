import Foundation
@testable import Petrel
import Testing

@Suite("GatewayConfiguration")
struct GatewayConfigurationTests {
    private static let gateway = URL(string: "https://api.example.com")!
    private static let callback = URL(string: "https://app.example.com/oauth/callback")!
    private static let permission = URL(string: "https://app.example.com/oauth/permission-callback")!

    private func configuration(
        callback: URL = Self.callback,
        permission: URL = Self.permission
    ) throws -> GatewayConfiguration {
        try GatewayConfiguration(gatewayURL: Self.gateway, callbackURL: callback, permissionCallbackURL: permission)
    }

    @Test("Accepts exact https callbacks and keeps every value as given")
    func acceptsExactHTTPSCallbacks() throws {
        let config = try configuration()
        #expect(config.gatewayURL == Self.gateway)
        #expect(config.callbackURL == Self.callback)
        #expect(config.permissionCallbackURL == Self.permission)
        #expect(config.callbackOrigin == "https://app.example.com")
        #expect(config.permissionCallbackOrigin == "https://app.example.com")
    }

    @Test(
        "Rejects callbacks that are not exact https URLs",
        arguments: [
            "http://app.example.com/oauth/callback",
            "app.example://oauth/callback",
            "https:///oauth/callback",
            "https://user@app.example.com/oauth/callback",
            "https://user:pw@app.example.com/oauth/callback",
            "https://app.example.com/oauth/callback?x=1",
            "https://app.example.com/oauth/callback#frag",
            "/oauth/callback",
        ]
    )
    func rejectsInexactCallbacks(_ raw: String) throws {
        let bad = try #require(URL(string: raw))
        #expect(throws: GatewayConfiguration.ValidationError.invalidCallbackURL(bad)) {
            try configuration(callback: bad)
        }
        #expect(throws: GatewayConfiguration.ValidationError.invalidPermissionCallbackURL(bad)) {
            try configuration(permission: bad)
        }
    }

    @Test("Origin includes a non-default port and lowercases the host")
    func originCarriesNonDefaultPort() throws {
        let config = try configuration(
            callback: URL(string: "https://App.Example.com:8443/cb")!,
            permission: URL(string: "https://app.example.com:443/pcb")!
        )
        #expect(config.callbackOrigin == "https://app.example.com:8443")
        #expect(config.permissionCallbackOrigin == "https://app.example.com")
    }

    @Test("Callback matching: same scheme, host in any case, effective port and path; no user info or fragment")
    func callbackMatchingIsExact() throws {
        let config = try configuration()
        let accepted = [
            "https://app.example.com/oauth/callback",
            "https://APP.example.com/oauth/callback?code=c&state=s",
            "https://app.example.com:443/oauth/callback?code=c",
        ]
        let rejected = [
            "http://app.example.com/oauth/callback",
            "https://app.example.com.evil.com/oauth/callback",
            "https://evil.com/oauth/callback",
            "https://app.example.com:8443/oauth/callback",
            "https://app.example.com/oauth/callback/",
            "https://app.example.com/OAUTH/callback",
            "https://app.example.com/oauth/permission-callback",
            "https://user@app.example.com/oauth/callback",
            "https://app.example.com/oauth/callback#code=c",
        ]
        for raw in accepted {
            #expect(config.isSignInCallback(URL(string: raw)!), "\(raw)")
        }
        for raw in rejected {
            #expect(!config.isSignInCallback(URL(string: raw)!), "\(raw)")
        }
        #expect(config.isPermissionCallback(Self.permission))
        #expect(!config.isPermissionCallback(Self.callback))
    }

    @Test("A configured non-default port must match exactly")
    func nonDefaultPortMustMatch() throws {
        let config = try configuration(callback: URL(string: "https://app.example.com:8443/cb")!)
        #expect(config.isSignInCallback(URL(string: "https://app.example.com:8443/cb?code=c")!))
        #expect(!config.isSignInCallback(URL(string: "https://app.example.com/cb?code=c")!))
    }

    @Test("Gateway mode carries its configuration and compares by value")
    func authModeCarriesConfiguration() throws {
        let config = try configuration()
        #expect(AuthMode.gateway(config) == AuthMode.gateway(try configuration()))
        #expect(AuthMode.gateway(config) != AuthMode.publicOAuth)
    }
}
