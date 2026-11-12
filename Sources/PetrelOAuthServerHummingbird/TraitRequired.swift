// Without the OAuthServerHummingbird trait this module builds none of its
// dependencies, and its public types exist only to say how to get them.

#if !OAuthServerHummingbird
    /// Requires the `OAuthServerHummingbird` package trait.
    @available(
        *, unavailable,
        message: "Enable the OAuthServerHummingbird trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"…\", traits: [\"OAuthServerHummingbird\"])"
    )
    public enum OAuthServerHummingbird {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(
        *, unavailable,
        message: "Enable the OAuthServerHummingbird trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"…\", traits: [\"OAuthServerHummingbird\"])"
    )
    public struct PinnedNIOOAuthRemoteTransport {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(
        *, unavailable,
        message: "Enable the OAuthServerHummingbird trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"…\", traits: [\"OAuthServerHummingbird\"])"
    )
    public struct OAuthResourceChallenge {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(
        *, unavailable,
        message: "Enable the OAuthServerHummingbird trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"…\", traits: [\"OAuthServerHummingbird\"])"
    )
    public enum OAuthClientAddressPolicy {}

    /// Requires the `OAuthServerHummingbird` package trait.
    @available(
        *, unavailable,
        message: "Enable the OAuthServerHummingbird trait: .package(url: \"https://github.com/joshlacal/Petrel.git\", from: \"…\", traits: [\"OAuthServerHummingbird\"])"
    )
    public struct OAuthServerRequestContext {}
#endif
