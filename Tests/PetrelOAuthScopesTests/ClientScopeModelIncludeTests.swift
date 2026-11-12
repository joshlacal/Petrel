import PetrelOAuthScopes
import Testing

/// `include` scopes and permission sets: the vectors of
/// `scopes/include-scope.test.ts` of `@atproto/oauth-scopes`, and the
/// "Permission Sets" section of the permission specification.
@Suite("Client scope model: include scope and permission sets")
struct ClientScopeModelIncludeTests {
    // MARK: Parsing

    @Test("parses a positional nsid")
    func positional() throws {
        let scope = try IncludeScope.parse("include:com.example.bar")
        #expect(scope.nsid == "com.example.bar")
        #expect(scope.aud == nil)
    }

    @Test("parses a positional nsid with an aud parameter")
    func positionalWithAudience() throws {
        let scope = try IncludeScope.parse("include:com.example.baz?aud=did:web:example.com%23my_service")
        #expect(scope.nsid == "com.example.baz")
        #expect(scope.aud == .service("did:web:example.com#my_service"))
    }

    @Test("parses a bare # in the parameters")
    func bareHash() throws {
        let scope = try IncludeScope.parse("include:com.example.baz?aud=did:web:example.com#my_service")
        #expect(scope.nsid == "com.example.baz")
        #expect(scope.aud == .service("did:web:example.com#my_service"))
    }

    @Test("parses a named nsid")
    func named() throws {
        let scope = try IncludeScope.parse("include?nsid=com.example.baz")
        #expect(scope.nsid == "com.example.baz")
        #expect(scope.aud == nil)
    }

    @Test("parses a named nsid and aud")
    func namedWithAudience() throws {
        let scope = try IncludeScope.parse("include?aud=did:web:example.com%23my_service&nsid=com.example.baz")
        #expect(scope.nsid == "com.example.baz")
        #expect(scope.aud == .service("did:web:example.com#my_service"))
    }

    static let invalid: [(String, ScopeParseError)] = [
        ("", .prefixMismatch(expected: "include", actual: "")),
        ("repo:com.example.baz", .prefixMismatch(expected: "include", actual: "repo:com.example.baz")),
        ("include", .missingRequiredParameter(prefix: "include", key: "nsid")),
        ("include#", .prefixMismatch(expected: "include", actual: "include#")),
        // Invalid NSID.
        ("include:", .invalidPositionalValue(prefix: "include", key: "nsid", value: "")),
        ("include:#", .invalidPositionalValue(prefix: "include", key: "nsid", value: "#")),
        ("include:&", .invalidPositionalValue(prefix: "include", key: "nsid", value: "&")),
        ("include:com..example", .invalidPositionalValue(prefix: "include", key: "nsid", value: "com..example")),
        ("include:com", .invalidPositionalValue(prefix: "include", key: "nsid", value: "com")),
        ("include:com.example", .invalidPositionalValue(prefix: "include", key: "nsid", value: "com.example")),
        ("include:9com.example.foo", .invalidPositionalValue(prefix: "include", key: "nsid", value: "9com.example.foo")),
        ("include:com.example.-bar", .invalidPositionalValue(prefix: "include", key: "nsid", value: "com.example.-bar")),
        ("include:invalid^nsid", .invalidPositionalValue(prefix: "include", key: "nsid", value: "invalid^nsid")),
        ("include:nsid", .invalidPositionalValue(prefix: "include", key: "nsid", value: "nsid")),
        ("include:*", .invalidPositionalValue(prefix: "include", key: "nsid", value: "*")),
        ("include:com.example.*", .invalidPositionalValue(prefix: "include", key: "nsid", value: "com.example.*")),
        // Invalid aud.
        ("include:com.example.baz?aud=", .invalidParameterValue(prefix: "include", key: "aud", value: "")),
        ("include:com.example.baz?aud=did:web:example.com", .invalidParameterValue(prefix: "include", key: "aud", value: "did:web:example.com")),
        ("include:com.example.baz?aud=invalid^did", .invalidParameterValue(prefix: "include", key: "aud", value: "invalid^did")),
        // The wildcard audience is for rpc only.
        ("include:com.example.baz?aud=*", .invalidParameterValue(prefix: "include", key: "aud", value: "*")),
        // Structure.
        ("include:com.example.baz?nsid=com.example.qux", .positionalAndNamedConflict(prefix: "include", key: "nsid")),
        ("include?nsid=com.example.baz&nsid=com.example.qux", .repeatedSingleValuedParameter(prefix: "include", key: "nsid")),
        ("include:com.example.baz?aud=did:web:a.example%23x&aud=did:web:b.example%23x", .repeatedSingleValuedParameter(prefix: "include", key: "aud")),
        ("include:com.example.baz?lxm=com.example.foo", .unknownParameter(prefix: "include", key: "lxm")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try IncludeScope.parse(scope) }
    }

