// Without the OAuthServerHummingbird trait this module builds none of its
// dependencies, and its public types exist only to say how to get them.
//
// The entry points mirror the real ones loosely, so that a call written for
// the real adapter type-checks far enough for the compiler to report the
// unavailability message. Types that conform to Hummingbird protocols cannot
// be mirrored without Hummingbird; using them reports a conformance error.

#if !OAuthServerHummingbird
    import Foundation

    private let traitMessage = "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])"

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
    public enum OAuthServerHummingbird {
        /// Requires the `OAuthServerHummingbird` package trait.
        @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
        public static func addRoutes(
            to _: Any,
            server _: Any,
            maximumBodyBytes _: Int = 0,
            clientAddress _: Any? = nil
        ) {
            fatalError(traitMessage)
        }

        /// Requires the `OAuthServerHummingbird` package trait.
        @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
        public static func authenticate(_: Any, verifier _: Any, publicOrigin _: URL) async -> Any {
            fatalError(traitMessage)
        }
    }

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
    public struct OAuthResourceChallenge {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
    public enum OAuthClientAddressPolicy {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(*, unavailable, message: "Enable the 'OAuthServerHummingbird' package trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"2.0.0\", traits: [\"OAuthServerHummingbird\"])")
    public struct OAuthServerRequestContext {}
#endif
