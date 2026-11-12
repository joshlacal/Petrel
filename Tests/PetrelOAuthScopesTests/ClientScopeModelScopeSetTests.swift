import PetrelOAuthScopes
import Testing

/// `ATProtoScopeSet`: the vectors of `scope-permissions.test.ts`,
/// `scope-permissions-transition.test.ts` and `scopes-set.test.ts` of
/// `@atproto/oauth-scopes`, and what an OAuth client asks of a granted scope
/// value: parsing it leniently, writing it back, and whether it covers what
/// was requested.
///
/// The set always honors the transitional scopes, as the reference
/// `ScopePermissionsTransition` does.
@Suite("Client scope model: ATProtoScopeSet")
struct ClientScopeModelScopeSetTests {
    private static let service = "did:web:example.com#foo"

    // MARK: scope-permissions.test.ts

    @Test("allowsAccount: properly allows account:email")
    func accountEmail() {
        let set = ATProtoScopeSet(scope: "account:email")
        #expect(set.allowsAccount(.init(attr: .email, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .email, action: .manage)))
        #expect(!set.allowsAccount(.init(attr: .repo, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .repo, action: .manage)))
        #expect(!set.allowsAccount(.init(attr: .status, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .status, action: .manage)))
    }

    @Test("allowsBlob: allows any mime with blob:*/*")
    func blobAny() {
        let set = ATProtoScopeSet(scope: "blob:*/*")
        #expect(set.allowsBlob(.init(mime: "image/png")))
        #expect(set.allowsBlob(.init(mime: "application/json")))
    }

    @Test("allowsBlob: only allows images with blob:image/*")
    func blobImages() {
        let set = ATProtoScopeSet(scope: "blob:image/*")
        #expect(set.allowsBlob(.init(mime: "image/png")))
        #expect(!set.allowsBlob(.init(mime: "application/json")))
    }

    static let invalidBlobScopes: [(String, ScopeParseError)] = [
        ("blob:*", .invalidPositionalValue(prefix: "blob", key: "accept", value: "*")),
        ("blob:/image", .invalidPositionalValue(prefix: "blob", key: "accept", value: "/image")),
    ]

    @Test("allowsBlob: ignores invalid scopes", arguments: invalidBlobScopes)
    func blobInvalid(scope: String, error: ScopeParseError) {
        let set = ATProtoScopeSet(scope: scope)
        #expect(set.scopes.isEmpty)
        #expect(set.unrecognized == [scope])
        #expect(set.rejected == [scope: error])
        #expect(!set.allowsBlob(.init(mime: "image/png")))
        #expect(!set.allowsBlob(.init(mime: "application/json")))
    }

    @Test("allowsRepo: allows any repo action with repo:*")
    func repoAny() {
        let set = ATProtoScopeSet(scope: "repo:*")
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
        #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
    }

    @Test("allowsRepo: allows specific repo actions")
    func repoActions() {
        let set = ATProtoScopeSet(scope: "repo:*?action=create")
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
        // Control
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
        #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
    }

    @Test("allowsRepo: allows a specific repo collection and action")
    func repoCollectionAndAction() {
        let set = ATProtoScopeSet(scope: "repo:com.example.foo?action=create")
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        // Control
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
        #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
        #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
    }

    @Test("allowsRPC: ignores rpc:*?lxm=*")
    func rpcInvalid() {
        let set = ATProtoScopeSet(scope: "rpc:*?lxm=*")
        #expect(set.unrecognized == ["rpc:*?lxm=*"])
        #expect(set.rejected == ["rpc:*?lxm=*": .positionalAndNamedConflict(prefix: "rpc", key: "lxm")])
        #expect(!set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com")))
        #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
    }

    @Test("allowsRPC: allows constraining lxm")
    func rpcMethod() {
        let set = ATProtoScopeSet(scope: "rpc:app.bsky.feed.getFeed?aud=*")
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:plc:blahbla")))
        // Control
        #expect(!set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com")))
    }

    @Test("allowsRPC: allows constraining aud")
    func rpcAudience() {
        let set = ATProtoScopeSet(scope: "rpc:*?aud=did:web:example.com%23foo")
        #expect(set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com#foo")))
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#foo")))
        // Control: wrong service, then no service id.
        #expect(!set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:bar.com#foo")))
        #expect(!set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com")))
    }

