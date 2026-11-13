// Without the OAuthServerNIO trait this module builds none of its
// dependencies, and its public type exists only to say how to get it.
//
// The stub mirrors the real initializer and conformance, so that code written
// for the real type type-checks far enough for the compiler to report the
// unavailability message, rather than an unrelated "no such initializer" or
// "does not conform" error.

#if !OAuthServerNIO
    import Foundation
    import PetrelOAuthServer

    private let traitMessage = "Enable the 'OAuthServerNIO' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerNIO\"])"

    /// Requires the `OAuthServerNIO` package trait.
    @available(*, unavailable, message: "Enable the 'OAuthServerNIO' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerNIO\"])")
    public struct PinnedNIOOAuthRemoteTransport: OAuthRemoteTransport {
        /// Requires the `OAuthServerNIO` package trait.
        @available(*, unavailable, message: "Enable the 'OAuthServerNIO' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerNIO\"])")
        public init(eventLoopGroup: Any? = nil, trustRoots: Any? = nil, userAgent: String = "") throws {
            fatalError(traitMessage)
        }

        /// Requires the `OAuthServerNIO` package trait.
        public var pinsConnectionsToApprovedPeers: Bool {
            false
        }

        /// Requires the `OAuthServerNIO` package trait.
        public func get(
            url _: URL,
            approvedPeers _: Set<OAuthIPAddress>,
            timeout _: TimeInterval,
            maximumBodyBytes _: Int
        ) async throws -> OAuthRemoteHTTPResponse {
            fatalError(traitMessage)
        }
    }
#endif