    @Test("refuses to build a scope from invalid values")
    func buildValidates() {
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "include", key: "nsid", value: "com.example")) {
            try ATProtoScope.include(nsid: "com.example")
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "include", key: "aud", value: "did:web:example.com")) {
            try ATProtoScope.include(nsid: "com.example.foo", aud: "did:web:example.com")
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "include", key: "aud", value: "*")) {
            try ATProtoScope.include(nsid: "com.example.foo", aud: "*")
        }
    }

    // MARK: Formatting

    @Test("formats a scope without aud")
    func formatsWithoutAudience() throws {
        #expect(try IncludeScope(nsid: "com.example.foo").canonicalScopeString() == "include:com.example.foo")
        #expect(try ATProtoScope.include(nsid: "com.example.foo").scopeString == "include:com.example.foo")
    }

    @Test("formats a scope with aud")
    func formatsWithAudience() throws {
        #expect(
            try IncludeScope(nsid: "com.example.foo", aud: .service("did:web:example.com#my_service")).canonicalScopeString()
                == "include:com.example.foo?aud=did:web:example.com%23my_service"
        )
        #expect(
            try ATProtoScope.include(nsid: "com.example.foo", aud: "did:web:example.com#my_service").scopeString
                == "include:com.example.foo?aud=did:web:example.com%23my_service"
        )
    }

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("include:com.example.bar", "include:com.example.bar"),
        ("include:com.example.baz?aud=did:web:example.com%23my_service", "include:com.example.baz?aud=did:web:example.com%23my_service"),
        ("include:com.example.baz?aud=did:web:example.com#my_service", "include:com.example.baz?aud=did:web:example.com%23my_service"),
        ("include?nsid=com.example.baz", "include:com.example.baz"),
        ("include?aud=did:web:example.com%23my_service&nsid=com.example.baz", "include:com.example.baz?aud=did:web:example.com%23my_service"),
        ("include:com.example.bar?", "include:com.example.bar"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try IncludeScope.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point and names the same set", arguments: consistency)
    func roundTrips(input: String, expected: String) throws {
        let scope = try IncludeScope.parse(input)
        let reparsed = try IncludeScope.parse(expected)
        #expect(try reparsed.canonicalScopeString() == expected)
        #expect(reparsed.nsid == scope.nsid)
        #expect(reparsed.aud == scope.aud)
    }

    // MARK: Namespace authority

    /// (permission set NSID, resource NSID, under authority)
    static let authority: [(String, String, Bool)] = [
        // same authority
        ("com.example.foo.auth", "com.example.foo.identifier", true),
        // child authorities
        ("com.example.foo.auth", "com.example.foo.bar.baz", true),
        ("com.example.foo.auth", "com.example.foo.bar.baz.quz", true),
        // invalid nsids
        ("com.example.foo.auth", "com", false),
        ("com.example.foo.auth", "com.example", false),
        // siblings of root domain
        ("com.example.foo.auth", "com.example.bar", false),
        ("com.example.foo.auth", "com.example.bar.foo", false),
        ("com.example.foo.auth", "com.example.bar.qux", false),
        // other domains
        ("com.example.foo.auth", "com.atproto.foo", false),
        ("com.example.foo.auth", "com.atproto.foo.auth", false),
        ("com.example.foo.auth", "com.atproto.foo.bar", false),
        // Beyond the reference vectors: the group itself, its parent, a group
        // that merely shares a prefix, and the wildcard.
        ("com.example.foo.auth", "com.example.foo", false),
        ("com.example.foo.auth", "com.example.foo.", false),
        ("com.example.foo.auth", "com.example.fooBar.baz", false),
        ("com.example.foo.auth", "com.example.foobar", false),
        ("com.example.foo.auth", "com.example.auth", false),
        ("com.example.foo.auth", "*", false),
        ("com.example.foo.auth", "com.example.foo.auth", true),
        ("com.example.foo.auth", "com.example.Foo.identifier", false),
        // Specification, "Namespace Authority".
        ("app.example.feed.authOnlyPost", "app.example.feed.post", true),
        ("app.example.feed.authOnlyPost", "app.example.feed.getPostThread", true),
        ("app.example.feed.authOnlyPost", "app.example.actor.profile", false),
        ("app.example.authFull", "app.example.feed.post", true),
        ("app.example.authFull", "app.example.feed.getPostThread", true),
        ("app.example.authFull", "app.example.actor.profile", true),
        ("app.example.authFull", "app.example.feed.deeper.still.record", true),
        ("app.example.authFull", "app.other.feed.post", false),
        ("app.example.authFull", "com.example.feed.post", false),
    ]

    @Test("isParentAuthorityOf", arguments: authority)
    func parentAuthority(set: String, resource: String, expected: Bool) {
        #expect(IncludeScope(nsid: set).isParentAuthorityOf(resource) == expected)
    }

    // MARK: Expansion (buildPermissions)

    typealias Reason = IncludeScope.ExpansionRejectionReason

    struct Expansion: Sendable, CustomTestStringConvertible {
        let name: String
        var include = "include:com.example.calendar.auth"
        let permissions: String
        var scopes: [String] = []
        var reasons: [Reason] = []

        var testDescription: String { name }
    }

    static let expansions: [Expansion] = [
        // blob
        Expansion(
            name: "blob: rejects valid permissions",
            permissions: #"[{"type":"permission","resource":"blob","accept":["image/*"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "blob: rejects invalid permissions (accept is not an array)",
            permissions: #"[{"type":"permission","resource":"blob","accept":"image/*"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "blob: rejects invalid permissions (extra property)",
            permissions: #"[{"type":"permission","resource":"blob","accept":["image/*"],"extra":"property"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),

        // rpc: enables
        Expansion(
            name: "rpc: allows * aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"]}]"#,
            scopes: ["rpc:com.example.calendar.listEvents?aud=*"]
        ),
        Expansion(
            name: "rpc: inherits aud",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            permissions: """
            [
              {"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents"]},
              {"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.getEventDetails"]}
            ]
            """,
            scopes: [
                "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23foo",
                "rpc:com.example.calendar.getEventDetails?aud=did:web:example.com%23foo",
            ]
        ),

        // rpc: rejects
        Expansion(
            name: "rpc: forbids use of a specific aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: invalid lxm syntax (not an array)",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":"com.example.calendar.listEvents"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: invalid lxm syntax (not an array), wildcard aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":"com.example.calendar.listEvents"}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: extra properties",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"],"extra":"property"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: extra properties, wildcard aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"],"extra":"property"}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: missing lxm",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: missing lxm, wildcard aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*"}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: missing aud",
            permissions: #"[{"type":"permission","resource":"rpc","lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: missing aud and lxm",
            permissions: #"[{"type":"permission","resource":"rpc"}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: both inheritAud and aud specified",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#bar",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: both inheritAud and wildcard aud specified",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#bar",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: invalid authority, specific aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.atproto.moderation.createReport"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: un-specified inherited aud",
            permissions: #"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: wildcard aud for an invalid authority",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.atproto.moderation.createReport"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "rpc: inherited aud for an invalid authority",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            permissions: #"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents","com.example.contacts.list"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        // A wildcard is never under the authority of a permission set.
        Expansion(
            name: "rpc: wildcard lxm",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            permissions: #"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["*"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "rpc: wildcard lxm next to a valid one, wildcard aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents","*"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: partial wildcard lxm",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.*"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: invalid lxm value",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: empty lxm",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":[]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: lxm with a non-string element",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents",1]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: aud is not a string",
            permissions: #"[{"type":"permission","resource":"rpc","aud":["*"],"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "rpc: inheritAud is not a boolean",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            permissions: #"[{"type":"permission","resource":"rpc","inheritAud":"true","lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: collection is not an rpc field",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"],"collection":["com.example.calendar.event"]}]"#,
            reasons: [.invalidPermission]
        ),
        // DIFFERENCE 11: `inheritAud` is only understood when it is `true`
        // and there is an audience to inherit. Any other `inheritAud`,
        // `false` included, is an unknown parameter and the entry is ignored,
        // as in the reference implementation. (The specification makes it an
        // optional boolean, which would make `false` the same as leaving it
        // out.)
        Expansion(
            name: "rpc: inheritAud false with a wildcard aud",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","inheritAud":false,"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: inheritAud false without aud does not inherit",
            include: "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            permissions: #"[{"type":"permission","resource":"rpc","inheritAud":false,"lxm":["com.example.calendar.listEvents"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "rpc: several lxm are sorted",
            permissions: #"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents","com.example.calendar.getEventDetails"]}]"#,
            scopes: ["rpc?lxm=com.example.calendar.getEventDetails&lxm=com.example.calendar.listEvents&aud=*"]
        ),

        // repo: enables
        Expansion(
            name: "repo: valid permission",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["create","update","delete"]}]"#,
            scopes: ["repo:com.example.calendar.event"]
        ),
        Expansion(
            name: "repo: valid permission without action",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"]}]"#,
            scopes: ["repo:com.example.calendar.event"]
        ),
        Expansion(
            name: "repo: valid permission with partial actions",
            permissions: """
            [
              {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["delete","update"]},
              {"type":"permission","resource":"repo","collection":["com.example.calendar.event","com.example.calendar.rsvp"],"action":["delete","create"]}
            ]
            """,
            scopes: [
                "repo:com.example.calendar.event?action=update&action=delete",
                "repo?collection=com.example.calendar.event&collection=com.example.calendar.rsvp&action=create&action=delete",
            ]
        ),

        // repo: rejects
        Expansion(
            name: "repo: invalid collection syntax (not an array)",
            permissions: #"[{"type":"permission","resource":"repo","collection":"com.example.calendar.event","action":["create","update","delete"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: invalid action syntax (not an array)",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":"all"}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: invalid action values",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["create","update","manage"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: invalid authority",
            permissions: #"[{"type":"permission","resource":"repo","collection":["app.bsky.feed.post"],"action":["create","update","delete"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "repo: one valid and one invalid authority",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event","app.bsky.feed.post"],"action":["create","update","delete"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "repo: wildcard collection",
            permissions: #"[{"type":"permission","resource":"repo","collection":["*"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "repo: wildcard collection next to a valid one",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event","*"],"action":["delete"]}]"#,
            reasons: [.outsideNamespaceAuthority]
        ),
        Expansion(
            name: "repo: partial wildcard collection",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.*"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: missing collection",
            permissions: #"[{"type":"permission","resource":"repo","action":["create"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: empty collection",
            permissions: #"[{"type":"permission","resource":"repo","collection":[]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: empty action",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":[]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: invalid collection value",
            permissions: #"[{"type":"permission","resource":"repo","collection":["event"]}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: inheritAud is not a repo field",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"inheritAud":true}]"#,
            reasons: [.invalidPermission]
        ),
        Expansion(
            name: "repo: extra properties",
            permissions: #"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"extra":1.5}]"#,
            reasons: [.invalidPermission]
        ),

        // account, identity, include, unknown
        Expansion(
            name: "account: rejects account permissions",
            permissions: #"[{"type":"permission","resource":"account","attr":"email","action":["read"]}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "identity: rejects identity permissions",
            permissions: #"[{"type":"permission","resource":"identity","attr":"handle"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "include: rejects nested permission sets",
            permissions: #"[{"type":"permission","resource":"include","nsid":"com.example.calendar.authOther"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(
            name: "unknown resource",
            permissions: #"[{"type":"permission","resource":"space","name":"com.example.calendar.shared"}]"#,
            reasons: [.notAllowedInPermissionSet]
        ),
        Expansion(name: "empty permission set", permissions: "[]"),
    ]

    @Test("expands a permission set", arguments: expansions)
    func expands(_ vector: Expansion) throws {
        let include = try IncludeScope.parse(vector.include)
        let set = try ClientScopeModelTestSupport.permissionSet(permissions: vector.permissions)

        let expansion = include.expansion(of: set)
        #expect(try expansion.permissions.map { try $0.canonicalScopeString() } == vector.scopes)
        #expect(expansion.rejections.map(\.reason) == vector.reasons)
        #expect(expansion.permissions.count + expansion.rejections.count == set.permissions.count)

        #expect(include.expand(set) == expansion.permissions)
        #expect(try include.expandToScopeStrings(set) == vector.scopes)
        // Whatever is granted is a repo or rpc permission under the authority
        // of the set, and never a wildcard.
        for permission in expansion.permissions {
            switch permission {
            case let .repo(repo):
                #expect(repo.collection.allSatisfy { include.isParentAuthorityOf($0.stringValue) })
                #expect(!repo.collection.contains(.any))
            case let .rpc(rpc):
                #expect(rpc.lxm.allSatisfy { include.isParentAuthorityOf($0.stringValue) })
                #expect(!rpc.lxm.contains(.any))
                #expect(rpc.aud == .any || rpc.aud == include.aud)
            }
        }
    }

    // DIFFERENCE 12 (resolved in the shared target): an entry with a field
    // that is `null` or a JSON object is ignored, as any other malformed
    // entry is, and the rest of the permission set stands.
    @Test(
        "a null or object field invalidates only the entry that carries it",
        arguments: [
            (#"[{"type":"permission","resource":"rpc","aud":null,"lxm":["com.example.calendar.listEvents"]}]"#, [String]()),
            (#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":null}]"#, []),
            (#"[{"type":"permission","resource":"repo","collection":[{"nsid":"com.example.calendar.event"}]}]"#, []),
            (#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"]},{"type":"permission","resource":"repo","collection":["com.example.calendar.rsvp"],"nested":{"a":1}}]"#,
             ["repo:com.example.calendar.event"]),
        ]
    )
    func unsupportedFieldValue(_ permissions: String, granted: [String]) throws {
        let set = try ClientScopeModelTestSupport.permissionSet(permissions: permissions)
        let include = IncludeScope(nsid: "com.example.calendar.auth")
        let expansion = include.expansion(of: set)
        #expect(try expansion.permissions.map { try $0.canonicalScopeString() } == granted)
        #expect(expansion.permissions.count + expansion.rejections.count == set.permissions.count)
        #expect(!expansion.rejections.isEmpty)
    }

    /// The equivalent scope strings are valid: the permissions above are
    /// refused for being in a permission set, not for being malformed.
    @Test("account and identity permissions are valid outside a permission set")
    func accountAndIdentityControl() throws {
        #expect(try AccountPermission.parse("account:email?action=read").action == [.read])
        #expect(try IdentityPermission.parse("identity:handle").attr == .handle)
        #expect(try BlobPermission.parse("blob:image/*").accept == [.type("image")])
    }

    @Test("reports the position and content of ignored permissions")
    func rejectionDetails() throws {
        let set = try ClientScopeModelTestSupport.permissionSet(permissions: """
        [
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"]},
          {"type":"permission","resource":"blob","accept":["image/*"]},
          {"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"]},
          {"type":"permission","resource":"repo","collection":["app.bsky.feed.post"]}
        ]
        """)
        let expansion = IncludeScope(nsid: "com.example.calendar.auth").expansion(of: set)

        #expect(try expansion.permissions.map { try $0.canonicalScopeString() } == [
            "repo:com.example.calendar.event",
            "rpc:com.example.calendar.listEvents?aud=*",
        ])
        #expect(expansion.rejections.map(\.index) == [1, 3])
        #expect(expansion.rejections.map(\.reason) == [.notAllowedInPermissionSet, .outsideNamespaceAuthority])
        #expect(expansion.rejections.map(\.permission) == [
            LexiconPermission(resource: "blob", fields: ["accept": .list([.string("image/*")])]),
            LexiconPermission(resource: "repo", fields: ["collection": .list([.string("app.bsky.feed.post")])]),
        ])
    }

    // MARK: Specification examples

    /// Each JSON permission example of the specification, next to the scope
    /// string the specification gives for it.
    static let jsonForms: [(String, String)] = [
        (
            #"{"type":"permission","resource":"repo","collection":["app.example.profile"]}"#,
            "repo:app.example.profile"
        ),
        (
            #"{"type":"permission","resource":"repo","collection":["app.example.profile"],"action":["create","update","delete"]}"#,
            "repo:app.example.profile?action=create&action=update&action=delete"
        ),
        (
            #"{"type":"permission","resource":"repo","collection":["app.example.profile","app.example.post"]}"#,
            "repo?collection=app.example.profile&collection=app.example.post"
        ),
        (
            #"{"type":"permission","resource":"rpc","lxm":["app.example.moderation.createReport"],"aud":"*"}"#,
            "rpc:app.example.moderation.createReport?aud=*"
        ),
    ]

    @Test("spec: the JSON form and the string form are the same permission", arguments: jsonForms)
    func jsonFormEqualsStringForm(json: String, string: String) throws {
        let set = try ClientScopeModelTestSupport.permissionSet(permissions: "[\(json)]")
        let scopes = try IncludeScope(nsid: "app.example.authFull").expandToScopeStrings(set)
        #expect(try scopes == [ClientScopeModelTestSupport.canonical(string)])
    }

    /// The example Lexicon of the specification, without its elided entries.
    static let specLexicon = """
    {
      "lexicon": 1,
      "id": "com.example.authBasicFeatures",
      "defs": {
        "main": {
          "type": "permission-set",
          "title": "Basic App Functionality",
          "title:lang": {
            "ja": "基本的なアプリ機能"
          },
          "detail": "Creation of posts and interactions",
          "detail:lang": {
            "ja": "投稿と交流の作成"
          },
          "permissions": [
            {
              "type": "permission",
              "resource": "repo",
              "collection": ["com.example.post"]
            },
            {
              "type": "permission",
              "resource": "repo",
              "collection": ["com.example.like"],
              "action": ["delete"]
            },
            {
              "type": "permission",
              "resource": "rpc",
              "inheritAud": true,
              "lxm": [
                "com.example.getFeed",
                "com.example.getProfile",
                "com.example.getPreferences",
                "com.example.putPreferences",
                "com.example.getAuthorFeed"
              ]
            },
            {
              "type": "permission",
              "resource": "rpc",
              "aud": "*",
              "lxm": ["com.example.getFeedSkeleton"]
            }
          ]
        }
      }
    }
    """

    @Test("spec: decodes the example permission set Lexicon")
    func decodesSpecLexicon() throws {
        let document = try ClientScopeModelTestSupport.decodeLexiconDocument(Self.specLexicon)
        let set = document.defs.main
        #expect(document.id == "com.example.authBasicFeatures")
        #expect(set.type == "permission-set")
        #expect(set.title == "Basic App Functionality")
        #expect(set.titleLang == ["ja": "基本的なアプリ機能"])
        #expect(set.detail == "Creation of posts and interactions")
        #expect(set.detailLang == ["ja": "投稿と交流の作成"])
        #expect(set.localizedTitle(for: ["ja-JP", "en"]) == "基本的なアプリ機能")
        #expect(set.localizedDetail(for: ["fr"]) == "Creation of posts and interactions")
        #expect(set.permissions.map(\.resource) == ["repo", "repo", "rpc", "rpc"])
        #expect(set.permissions.map(\.type) == ["permission", "permission", "permission", "permission"])
        #expect(set.permissions[0].fields == ["collection": .list([.string("com.example.post")])])
        #expect(set.permissions[1].fields == [
            "collection": .list([.string("com.example.like")]),
            "action": .list([.string("delete")]),
        ])
        #expect(set.permissions[2].fields["inheritAud"] == .bool(true))
        #expect(set.permissions[3].fields == [
            "aud": .string("*"),
            "lxm": .list([.string("com.example.getFeedSkeleton")]),
        ])
    }

    /// "Because some of the rpc permissions have the inheritAud flag set to
    /// true, the aud parameter on the include will be passed down to those
    /// specific rpc permissions."
    @Test("spec: expands the example with the aud of the include scope")
    func expandsSpecLexiconWithAudience() throws {
        let set = try ClientScopeModelTestSupport.decodeLexiconDocument(Self.specLexicon).defs.main
        let include = try IncludeScope.parse(
            "include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview"
        )
        let expansion = include.expansion(of: set)
        #expect(expansion.rejections.isEmpty)
        let scopes = try include.expandToScopeStrings(set)
        #expect(scopes == [
            "repo:com.example.post",
            "repo:com.example.like?action=delete",
            "rpc?lxm=com.example.getAuthorFeed&lxm=com.example.getFeed&lxm=com.example.getPreferences"
                + "&lxm=com.example.getProfile&lxm=com.example.putPreferences"
                + "&aud=did:web:api.example.com%23svc_appview",
            "rpc:com.example.getFeedSkeleton?aud=*",
        ])

        let granted = ATProtoScopeSet(rawScopes: Set(scopes))
        #expect(granted.rejected.isEmpty)
        #expect(granted.allowsRepo(.init(collection: "com.example.post", action: .create)))
        #expect(granted.allowsRepo(.init(collection: "com.example.like", action: .delete)))
        #expect(!granted.allowsRepo(.init(collection: "com.example.like", action: .create)))
        #expect(granted.allowsRPC(.init(lxm: "com.example.getFeed", aud: "did:web:api.example.com#svc_appview")))
        #expect(!granted.allowsRPC(.init(lxm: "com.example.getFeed", aud: "did:web:other.example.com#svc_appview")))
        #expect(granted.allowsRPC(.init(lxm: "com.example.getFeedSkeleton", aud: "did:web:other.example.com#feedgen")))
    }

    /// "If the aud had not been part of the include, the default value (no
    /// audience) would have been used instead": the inheriting permission has
    /// no audience, and is ignored.
    @Test("spec: expands the example without an aud on the include scope")
    func expandsSpecLexiconWithoutAudience() throws {
        let set = try ClientScopeModelTestSupport.decodeLexiconDocument(Self.specLexicon).defs.main
        let include = try IncludeScope.parse("include:com.example.authBasicFeatures")
        #expect(try include.expandToScopeStrings(set) == [
            "repo:com.example.post",
            "repo:com.example.like?action=delete",
            "rpc:com.example.getFeedSkeleton?aud=*",
        ])
        let expansion = include.expansion(of: set)
        #expect(expansion.rejections.map(\.index) == [2])
        #expect(expansion.rejections.map(\.reason) == [.invalidPermission])
    }

    // MARK: Decoding

    @Test("decodes a permission-set definition")
    func decodesDefinition() throws {
        let set = try ClientScopeModelTestSupport.decodePermissionSet("""
        {"type":"permission-set","title":"Calendar","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"flag":true,"count":3,"ratio":1.5,"text":"x"}
        ]}
        """)
        #expect(set.title == "Calendar")
        #expect(set.titleLang.isEmpty)
        #expect(set.detail == nil)
        #expect(set.detailLang.isEmpty)
        #expect(set.permissions == [
            LexiconPermission(resource: "repo", fields: [
                "collection": .list([.string("com.example.calendar.event")]),
                "flag": .bool(true),
                "count": .number(3),
                "ratio": .number(1.5),
                "text": .string("x"),
            ]),
        ])
    }

    @Test("a permission set built in code equals the decoded one")
    func memberwise() throws {
        let decoded = try ClientScopeModelTestSupport.decodePermissionSet("""
        {"type":"permission-set","detail":"Events","permissions":[
          {"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}
        ]}
        """)
        let built = LexiconPermissionSet(
            permissions: [
                LexiconPermission(resource: "rpc", fields: [
                    "inheritAud": .bool(true),
                    "lxm": .list([.string("com.example.calendar.listEvents")]),
                ]),
            ],
            detail: "Events"
        )
        #expect(decoded == built)
        let alias: ATProtoPermissionSet = built
        #expect(alias == decoded)
    }

    @Test(
        "refuses documents that are not a permission set",
        arguments: [
            // A whole Lexicon document is not a definition.
            #"{"lexicon":1,"id":"com.example.foo","defs":{"main":{"type":"permission-set","permissions":[]}}}"#,
            // No type, no permissions, or permissions that are not permission
            // objects.
            #"{"permissions":[]}"#,
            #"{"type":"permission-set"}"#,
            #"{"type":"permission-set","permissions":{}}"#,
            #"{"type":"permission-set","permissions":["repo:*"]}"#,
            #"{"type":"permission-set","permissions":[{"type":"permission"}]}"#,
            #"{"type":"permission-set","permissions":[{"resource":"repo"}]}"#,
            #"{"type":"permission-set","permissions":[{"type":"permission","resource":1}]}"#,
            // Mistyped title.
            #"{"type":"permission-set","title":1,"permissions":[]}"#,
        ]
    )
    func refusesInvalidDocuments(_ json: String) {
        #expect(throws: DecodingError.self) {
            try ClientScopeModelTestSupport.decodePermissionSet(json)
        }
    }

    // DIFFERENCE 13: `type` is decoded but not checked, on the set and on its
    // entries, and a malformed localisation map is ignored. A resolver that
    // needs to tell a permission set from another definition reads `type`.
    @Test("decodes without checking the type fields")
    func typeIsNotChecked() throws {
        let other = try ClientScopeModelTestSupport.decodePermissionSet(#"{"type":"query","permissions":[]}"#)
        #expect(other.type == "query")
        #expect(other.permissions.isEmpty)

        let entry = try ClientScopeModelTestSupport.decodePermissionSet(
            #"{"type":"permission-set","permissions":[{"type":"params","resource":"repo","collection":["com.example.calendar.event"]}]}"#
        )
        #expect(entry.permissions.map(\.type) == ["params"])
        #expect(
            try IncludeScope(nsid: "com.example.calendar.auth").expandToScopeStrings(entry)
                == ["repo:com.example.calendar.event"]
        )

        let lang = try ClientScopeModelTestSupport.decodePermissionSet(
            #"{"type":"permission-set","title:lang":"ja","permissions":[]}"#
        )
        #expect(lang.titleLang.isEmpty)
    }
}
