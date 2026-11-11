import PetrelOAuthScopes
import Testing

/// `rpc` permissions: the vectors of `scopes/rpc-permission.test.ts` of
/// `@atproto/oauth-scopes`, and the audience (DID service reference) syntax.
@Suite("Client scope model: rpc permission")
struct ClientScopeModelRPCTests {
    // MARK: Parsing

    @Test("parses a positional scope")
    func positional() throws {
        let scope = try RPCPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(scope.aud == .service("did:web:example.com#service_id"))
        #expect(scope.lxm == [.nsid("com.example.service")])
    }

    @Test("parses named and positional forms alike")
    func namedAndPositional() throws {
        let named = try RPCPermission.parse("rpc?lxm=com.example.method1&aud=*")
        #expect(named.aud == .any)
        #expect(named.lxm == [.nsid("com.example.method1")])
        #expect(try RPCPermission.parse("rpc:com.example.method1?aud=*") == named)
    }

    @Test("parses multiple lxm")
    func multipleMethods() throws {
        let scope = try RPCPermission.parse("rpc?aud=*&lxm=com.example.method1&lxm=com.example.method2")
        #expect(scope.aud == .any)
        #expect(scope.lxm == [.nsid("com.example.method1"), .nsid("com.example.method2")])
    }

    static let invalid: [(String, ScopeParseError)] = [
        // Without lxm.
        ("rpc?aud=did:web:example.com%23service_id", .missingRequiredParameter(prefix: "rpc", key: "lxm")),
        ("rpc:?aud=did:web:example.com%23service_id", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "")),
        ("rpc?aud=did:web:example.com", .missingRequiredParameter(prefix: "rpc", key: "lxm")),
        ("rpc", .missingRequiredParameter(prefix: "rpc", key: "lxm")),
        // Without aud.
        ("rpc?lxm=com.example.method1", .missingRequiredParameter(prefix: "rpc", key: "aud")),
        ("rpc:com.example.method1", .missingRequiredParameter(prefix: "rpc", key: "aud")),
        ("rpc:com.example.service", .missingRequiredParameter(prefix: "rpc", key: "aud")),
        ("rpc:*", .missingRequiredParameter(prefix: "rpc", key: "aud")),
        ("rpc:foo.bar.baz?aud=", .invalidParameterValue(prefix: "rpc", key: "aud", value: "")),
        // lxm both positional and named.
        ("rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2", .positionalAndNamedConflict(prefix: "rpc", key: "lxm")),
        ("rpc:foo.bar.baz?aud=did:web:example.com%23service_id&lxm=foo.bar.baz", .positionalAndNamedConflict(prefix: "rpc", key: "lxm")),
        ("rpc:*?lxm=*", .positionalAndNamedConflict(prefix: "rpc", key: "lxm")),
        // Any aud with any lxm.
        ("rpc?aud=*&lxm=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        ("rpc:*?aud=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        ("rpc?lxm=com.example.foo&lxm=*&aud=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        // Invalid lxm.
        ("rpc:invalid", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "invalid")),
        ("rpc?lxm=invalid", .invalidParameterValue(prefix: "rpc", key: "lxm", value: "invalid")),
        ("rpc:invalid?aud=did:web:example.com", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "invalid")),
        ("rpc:invalid?aud=did:web:example.com%23service_id", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "invalid")),
        ("rpc:foo.bar", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "foo.bar")),
        ("rpc?lxm=invalid&aud=invalid", .invalidParameterValue(prefix: "rpc", key: "lxm", value: "invalid")),
        ("rpc:com.example.*?aud=did:web:example.com%23service_id", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "com.example.*")),
        // Invalid aud.
        ("rpc:com.example.service?aud=invalid", .invalidParameterValue(prefix: "rpc", key: "aud", value: "invalid")),
        ("rpc:foo.bar.baz?aud=invalid", .invalidParameterValue(prefix: "rpc", key: "aud", value: "invalid")),
        ("rpc:foo.bar.baz?aud=did:web", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web")),
        ("rpc:foo.bar.baz?aud=did:web%23service_id", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web#service_id")),
        ("rpc:foo.bar.baz?aud=did:plc:111", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:plc:111")),
        ("rpc:foo.bar.baz?aud=did:plc:111%23service_id", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:plc:111#service_id")),
        ("rpc:foo.bar.baz?aud=did:foo:bar", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:foo:bar")),
        ("rpc:foo.bar.baz?aud=did:foo:bar%23service_id", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:foo:bar#service_id")),
        ("rpc:foo.bar.baz?aud=did:web:example.com", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web:example.com")),
        ("rpc:foo.bar.baz?aud=**", .invalidParameterValue(prefix: "rpc", key: "aud", value: "**")),
        ("rpc:foo.bar.baz?aud=*&aud=*", .repeatedSingleValuedParameter(prefix: "rpc", key: "aud")),
        ("rpc:foo.bar.baz?aud=did:web:a.example%23x&aud=did:web:b.example%23x", .repeatedSingleValuedParameter(prefix: "rpc", key: "aud")),
        // Structure.
        ("rpc:com.example.service?aud=did:web:example.com%23service_id&invalid=param", .unknownParameter(prefix: "rpc", key: "invalid")),
        ("rpc:com.example.service?aud=*&action=create", .unknownParameter(prefix: "rpc", key: "action")),
        ("invalid", .prefixMismatch(expected: "rpc", actual: "invalid")),
        ("notrpc:com.example.service?aud=did:web:example.com%23service_id", .prefixMismatch(expected: "rpc", actual: "notrpc:com.example.service?aud=did:web:example.com%23service_id")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try RPCPermission.parse(scope) }
    }

    // MARK: Audience syntax

    /// (audience, whether the canonical scope string parses back to it).
    ///
    /// The canonical form writes "%" and "+" of a parameter value bare, as
    /// the reference implementation does, so an audience containing either
    /// has a canonical form that does not read back (reference parity).
    static let validAudiences: [(String, Bool)] = [
        ("did:web:example.com#service_id", true),
        ("did:web:api.bsky.app#bsky_appview", true),
        ("did:web:sub.domain.example.co.uk#svc", true),
        ("did:web:localhost#svc", true),
        ("did:web:localhost%3A3000#svc", false),
        ("did:web:localhost%3A65535#svc", false),
        ("did:plc:ewvi7nxzyoun6zhxrhs64oiz#atproto_labeler", true),
        ("did:plc:z72i7hdynmk6r22z27h6tvur#bsky_fg", true),
        // RFC 3986 fragment characters.
        ("did:web:example.com#a-b.c_d~e", true),
        ("did:web:example.com#a!$&'()*,;=b", true),
        ("did:web:example.com#a!$&'()*+,;=b", false),
        ("did:web:example.com#a:b@c/d?e", true),
        ("did:web:example.com#a%20b%2fc", false),
    ]

    @Test("accepts DID service references", arguments: validAudiences)
    func validAudience(aud: String, readsBack: Bool) throws {
        let scope = try ClientScopeModelTestSupport.rpc(["com.example.method"], aud: aud)
        #expect(scope.aud == .service(aud))
        #expect(scope.matches(.init(lxm: "com.example.method", aud: aud)))
        #expect(AtprotoSyntax.isValidAtprotoDIDRefAbsolute(aud))

        let canonical = try scope.canonicalScopeString()
        #expect(((try? RPCPermission.parse(canonical))?.aud == .service(aud)) == readsBack)
    }

    static let invalidAudiences: [String] = [
        "",
        "did:web:example.com",
        "did:web:example.com#",
        "did:web:example.com#a#b",
        "#service_id",
        "example.com#service_id",
        "https://example.com#service_id",
        "DID:web:example.com#svc",
        "did:WEB:example.com#svc",
        // did:web: a bare hostname, no path, no port unless localhost.
        "did:web:#svc",
        "did:web:example.com:path#svc",
        "did:web::example.com#svc",
        "did:web:example.com%3A443#svc",
        "did:web:example.com%3a443#svc",
        "did:web:localhost%3Aabc#svc",
        "did:web:localhost%3A65536#svc",
        "did:web:localhost%3A3000%3A1#svc",
        "did:web:localhost:3000#svc",
        "did:web:exa mple.com#svc",
        "did:web:example.com/path#svc",
        // did:plc: exactly 24 base32 characters.
        "did:plc:ewvi7nxzyoun6zhxrhs64oi#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oizz#svc",
        "did:plc:EWVI7NXZYOUN6ZHXRHS64OIZ#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oi1#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oi8#svc",
        // Other DID methods are not atproto DIDs.
        "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#svc",
        "did:example:123#svc",
        // Fragment syntax.
        "did:web:example.com#sp ace",
        "did:web:example.com#%zz",
        "did:web:example.com#abc%2",
        "did:web:example.com#a\"b",
        "did:web:example.com#a[b]",
        "did:web:example.com#caf\u{E9}",
    ]

    @Test("rejects anything that is not a DID service reference", arguments: invalidAudiences)
    func invalidAudience(_ aud: String) {
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "rpc", key: "aud", value: aud)) {
            try ATProtoScope.rpc(lxm: ["com.example.method"], aud: aud)
        }
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute(aud))
    }

    // DIFFERENCE 9: `did:web:localhost%3A` (a port separator with no port) is
    // accepted, as the WHATWG URL parser the reference implementation uses
    // accepts `http://localhost:`.
    @Test("accepts a localhost did:web with an empty port")
    func emptyLocalhostPort() throws {
        let scope = try ClientScopeModelTestSupport.rpc(["com.example.method"], aud: "did:web:localhost%3A#svc")
        #expect(scope.aud == .service("did:web:localhost%3A#svc"))
    }

    // MARK: Building (scopeNeededFor)

    @Test("builds the scope needed for a method and audience")
    func scopeNeededFor() throws {
        #expect(
            try ATProtoScope.rpc(lxm: ["com.example.service"], aud: "did:web:example.com#service_id").scopeString
                == "rpc:com.example.service?aud=did:web:example.com%23service_id"
        )
        #expect(
            try ATProtoScope.rpc(lxm: ["com.example.method1"], aud: "*").scopeString
                == "rpc:com.example.method1?aud=*"
        )
        #expect(
            try RPCPermission.scopeNeeded(for: .init(lxm: "com.example.service", aud: "did:web:example.com#service_id"))
                == "rpc:com.example.service?aud=did:web:example.com%23service_id"
        )
    }

    @Test("refuses to build a scope from invalid values")
    func buildValidates() {
        let unrestricted = ScopeParseError.forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")
        #expect(throws: ScopeParseError.missingRequiredParameter(prefix: "rpc", key: "lxm")) {
            try ATProtoScope.rpc(lxm: [], aud: "*")
        }
        #expect(throws: unrestricted) {
            try ATProtoScope.rpc(lxm: ["*"], aud: "*")
        }
        #expect(throws: unrestricted) {
            try ATProtoScope.rpc(lxm: ["com.example.foo", "*"], aud: "*")
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "rpc", key: "lxm", value: "nope")) {
            try ATProtoScope.rpc(lxm: ["nope"], aud: "*")
        }
        // The method list is checked before the audience.
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "rpc", key: "lxm", value: "nope")) {
            try ATProtoScope.rpc(lxm: ["nope"], aud: "nope")
        }
    }

    // MARK: Matching

    @Test("matches the exact lxm and aud")
    func matchesExact() throws {
        let scope = try RPCPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(scope.matches(.init(lxm: "com.example.service", aud: "did:web:example.com#service_id")))
    }

    @Test("does not match a different lxm")
    func doesNotMatchOtherMethod() throws {
        let scope = try RPCPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(!scope.matches(.init(lxm: "com.example.OtherService", aud: "did:web:example.com#service_id")))
    }

    @Test("does not match a different aud")
    func doesNotMatchOtherAudience() throws {
        let scope = try RPCPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(!scope.matches(.init(lxm: "com.example.service", aud: "did:example:456#service_id")))
        #expect(!scope.matches(.init(lxm: "com.example.service", aud: "did:web:example.com#other_id")))
        // The bare DID is not the service reference.
        #expect(!scope.matches(.init(lxm: "com.example.service", aud: "did:web:example.com")))
        // A wildcard request is only satisfied by a wildcard permission.
        #expect(!scope.matches(.init(lxm: "com.example.service", aud: "*")))
        #expect(!scope.matches(.init(lxm: "*", aud: "did:web:example.com#service_id")))
    }

    @Test("matches a wildcard aud")
    func matchesWildcardAudience() throws {
        let scope = try RPCPermission.parse("rpc:com.example.method1?aud=*")
        #expect(scope.matches(.init(lxm: "com.example.method1", aud: "did:web:example.com#service_id")))
        #expect(scope.matches(.init(lxm: "com.example.method1", aud: "*")))
        #expect(!scope.matches(.init(lxm: "com.example.method2", aud: "did:web:example.com#service_id")))
    }

    @Test("matches a wildcard lxm")
    func matchesWildcardMethod() throws {
        let scope = try RPCPermission.parse("rpc:*?aud=did:web:example.com%23service_id")
        #expect(scope.matches(.init(lxm: "com.example.method1", aud: "did:web:example.com#service_id")))
        #expect(scope.matches(.init(lxm: "com.example.anyMethod", aud: "did:web:example.com#service_id")))
        #expect(scope.matches(.init(lxm: "*", aud: "did:web:example.com#service_id")))
        #expect(!scope.matches(.init(lxm: "com.example.method1", aud: "did:web:other.example#service_id")))
    }

    /// See DIFFERENCE 8 (resolved in the shared target): comparison is
    /// byte-wise, so a method or service spelled with U+212A KELVIN SIGN is
    /// not the one spelled with "K".
    @Test("compares methods and audiences byte-wise, not under Unicode canonical equivalence")
    func doesNotMatchCanonicallyEquivalent() throws {
        let scope = try RPCPermission.parse("rpc:com.example.getKey?aud=did:web:example.com%23Key")
        #expect(scope.matches(.init(lxm: "com.example.getKey", aud: "did:web:example.com#Key")))
        #expect(!scope.matches(.init(lxm: "com.example.get\u{212A}ey", aud: "did:web:example.com#Key")))
        #expect(!scope.matches(.init(lxm: "com.example.getKey", aud: "did:web:example.com#\u{212A}ey")))
        #expect(!scope.matches(.init(lxm: "com.example.getkey", aud: "did:web:example.com#Key")))
    }

    // MARK: Formatting

    @Test("formats a scope with lxm and aud")
    func formats() throws {
        let scope = RPCPermission(aud: .service("did:web:example.com#service_id"), lxm: [.nsid("com.example.service")])
        #expect(try scope.canonicalScopeString() == "rpc:com.example.service?aud=did:web:example.com%23service_id")
    }

    @Test("formats a scope with a wildcard aud")
    func formatsWildcardAudience() throws {
        #expect(
            try RPCPermission(aud: .any, lxm: [.nsid("com.example.method1")]).canonicalScopeString()
                == "rpc:com.example.method1?aud=*"
        )
    }

    @Test("formats a scope with a wildcard lxm")
    func formatsWildcardMethod() throws {
        let scope = RPCPermission(aud: .service("did:web:example.com#service_id"), lxm: [.any])
        #expect(try scope.canonicalScopeString() == "rpc:*?aud=did:web:example.com%23service_id")
    }

    @Test("formats several lxm as named parameters")
    func formatsMultipleMethods() throws {
        let scope = try ClientScopeModelTestSupport.rpc(
            ["com.example.method1", "com.example.method2"],
            aud: "did:web:example.com#service_id"
        )
        #expect(
            try scope.canonicalScopeString()
                == "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=did:web:example.com%23service_id"
        )
    }

    @Test("simplifies lxm when one of them is the wildcard")
    func simplifiesWildcard() throws {
        let scope = try ClientScopeModelTestSupport.rpc(["*", "com.example.method1"], aud: "did:web:example.com#service_id")
        // As given; see DIFFERENCE 4.
        #expect(scope.lxm == [.any, .nsid("com.example.method1")])
        #expect(try scope.canonicalScopeString() == "rpc:*?aud=did:web:example.com%23service_id")
    }

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("rpc:com.example.service?aud=did:web:example.com%23service_id", "rpc:com.example.service?aud=did:web:example.com%23service_id"),
        // A bare "#" in the parameters is tolerated when reading.
        ("rpc:com.example.service?aud=did:web:example.com#service_id", "rpc:com.example.service?aud=did:web:example.com%23service_id"),
        ("rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*", "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*"),
        ("rpc?lxm=com.example.method1&lxm=com.example.method2&lxm=*&aud=did:web:example.com%23service_id", "rpc:*?aud=did:web:example.com%23service_id"),
        ("rpc?aud=did:web:example.com%23foo&lxm=com.example.service", "rpc:com.example.service?aud=did:web:example.com%23foo"),
        ("rpc?lxm=com.example.method1&aud=did:web:example.com#foo", "rpc:com.example.method1?aud=did:web:example.com%23foo"),
        ("rpc?lxm=com.example.method1&aud=did:web:example.com%23bar", "rpc:com.example.method1?aud=did:web:example.com%23bar"),
        ("rpc:com.example.method1?&aud=*", "rpc:com.example.method1?aud=*"),
        // Beyond the reference vectors.
        ("rpc?lxm=com.example.b&lxm=com.example.a&lxm=com.example.b&aud=*", "rpc?lxm=com.example.a&lxm=com.example.b&aud=*"),
        ("rpc:com.example.method1?aud=did%3Aweb%3Aexample.com%23foo", "rpc:com.example.method1?aud=did:web:example.com%23foo"),
        ("rpc:com.example.method1?aud=did:plc:ewvi7nxzyoun6zhxrhs64oiz%23atproto_labeler", "rpc:com.example.method1?aud=did:plc:ewvi7nxzyoun6zhxrhs64oiz%23atproto_labeler"),
        ("rpc:com.example.method1?aud=%2A", "rpc:com.example.method1?aud=*"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try RPCPermission.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point and grants the same access", arguments: consistency)
    func roundTrips(input: String, expected: String) throws {
        let scope = try RPCPermission.parse(input)
        let reparsed = try RPCPermission.parse(expected)
        #expect(try reparsed.canonicalScopeString() == expected)
        #expect(reparsed.aud == scope.aud)
        #expect(reparsed.lxm.contains(.any) == scope.lxm.contains(.any))
        if !scope.lxm.contains(.any) {
            #expect(Set(reparsed.lxm) == Set(scope.lxm))
        }
    }

    // MARK: Percent-encoding inside the audience (reference parity)

    /// A `did:web` on a localhost port carries a percent-encoded ":". To write
    /// it in a scope string the "%" has to be escaped again. The canonical
    /// form writes it bare, as the reference implementation does, and that
    /// string reads back as the path-ful, invalid `did:web:localhost:3000`.
    @Test("an audience containing a percent sign has a canonical form that does not read back")
    func percentInAudience() throws {
        let escaped = "rpc:com.example.method?aud=did:web:localhost%253A3000%23svc"
        let scope = try RPCPermission.parse(escaped)
        #expect(scope.aud == .service("did:web:localhost%3A3000#svc"))
        #expect(try ClientScopeModelTestSupport.rpc(["com.example.method"], aud: "did:web:localhost%3A3000#svc") == scope)

        let canonical = try scope.canonicalScopeString()
        #expect(canonical == "rpc:com.example.method?aud=did:web:localhost%3A3000%23svc")
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web:localhost:3000#svc")) {
            try RPCPermission.parse(canonical)
        }
    }

    /// "+" is a valid fragment character, and a space when read from a
    /// parameter value. It has to be written "%2B"; the canonical form writes
    /// it bare, as the reference implementation does.
    @Test("an audience containing a plus sign has a canonical form that does not read back")
    func plusInAudience() throws {
        let escaped = "rpc:com.example.method?aud=did:web:example.com%23a%2Bb"
        let scope = try RPCPermission.parse(escaped)
        #expect(scope.aud == .service("did:web:example.com#a+b"))
        #expect(try ClientScopeModelTestSupport.rpc(["com.example.method"], aud: "did:web:example.com#a+b") == scope)

        let canonical = try scope.canonicalScopeString()
        #expect(canonical == "rpc:com.example.method?aud=did:web:example.com%23a+b")
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web:example.com#a b")) {
            try RPCPermission.parse(canonical)
        }
    }
}
