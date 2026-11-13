import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel

extension GatewayConfiguration {
    /// The callback values Petrel hard-coded before gateway configuration became
    /// caller-supplied. Existing gateway tests run under this configuration to show that
    /// behaviour is unchanged for an app that passes its former values.
    static let legacyCallbackURL = URL(string: "https://catbird.blue/oauth/callback")!
    static let legacyPermissionCallbackURL = URL(string: "https://catbird.blue/oauth/permission-callback")!

    /// A configuration equal to the former built-in constants, for the given gateway.
    static func legacyEquivalent(gatewayURL: URL) -> GatewayConfiguration {
        // The literals above are valid exact https callbacks.
        try! GatewayConfiguration(
            gatewayURL: gatewayURL,
            callbackURL: legacyCallbackURL,
            permissionCallbackURL: legacyPermissionCallbackURL
        )
    }
}

extension ConfidentialGatewayStrategy {
    /// The former initializer shape, configured with ``GatewayConfiguration/legacyEquivalent(gatewayURL:)``.
    init(
        gatewayURL: URL,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        urlSession: URLSession? = nil
    ) {
        self.init(
            configuration: .legacyEquivalent(gatewayURL: gatewayURL),
            storage: storage,
            accountManager: accountManager,
            urlSession: urlSession
        )
    }
}

extension AuthMode {
    /// A gateway mode for tests where only "some gateway" matters.
    static let testGateway: AuthMode = .gateway(.legacyEquivalent(gatewayURL: URL(string: "https://gateway.example.test")!))
}
