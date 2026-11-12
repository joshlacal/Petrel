/// An `include:` scope: a reference to a permission set published as a
/// Lexicon schema, such as
/// `include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview`.
///
/// An include is not a permission. It matches nothing itself; it stands for the
/// `repo:` and `rpc:` permissions its permission set expands to
/// (``expand(_:)``), once that set has been resolved and authenticated
/// (`OAuthLexiconResolving`). It therefore conforms to ``ScopeFamily`` and
/// not to ``ScopePermission``.
///
/// Port of `IncludeScope`, `scopes/include-scope.ts:26-189`.
public struct IncludeScope: Sendable, Hashable, ScopeFamily {
    /// The NSID of the permission set. Positional, required, single-valued.
    public let nsid: String
    /// The audience that `rpc` permissions marked `inheritAud` take. Optional,
    /// single-valued, with no default: when omitted it stays absent
    /// (`scopes/include-scope.ts:169-173`).
    public let aud: AudParam?

    private let parameters: ScopeParameterValues

    /// Creates a reference to the permission set `nsid`.
    public init(nsid: String, aud: AudParam? = nil) {
        self.nsid = nsid
        self.aud = aud
        var values = ScopeParameterValues()
        values.set("nsid", [nsid])
        if let aud { values.set("aud", [aud.stringValue]) }
        self.parameters = values
    }

    /// Builds the scope from parameters ``schema`` has validated.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        guard let nsid = parameters.single("nsid") else {
            throw .missingRequiredParameter(prefix: Self.schema.prefix, key: "nsid")
        }
        self.nsid = nsid
        if let audRaw = parameters.single("aud") {
            // Always `.service`: the schema below rejects `*` for this
            // resource, so a wildcard never reaches here.
            self.aud = .service(audRaw)
        } else {
            self.aud = nil
        }
        self.parameters = parameters
    }

    /// The parameter values this scope was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of `include` (`scopes/include-scope.ts:161-176`).
    public static let schema = ScopeParameterSchema(
        prefix: "include",
        positionalKey: "nsid",
        parameters: [
            .init(key: "nsid", arity: .single, isRequired: true,
                  validate: AtprotoSyntax.isValidNSID),
            // scopes/include-scope.ts:169-173 — an atproto DID with a service
            // fragment, and nothing else. Unlike the `aud` of `rpc:`
            // (`scopes/rpc-permission.ts:19-20`), there is no `*` here:
            // `include:<nsid>?aud=*` is not a valid scope.
            .init(key: "aud", arity: .single, defaultValue: nil,
                  validate: AtprotoSyntax.isValidAtprotoDIDRefAbsolute),
        ]
    )
}