    @Test("allowsRPC: allows constraining lxm and aud")
    func rpcMethodAndAudience() {
        let set = ATProtoScopeSet(scope: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23foo")
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#foo")))
        // Control
        #expect(!set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com")))
        #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:plc:blahbla")))
    }

    @Test("allowsRPC: the combined did#serviceId form is required when granted")
    func rpcCombinedAudience() {
        let combined = ATProtoScopeSet(scope: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_appview")
        #expect(combined.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#bsky_appview")))
        #expect(!combined.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
        #expect(throws: ScopeDenied(needed: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com")) {
            try combined.requireRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com"))
        }

        let wildcard = ATProtoScopeSet(scope: "rpc:app.bsky.feed.getFeed?aud=*")
        #expect(wildcard.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#bsky_appview")))
    }

    @Test("allowsIdentity")
    func identity() {
        let handle = ATProtoScopeSet(scope: "identity:handle")
        #expect(handle.allowsIdentity(.init(attr: .handle)))
        #expect(!handle.allowsIdentity(.init(attr: .any)))

        let any = ATProtoScopeSet(scope: "identity:*")
        #expect(any.allowsIdentity(.init(attr: .handle)))
        #expect(any.allowsIdentity(.init(attr: .any)))

        // No transitional scope grants identity control.
        let transitional = ATProtoScopeSet(scope: "atproto transition:generic transition:chat.bsky transition:email")
        #expect(!transitional.allowsIdentity(.init(attr: .handle)))
        #expect(!transitional.allowsIdentity(.init(attr: .any)))
    }

    @Test("permissions of several scopes add up")
    func combined() {
        let set = ATProtoScopeSet(scope: "repo:com.example.foo?action=create repo:com.example.bar?action=delete blob:image/* blob:video/mp4 account:repo?action=manage")
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(set.allowsRepo(.init(collection: "com.example.bar", action: .delete)))
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .delete)))
        #expect(!set.allowsRepo(.init(collection: "com.example.bar", action: .create)))
        #expect(set.allowsBlob(.init(mime: "image/png")))
        #expect(set.allowsBlob(.init(mime: "video/mp4")))
        #expect(!set.allowsBlob(.init(mime: "video/webm")))
        #expect(set.allowsAccount(.init(attr: .repo, action: .manage)))
        #expect(set.allowsAccount(.init(attr: .repo, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .email, action: .read)))
    }

    // MARK: scope-permissions-transition.test.ts

    @Test("transition: allows reading the email with transition:email")
    func transitionEmail() {
        let set = ATProtoScopeSet(scope: "transition:email account:repo")
        #expect(set.allowsAccount(.init(attr: .email, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .email, action: .manage)))
        #expect(set.allowsAccount(.init(attr: .repo, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .repo, action: .manage)))
        #expect(!set.allowsAccount(.init(attr: .status, action: .read)))
        #expect(!set.allowsAccount(.init(attr: .status, action: .manage)))
    }

    @Test("transition: allows blob with transition:generic")
    func transitionBlob() {
        let set = ATProtoScopeSet(scope: "transition:generic")
        #expect(set.allowsBlob(.init(mime: "foo/bar")))
        #expect(!ATProtoScopeSet(scope: "transition:email transition:chat.bsky").allowsBlob(.init(mime: "foo/bar")))
    }

    @Test("transition: allows repo with transition:generic")
    func transitionRepo() {
        let set = ATProtoScopeSet(scope: "transition:generic")
        #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
        #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
        #expect(!ATProtoScopeSet(scope: "transition:email transition:chat.bsky").allowsRepo(.init(collection: "com.example.foo", action: .create)))
    }

    @Test("transition: allows rpc with transition:generic")
    func transitionRPC() {
        let set = ATProtoScopeSet(scope: "transition:generic")
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "*", aud: "did:web:example.com")))
    }

    @Test("transition: rejects chat methods with transition:generic alone")
    func transitionGenericExcludesChat() {
        let set = ATProtoScopeSet(scope: "transition:generic")
        #expect(!set.allowsRPC(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
        #expect(!set.allowsRPC(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))
        // Control
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
        // Only the "chat.bsky." namespace is carved out.
        #expect(set.allowsRPC(.init(lxm: "chat.bskyx.message.send", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "chat.other.message.send", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "app.chat.bsky.send", aud: "did:web:example.com")))
    }

    @Test("transition: allows chat.bsky.* methods with transition:generic and transition:chat.bsky")
    func transitionChatWithGeneric() {
        let set = ATProtoScopeSet(scope: "transition:generic transition:chat.bsky")
        #expect(set.allowsRPC(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "*", aud: "did:web:example.com")))
    }

    /// As in the reference implementation, `transition:chat.bsky` allows the
    /// `chat.bsky.*` methods whether or not `transition:generic` is present.
    /// (The OAuth specification says it "depends on and does not function
    /// without the transition:generic scope".)
    @Test("transition: allows chat.bsky.* methods with transition:chat.bsky alone")
    func transitionChatAlone() {
        let set = ATProtoScopeSet(scope: "transition:chat.bsky")
        #expect(set.allowsRPC(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
        #expect(set.allowsRPC(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))
        // Control
        #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
        #expect(!set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
        #expect(!set.allowsRPC(.init(lxm: "*", aud: "did:web:example.com")))
    }

    @Test("transition: granular rpc permissions still apply next to transitional scopes")
    func transitionWithGranular() {
        let chat = ATProtoScopeSet(scope: "transition:chat.bsky rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23foo")
        #expect(chat.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: Self.service)))
        #expect(!chat.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:other.example#foo")))
        #expect(!chat.allowsRPC(.init(lxm: "app.bsky.feed.getTimeline", aud: Self.service)))
        #expect(chat.allowsRPC(.init(lxm: "chat.bsky.convo.listConvos", aud: Self.service)))

        let generic = ATProtoScopeSet(scope: "transition:generic rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo")
        #expect(generic.allowsRPC(.init(lxm: "chat.bsky.convo.getConvo", aud: Self.service)))
        #expect(!generic.allowsRPC(.init(lxm: "chat.bsky.convo.getConvo", aud: "did:web:other.example#foo")))
        #expect(!generic.allowsRPC(.init(lxm: "chat.bsky.convo.listConvos", aud: Self.service)))
    }

    // MARK: scopes-set.test.ts

    @Test("initializes with an empty set")
    func emptySet() throws {
        for set in try [ATProtoScopeSet([]), ATProtoScopeSet(scope: ""), ATProtoScopeSet(scope: "   "), ATProtoScopeSet(strict: "")] {
            #expect(set.rawScopes.isEmpty)
            #expect(set.scopes.isEmpty)
            #expect(set.unrecognized.isEmpty)
            #expect(set.scopeString == "")
            #expect(set.normalizedScopeString == "")
            #expect(!set.includesAtproto)
        }
    }

    /// `repo:read` is how the reference test names an arbitrary member. It is
    /// not a valid repo scope ("read" is not an NSID), so it is kept as an
    /// unrecognized string.
    @Test("keeps scopes it was given")
    func addsScopes() {
        let set = ATProtoScopeSet(scope: "repo:read")
        #expect(set.rawScopes == ["repo:read"])
        #expect(set.scopes.isEmpty)
        #expect(set.unrecognized == ["repo:read"])
        #expect(set.rejected == ["repo:read": .invalidPositionalValue(prefix: "repo", key: "collection", value: "read")])
        #expect(set.scopeString == "repo:read")

        let grown = ATProtoScopeSet(rawScopes: set.rawScopes.union(["atproto", "transition:generic"]))
        #expect(grown.scopes == [.atproto, .transitionGeneric])
        #expect(grown.rawScopes.contains("atproto"))
        #expect(!grown.rawScopes.contains("transition:email"))
        #expect(grown.scopeString == "atproto repo:read transition:generic")
    }

    @Test("matches included scopes")
    func matchesIncluded() {
        let set = ATProtoScopeSet(scope: "repo:com.example.foo")
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(!set.allowsRepo(.init(collection: "com.example.bar", action: .create)))
    }

    @Test("does not match missing scopes")
    func doesNotMatchMissing() {
        let set = ATProtoScopeSet(scope: "repo:com.example.foo?action=create")
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .delete)))
        #expect(throws: ScopeDenied(needed: "repo:com.example.foo?action=delete")) {
            try set.requireRepo(.init(collection: "com.example.foo", action: .delete))
        }
    }

    @Test("does not match invalid scopes")
    func doesNotMatchInvalid() {
        let set = ATProtoScopeSet(scope: "repo:not-a-valid-nsid")
        #expect(set.unrecognized == ["repo:not-a-valid-nsid"])
        #expect(!set.allowsRepo(.init(collection: "not-a-valid-nsid", action: .create)))
    }

    // MARK: Lenient parsing

    // DIFFERENCE 14: the set holds the scope strings as given. `scopes` and
    // `scopeString` are in sorted order of those strings (not the order they
    // were given in), and `scopeString` writes them verbatim (not in canonical
    // form).
    @Test("keeps the strings it does not understand")
    func lenient() throws {
        let granted = "atproto transition:generic repo:app.bsky.feed.post?action=create "
            + "rpc:*?aud=did:web:api.bsky.app%23bsky_appview blob:*/* account:email identity:handle "
            + "include:app.bsky.authFull future:thing repo:com.example.* openid atproto future:thing"
        let set = ATProtoScopeSet(scope: granted)

        #expect(try set.scopes.map { try $0.canonicalScopeString() } == [
            "account:email",
            "atproto",
            "blob:*/*",
            "identity:handle",
            "include:app.bsky.authFull",
            "repo:app.bsky.feed.post?action=create",
            "rpc:*?aud=did:web:api.bsky.app%23bsky_appview",
            "transition:generic",
        ])
        #expect(set.unrecognized == ["future:thing", "openid", "repo:com.example.*"])
        #expect(set.rejected == [
            "future:thing": .unknownPrefix("future:thing"),
            "openid": .unknownPrefix("openid"),
            "repo:com.example.*": .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.*"),
        ])
        // Sorted, duplicates dropped.
        #expect(set.scopeString == "account:email atproto blob:*/* future:thing identity:handle "
            + "include:app.bsky.authFull openid repo:app.bsky.feed.post?action=create repo:com.example.* "
            + "rpc:*?aud=did:web:api.bsky.app%23bsky_appview transition:generic")
        #expect(set.rawScopes == Set(granted.split(separator: " ").map(String.init)))
        #expect(set.includesAtproto)
    }

    @Test("an unrecognized string never grants anything")
    func unrecognizedGrantsNothing() {
        let set = ATProtoScopeSet(scope: "repo:com.example.* rpc:*?aud=* blob:* account:* identity:all transition:all")
        #expect(set.scopes.isEmpty)
        #expect(set.unrecognized.count == 6)
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(!set.allowsRPC(.init(lxm: "com.example.foo", aud: Self.service)))
        #expect(!set.allowsBlob(.init(mime: "image/png")))
        #expect(!set.allowsAccount(.init(attr: .email, action: .read)))
        #expect(!set.allowsIdentity(.init(attr: .handle)))
        #expect(!set.includesAtproto)
    }

    // DIFFERENCE 15: a scope value is split on SPACE only (RFC 6749). Other
    // whitespace is part of a string, which then is not a scope.
    @Test("splits on spaces only")
    func lenientWhitespace() {
        let set = ATProtoScopeSet(scope: "  atproto \n transition:generic\t\tblob:*/*  ")
        #expect(set.rawScopes == ["atproto", "\n", "transition:generic\t\tblob:*/*"])
        #expect(set.scopes == [.atproto])
        #expect(set.unrecognized == ["\n", "transition:generic\t\tblob:*/*"])

        let spaces = ATProtoScopeSet(scope: "  atproto   transition:generic  ")
        #expect(spaces.scopes == [.atproto, .transitionGeneric])
        #expect(spaces.unrecognized.isEmpty)
        #expect(spaces.scopeString == "atproto transition:generic")
    }

    // DIFFERENCE 16: scopes are not de-duplicated by meaning. Two spellings of
    // one permission are two members; `normalizedScopeString` folds them.
    @Test("keeps every spelling of a scope")
    func spellings() {
        let set = ATProtoScopeSet(scope: "repo?collection=* repo:* repo:*?action=create&action=update&action=delete account:email?action=read")
        #expect(set.scopes.count == 4)
        #expect(set.scopeString == "account:email?action=read repo:* repo:*?action=create&action=update&action=delete repo?collection=*")
        #expect(set.normalizedScopeString == "account:email repo:*")
    }

    // DIFFERENCE 17: `normalizedScopeString` keeps unrecognized strings.
    @Test("normalizedScopeString sorts and writes recognized scopes canonically")
    func normalized() {
        let set = ATProtoScopeSet(scope: "transition:generic future:thing repo?collection=* atproto blob:image/png")
        #expect(set.normalizedScopeString == "atproto blob:image/png future:thing repo:* transition:generic")
        #expect(set.scopeString == "atproto blob:image/png future:thing repo?collection=* transition:generic")
    }

    static let scopeStrings: [String] = [
        "",
        "atproto",
        "atproto transition:generic",
        "atproto transition:generic transition:chat.bsky transition:email",
        "atproto repo:app.bsky.feed.post rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview",
        "atproto include:app.bsky.authFull?aud=did:web:api.bsky.app%23bsky_appview blob:image/* blob:video/*",
        "atproto future:thing another:one?x=y repo:com.example.*",
        "repo?collection=com.example.b&collection=com.example.a blob?accept=image/svg+xml&accept=image/png",
        "atproto rpc:com.example.method?aud=did:web:localhost%253A3000%23svc",
    ]

    @Test("scopeString round-trips", arguments: scopeStrings)
    func scopeStringRoundTrip(_ string: String) {
        let set = ATProtoScopeSet(scope: string)
        let reparsed = ATProtoScopeSet(scope: set.scopeString)
        #expect(reparsed == set)
        #expect(reparsed.rawScopes == set.rawScopes)
        #expect(reparsed.scopes == set.scopes)
        #expect(reparsed.unrecognized == set.unrecognized)
        #expect(reparsed.scopeString == set.scopeString)
        #expect(set.scopes.count + set.unrecognized.count == string.split(separator: " ").count)
        #expect(set.rawScopes == Set(string.split(separator: " ").map(String.init)))
    }

    // MARK: Strict parsing

    @Test("strict parsing accepts valid scope values")
    func strict() throws {
        let set = try ATProtoScopeSet(strict: "atproto transition:generic repo:com.example.foo")
        #expect(set.rawScopes == ["atproto", "transition:generic", "repo:com.example.foo"])
        #expect(set.scopes.count == 3)
        #expect(set.unrecognized.isEmpty)
        #expect(try ATProtoScopeSet(strict: "").rawScopes.isEmpty)
        #expect(try ATProtoScopeSet(strict: "atproto") == ATProtoScopeSet(scope: "atproto"))
    }

    static let strictFailures: [(String, ScopeParseError)] = [
        ("atproto future:thing", .unknownPrefix("future:thing")),
        ("atproto repo:com.example.*", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.*")),
        ("atproto rpc:*?aud=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        ("openid atproto", .unknownPrefix("openid")),
        ("atproto\ttransition:generic", .unknownPrefix("atproto\ttransition:generic")),
        ("atproto\n", .unknownPrefix("atproto\n")),
        ("atproto repo:com.example.foo\n", .notAScopeToken("repo:com.example.foo\n")),
    ]

    @Test("strict parsing reports the first invalid string", arguments: strictFailures)
    func strictRejects(string: String, error: ScopeParseError) {
        #expect(throws: error) { try ATProtoScopeSet(strict: string) }
    }

    // DIFFERENCE 18: strict parsing tolerates leading, trailing and repeated
    // spaces, like lenient parsing.
    @Test(
        "strict parsing ignores extra spaces",
        arguments: ["atproto  transition:generic", " atproto transition:generic", "atproto transition:generic ", "  atproto   transition:generic  "]
    )
    func strictExtraSpaces(_ string: String) throws {
        let set = try ATProtoScopeSet(strict: string)
        #expect(set.rawScopes == ["atproto", "transition:generic"])
        #expect(try ATProtoScopeSet(strict: " ").rawScopes.isEmpty)
    }

    @Test("strict and lenient parsing agree on valid input", arguments: scopeStrings)
    func strictAgreesWithLenient(_ string: String) {
        let lenient = ATProtoScopeSet(scope: string)
        let strict = try? ATProtoScopeSet(strict: string)
        if lenient.unrecognized.isEmpty {
            #expect(strict == lenient)
            #expect(strict?.scopeString == lenient.scopeString)
        } else {
            #expect(strict == nil)
        }
    }

    // MARK: Set semantics

    @Test("equality ignores order and duplicates")
    func equality() throws {
        let one = ATProtoScopeSet(scope: "atproto repo:* future:thing")
        let two = ATProtoScopeSet(scope: "future:thing repo:* atproto atproto")
        #expect(one == two)
        #expect(one.hashValue == two.hashValue)
        #expect(one.scopeString == two.scopeString)
        #expect(one != ATProtoScopeSet(scope: "atproto repo:*"))
        #expect(one != ATProtoScopeSet(scope: "atproto repo:* future:other"))
        #expect(ATProtoScopeSet(scope: "atproto repo:*") != ATProtoScopeSet(scope: "atproto repo:*?action=create"))

        let literal: ATProtoScopeSet = [.atproto, .transitionGeneric, .atproto]
        #expect(literal == ATProtoScopeSet([.transitionGeneric, .atproto]))
        #expect(literal.scopes == [.atproto, .transitionGeneric])
        #expect(try literal == ATProtoScopeSet(strict: "atproto transition:generic"))
    }

    /// See DIFFERENCE 16: equality is by scope string, so two sets granting
    /// the same access through different spellings are not equal. Their
    /// normalized scope strings are.
    @Test("equality is by scope string")
    func equalityIsBySpelling() {
        let one = ATProtoScopeSet(scope: "atproto repo:*")
        let two = ATProtoScopeSet(scope: "atproto repo?collection=*")
        #expect(one != two)
        #expect(one.normalizedScopeString == two.normalizedScopeString)
        #expect(one.covers(two))
        #expect(two.covers(one))
    }

    @Test("membership is by scope string, coverage by access")
    func contains() throws {
        let set = try ATProtoScopeSet(strict: "atproto repo:*")
        #expect(set.rawScopes.contains("atproto"))
        #expect(set.rawScopes.contains("repo:*"))
        // Granted, but not a member.
        #expect(!set.rawScopes.contains("repo:com.example.foo"))
        #expect(try set.covers(ATProtoScope("repo:com.example.foo")))
        #expect(try set.covers(ATProtoScope("repo?collection=*")))
    }

    @Test("includesAtproto")
    func includesAtproto() {
        #expect(ATProtoScopeSet(scope: "atproto").includesAtproto)
        #expect(ATProtoScopeSet(scope: "transition:generic atproto").includesAtproto)
        #expect(!ATProtoScopeSet(scope: "transition:generic repo:*").includesAtproto)
        #expect(!ATProtoScopeSet(scope: "atproto:foo ATPROTO atproto2").includesAtproto)
    }

    // MARK: Coverage

    /// (granted, needed, covered)
    static let coverage: [(String, String, Bool)] = [
        // Static scopes are covered by their own presence only.
        ("atproto", "atproto", true),
        ("transition:generic", "atproto", false),
        ("atproto repo:* blob:*/* rpc:*?aud=did:web:example.com%23foo", "transition:generic", false),
        ("atproto transition:generic", "transition:chat.bsky", false),
        ("transition:email", "transition:email", true),

        // repo
        ("repo:*", "repo:com.example.foo", true),
        ("repo:*", "repo:com.example.foo?action=create", true),
        ("repo:*", "repo:*", true),
        ("repo:*", "repo?collection=com.example.foo&collection=com.example.bar", true),
        ("repo:*?action=create", "repo:com.example.foo?action=create", true),
        ("repo:*?action=create", "repo:com.example.foo", false),
        ("repo:*?action=create", "repo:*", false),
        ("repo:com.example.foo", "repo:com.example.foo", true),
        ("repo:com.example.foo", "repo:com.example.foo?action=delete", true),
        ("repo:com.example.foo", "repo:com.example.bar", false),
        ("repo:com.example.foo", "repo:*", false),
        ("repo:com.example.foo", "repo:*?action=create", false),
        ("repo:com.example.foo", "repo?collection=com.example.foo&collection=com.example.bar", false),
        ("repo:com.example.foo repo:com.example.bar", "repo?collection=com.example.foo&collection=com.example.bar", true),
        // Several scopes together.
        ("repo:com.example.foo?action=create repo:com.example.foo?action=update&action=delete", "repo:com.example.foo", true),
        ("repo:com.example.foo?action=create repo:com.example.foo?action=update", "repo:com.example.foo", false),
        ("repo:com.example.foo?action=create repo:com.example.bar?action=delete", "repo?collection=com.example.foo&collection=com.example.bar&action=create", false),

        // rpc
        ("rpc:*?aud=did:web:example.com%23foo", "rpc:com.example.a?aud=did:web:example.com%23foo", true),
        ("rpc:*?aud=did:web:example.com%23foo", "rpc:*?aud=did:web:example.com%23foo", true),
        ("rpc:*?aud=did:web:example.com%23foo", "rpc:com.example.a?aud=did:web:example.com%23bar", false),
        ("rpc:*?aud=did:web:example.com%23foo", "rpc:com.example.a?aud=*", false),
        ("rpc:com.example.a?aud=*", "rpc:com.example.a?aud=did:web:example.com%23foo", true),
        ("rpc:com.example.a?aud=*", "rpc:com.example.a?aud=*", true),
        ("rpc:com.example.a?aud=*", "rpc:com.example.b?aud=did:web:example.com%23foo", false),
        ("rpc:com.example.a?aud=*", "rpc:*?aud=did:web:example.com%23foo", false),
        ("rpc:com.example.a?aud=did:web:example.com%23foo", "rpc:com.example.a?aud=did:web:example.com%23foo", true),
        ("rpc:com.example.a?aud=did:web:example.com%23foo", "rpc?lxm=com.example.a&lxm=com.example.b&aud=did:web:example.com%23foo", false),
        ("rpc:com.example.a?aud=* rpc:com.example.b?aud=did:web:example.com%23foo", "rpc?lxm=com.example.a&lxm=com.example.b&aud=did:web:example.com%23foo", true),
        ("rpc:com.example.a?aud=* rpc:com.example.b?aud=did:web:example.com%23foo", "rpc?lxm=com.example.a&lxm=com.example.b&aud=*", false),

        // blob
        ("blob:*/*", "blob:image/png", true),
        ("blob:*/*", "blob:image/*", true),
        ("blob:*/*", "blob:*/*", true),
        ("blob:*/*", "blob?accept=image/*&accept=video/mp4", true),
        ("blob:image/*", "blob:image/png", true),
        ("blob:image/*", "blob:image/*", true),
        ("blob:image/*", "blob:*/*", false),
        ("blob:image/*", "blob:video/*", false),
        ("blob:image/*", "blob?accept=image/png&accept=video/mp4", false),
        ("blob:image/png", "blob:image/png", true),
        ("blob:image/png", "blob:image/*", false),
        ("blob:image/png", "blob:image/jpeg", false),
        ("blob:image/* blob:video/mp4", "blob?accept=image/png&accept=video/mp4", true),
        ("blob:image/png blob:image/jpeg", "blob:image/*", false),

        // account
        ("account:email", "account:email", true),
        ("account:email", "account:email?action=manage", false),
        ("account:email?action=manage", "account:email", true),
        ("account:email?action=manage", "account:email?action=manage", true),
        ("account:email?action=manage", "account:repo", false),
        ("account:status", "account:email", false),

        // identity
        ("identity:*", "identity:handle", true),
        ("identity:*", "identity:*", true),
        ("identity:handle", "identity:handle", true),
        ("identity:handle", "identity:*", false),

        // include: only by its own presence.
        ("include:com.example.auth", "include:com.example.auth", true),
        ("include:com.example.auth", "include:com.example.auth?aud=did:web:example.com%23foo", false),
        ("include:com.example.auth?aud=did:web:example.com%23foo", "include:com.example.auth", false),
        ("repo:* rpc:*?aud=did:web:example.com%23foo", "include:com.example.auth", false),
        ("include:com.example.auth", "repo:com.example.post", false),

        // Transitional scopes stand in for the access they are equivalent to.
        ("transition:generic", "repo:*", true),
        ("transition:generic", "repo:com.example.foo?action=delete", true),
        ("transition:generic", "blob:*/*", true),
        ("transition:generic", "blob:image/png", true),
        ("transition:generic", "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo", false),
        ("transition:generic", "rpc?lxm=app.bsky.feed.getFeed&lxm=chat.bsky.convo.getConvo&aud=*", false),
        ("transition:generic transition:chat.bsky", "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo", true),
        ("transition:generic", "account:email", false),
        ("transition:generic", "identity:handle", false),
        ("transition:email", "account:email", true),
        ("transition:email", "account:email?action=manage", false),
        ("transition:email", "account:repo", false),
        ("transition:email", "repo:com.example.foo", false),

        // Whole sets.
        ("atproto repo:* blob:image/*", "atproto repo:com.example.foo blob:image/png", true),
        ("atproto repo:* blob:image/*", "", true),
        ("", "", true),
        ("", "atproto", false),
        ("repo:* blob:image/*", "atproto repo:com.example.foo blob:image/png", false),
        ("atproto repo:* blob:image/*", "atproto repo:com.example.foo blob:video/mp4", false),
        // As in the reference implementation, `transition:chat.bsky` works
        // without `transition:generic`.
        ("transition:chat.bsky", "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo", true),
        ("transition:chat.bsky", "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23foo", false),
        // DIFFERENCE 19: `transition:generic` does not reach the chat.bsky
        // methods, so alone it does not cover a need for every method.
        ("transition:generic", "rpc:*?aud=did:web:example.com%23foo", false),
    ]

    @Test("covers", arguments: coverage)
    func covers(granted: String, needed: String, expected: Bool) throws {
        let grantedSet = try ATProtoScopeSet(strict: granted)
        let neededSet = try ATProtoScopeSet(strict: needed)
        #expect(grantedSet.covers(neededSet) == expected)
        if neededSet.scopes.count == 1 {
            #expect(grantedSet.covers(neededSet.scopes[0]) == expected)
        }
    }

    // PENDING-FIX 3 (fixed in the shared target): transitional scopes stand
    // in for rpc permissions whatever audience is needed, and for the
    // wildcard method when both `transition:generic` and
    // `transition:chat.bsky` are granted.
    /// (granted, needed, covered)
    static let pendingCoverage: [(String, String, Bool)] = [
        ("transition:generic", "rpc:app.bsky.feed.getFeed?aud=*", true),
        ("transition:generic transition:chat.bsky", "rpc:chat.bsky.convo.getConvo?aud=*", true),
        ("transition:generic transition:chat.bsky", "rpc:*?aud=did:web:example.com%23foo", true),
    ]

    @Test("covers: transitional scopes and wildcard needs", arguments: pendingCoverage)
    func coversPending(granted: String, needed: String, expected: Bool) throws {
        let grantedSet = try ATProtoScopeSet(strict: granted)
        let neededSet = try ATProtoScopeSet(strict: needed)
        #expect(grantedSet.covers(neededSet) == expected)
        #expect(grantedSet.covers(neededSet.scopes[0]) == expected)
    }

    @Test("a set covers itself", arguments: coverage)
    func coversItself(granted: String, needed: String, expected _: Bool) throws {
        for string in [granted, needed] {
            let set = try ATProtoScopeSet(strict: string)
            #expect(set.covers(set))
        }
    }

    // DIFFERENCE 20 (resolved in the shared target): a string of the needed
    // set that is not a recognized scope cannot be reasoned about, so it is
    // covered only when the granted set holds the identical string.
    @Test("an unrecognized string is covered only by the identical string")
    func coversUnrecognized() {
        let granted = ATProtoScopeSet(scope: "atproto repo:* future:thing")
        #expect(granted.covers(ATProtoScopeSet(scope: "atproto future:thing")))
        #expect(granted.covers(ATProtoScopeSet(scope: "future:thing repo:com.example.foo")))
        #expect(!granted.covers(ATProtoScopeSet(scope: "atproto future:other")))
        #expect(!granted.covers(ATProtoScopeSet(scope: "future:thing?x=y")))
        #expect(!ATProtoScopeSet(scope: "atproto repo:*").covers(granted))
        #expect(!ATProtoScopeSet(scope: "atproto").covers(granted))
    }

    /// The practical question after a token response: was everything that
    /// was requested granted?
    @Test("compares a granted scope value against the requested one")
    func requestedVersusGranted() throws {
        let requested = try ATProtoScopeSet([
            .atproto,
            .repo(collections: ["app.bsky.feed.post", "app.bsky.feed.like"]),
            .rpc(lxm: ["app.bsky.feed.getTimeline"], aud: "did:web:api.bsky.app#bsky_appview"),
            .blob(accept: ["image/*"]),
            .account(attribute: .email),
        ])
        // Sorted; see DIFFERENCE 14.
        #expect(requested.scopeString == "account:email atproto blob:image/* "
            + "repo?collection=app.bsky.feed.like&collection=app.bsky.feed.post "
            + "rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview")

        let full = ATProtoScopeSet(scope: requested.scopeString)
        #expect(full == requested)
        #expect(full.includesAtproto)
        #expect(full.covers(requested))

        // The user unticked the email permission and narrowed the repo one.
        let partial = ATProtoScopeSet(scope: "atproto repo:app.bsky.feed.post "
            + "rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview blob:image/*")
        #expect(partial.includesAtproto)
        #expect(!partial.covers(requested))
        #expect(requested.covers(partial))
        #expect(requested.scopes.filter { !partial.covers($0) }.map(ClientScopeModelTestSupport.resource(of:)) == ["account", "repo"])
    }

    // PENDING-FIX 1 (fixed in the shared target): a set built from typed
    // scopes holds those scopes, and its `scopeString` parses back to them.
    // `scopeString` keeps "%" and "+" of a parameter value escaped, where the
    // canonical form writes them bare and does not read back.
    @Test("a set built from typed scopes keeps values containing % or +")
    func typedScopesSurvive() throws {
        let blob = try ATProtoScope.blob(accept: ["image/png", "image/svg+xml"])
        let rpc = try ATProtoScope.rpc(lxm: ["com.example.method"], aud: "did:web:localhost%3A3000#svc")
        let set = ATProtoScopeSet([.atproto, blob, rpc])
        #expect(set.unrecognized.isEmpty)
        #expect(set.scopes.count == 3)
        #expect(set.allowsBlob(.init(mime: "image/svg+xml")))
        #expect(set.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:localhost%3A3000#svc")))
        #expect(set.covers(blob))
        #expect(set.covers(rpc))

        #expect(blob.scopeString == "blob?accept=image/png&accept=image/svg%2Bxml")
        #expect(rpc.scopeString == "rpc:com.example.method?aud=did:web:localhost%253A3000%23svc")
        #expect(try blob.canonicalScopeString() == "blob?accept=image/png&accept=image/svg+xml")
        #expect(try rpc.canonicalScopeString() == "rpc:com.example.method?aud=did:web:localhost%3A3000%23svc")
        #expect(set.scopeString == "atproto blob?accept=image/png&accept=image/svg%2Bxml "
            + "rpc:com.example.method?aud=did:web:localhost%253A3000%23svc")

        let reparsed = ATProtoScopeSet(scope: set.scopeString)
        #expect(reparsed == set)
        #expect(reparsed.unrecognized.isEmpty)
        #expect(reparsed.covers(set))
        #expect(set.covers(reparsed))
        #expect(reparsed.allowsBlob(.init(mime: "image/svg+xml")))
        #expect(reparsed.allowsRPC(.init(lxm: "com.example.method", aud: "did:web:localhost%3A3000#svc")))
    }
}
