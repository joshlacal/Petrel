import Foundation

/// Where an app's own confidential-client gateway lives and which web callbacks it redirects to.
///
/// Gateway mode (``AuthMode/gateway(_:)``) is for apps that run their own confidential OAuth
/// gateway: a backend that performs AT Protocol OAuth (PAR, PKCE, DPoP) as a confidential client
/// and gives the app only an opaque session. Petrel contains no default gateway; every value
/// comes from the app.
///
/// - `gatewayURL` is the gateway's base URL. Petrel sends `auth/*` requests and, in gateway mode,
///   all XRPC traffic there. It must be `https`, or `http` on a loopback host for local testing;
///   this is checked when a flow starts, as before.
/// - `callbackURL` is the exact web URL the gateway redirects to after sign-in (for example a
///   universal link). Petrel accepts a sign-in callback only when its scheme, host, port and path
///   equal this URL, and sends this URL's origin as `Origin` on the code exchange.
/// - `permissionCallbackURL` is the same for progressive scope upgrades
///   (``ATProtoClient/startGatewayScopeUpgrade(requesting:for:callbackURL:)``).
///
/// Both callback URLs must be absolute `https` URLs with a host and no user info, query or
/// fragment.
///
/// ```swift
/// let gateway = try GatewayConfiguration(
///     gatewayURL: URL(string: "https://api.example.com")!,
///     callbackURL: URL(string: "https://example.com/oauth/callback")!,
///     permissionCallbackURL: URL(string: "https://example.com/oauth/permission-callback")!
/// )
/// let client = try await ATProtoClient(
///     oauthConfig: oauthConfig,
///     namespace: "com.example.app",
///     authMode: .gateway(gateway)
/// )
/// ```
public struct GatewayConfiguration: Sendable, Equatable {
    /// Why a ``GatewayConfiguration`` was rejected.
    public enum ValidationError: Error, Equatable, Sendable {
        /// `callbackURL` is not an absolute `https` URL with a host and without user info,
        /// query or fragment.
        case invalidCallbackURL(URL)
        /// `permissionCallbackURL` is not an absolute `https` URL with a host and without user
        /// info, query or fragment.
        case invalidPermissionCallbackURL(URL)
    }

    /// The gateway's base URL.
    public let gatewayURL: URL
    /// The exact web URL the gateway redirects to after sign-in.
    public let callbackURL: URL
    /// The exact web URL the gateway redirects to after a progressive scope upgrade.
    public let permissionCallbackURL: URL

    /// Creates a gateway configuration.
    /// - Throws: ``ValidationError`` when a callback URL is not an exact `https` URL.
    public init(gatewayURL: URL, callbackURL: URL, permissionCallbackURL: URL) throws {
        guard Self.isValidCallback(callbackURL) else {
            throw ValidationError.invalidCallbackURL(callbackURL)
        }
        guard Self.isValidCallback(permissionCallbackURL) else {
            throw ValidationError.invalidPermissionCallbackURL(permissionCallbackURL)
        }
        self.gatewayURL = gatewayURL
        self.callbackURL = callbackURL
        self.permissionCallbackURL = permissionCallbackURL
    }

    /// The web origin of ``callbackURL`` (`https://host[:port]`), sent as `Origin` on the
    /// sign-in code exchange.
    var callbackOrigin: String { Self.origin(of: callbackURL) }

    /// The web origin of ``permissionCallbackURL``, sent as `Origin` on the scope-upgrade
    /// code exchange.
    var permissionCallbackOrigin: String { Self.origin(of: permissionCallbackURL) }

    /// Whether `url` is the sign-in callback: https, same host (any case), same effective port,
    /// same path, and no user info or fragment. Query items are the caller's to check.
    func isSignInCallback(_ url: URL) -> Bool {
        Self.matchesExactly(url, base: callbackURL)
    }

    /// Whether `url` is the scope-upgrade callback, under the same rules as
    /// ``isSignInCallback(_:)``.
    func isPermissionCallback(_ url: URL) -> Bool {
        Self.matchesExactly(url, base: permissionCallbackURL)
    }

    private static func isValidCallback(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil
        else {
            return false
        }
        return true
    }

    private static func effectivePort(_ components: URLComponents) -> Int {
        components.port ?? 443
    }

    private static func origin(of url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased()
        else {
            return ""
        }
        let port = effectivePort(components)
        return port == 443 ? "https://\(host)" : "https://\(host):\(port)"
    }

    private static func matchesExactly(_ url: URL, base: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let expected = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else {
            return false
        }
        guard components.scheme?.lowercased() == "https" else { return false }
        guard let host = components.host?.lowercased(), host == expected.host?.lowercased() else { return false }
        guard components.path == expected.path else { return false }
        guard components.user == nil && components.password == nil else { return false }
        guard effectivePort(components) == effectivePort(expected) else { return false }
        guard components.fragment == nil else { return false }
        return true
    }
}

extension AuthMode {
    /// Whether this is gateway mode, whatever its configuration.
    var isGateway: Bool {
        if case .gateway = self { return true }
        return false
    }
}
