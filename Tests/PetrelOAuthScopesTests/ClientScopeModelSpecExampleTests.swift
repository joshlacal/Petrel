import PetrelOAuthScopes
import Testing

/// Every example string of the permission specification
/// (`specs/permission.mdx`), in the order the specification gives them.
@Suite("Client scope model: permission specification examples")
struct ClientScopeModelSpecExampleTests {
    // MARK: Valid examples

    /// (example, canonical form)
    static let validExamples: [(String, String)] = [
        // repo
        ("repo:app.example.profile", "repo:app.example.profile"),
        ("repo:app.example.profile?action=create&action=update&action=delete", "repo:app.example.profile"),
        ("repo?collection=app.example.profile&collection=app.example.post", "repo?collection=app.example.post&collection=app.example.profile"),
        ("repo:*", "repo:*"),
        ("repo:*?action=delete", "repo:*?action=delete"),
        // rpc
        ("rpc:app.example.moderation.createReport?aud=*", "rpc:app.example.moderation.createReport?aud=*"),
        ("rpc?lxm=*&aud=did:web:api.example.com%23svc_appview", "rpc:*?aud=did:web:api.example.com%23svc_appview"),
        // blob
        ("blob:*/*", "blob:*/*"),
        ("blob?accept=video/*&accept=text/html", "blob?accept=text/html&accept=video/*"),
        // account
        ("account:email", "account:email"),
        ("account:repo?action=manage", "account:repo?action=manage"),
        ("account?action=manage&attr=repo", "account:repo?action=manage"),
        // identity
        ("identity:handle", "identity:handle"),
        ("identity:*", "identity:*"),
        ("identity:*?", "identity:*"),
        // include
        ("include:app.example.authFull?aud=did:web:api.example.com%23svc_chat", "include:app.example.authFull?aud=did:web:api.example.com%23svc_chat"),
        ("include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview", "include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview"),
    ]

    @Test("valid examples parse and format canonically", arguments: validExamples)
    func validExampleFormats(example: String, canonical: String) throws {
        let scope = try ATProtoScope(example)
        #expect(try scope.canonicalScopeString() == canonical)
        #expect(scope.scopeString == canonical)
    }

    @Test("the canonical form of a valid example is a fixed point", arguments: validExamples)
    func validExampleRoundTrips(example _: String, canonical: String) throws {
        #expect(try ATProtoScope(canonical).canonicalScopeString() == canonical)
    }

    // MARK: Meaning of the valid examples

    @Test("repo: full permission on a single record type")
    func repoSingleCollection() throws {
        let permission = try RepoPermission.parse("repo:app.example.profile")
        #expect(permission.collection == [.nsid("app.example.profile")])
        #expect(permission.action == [.create, .update, .delete])
        #expect(
            try ATProtoScope.repo(collections: ["app.example.profile"]).canonicalScopeString()
                == permission.canonicalScopeString()
        )
    }

    @Test("repo: explicit actions are the same as the default")
    func repoExplicitActions() throws {
        let explicit = try RepoPermission.parse("repo:app.example.profile?action=create&action=update&action=delete")
        let implicit = try RepoPermission.parse("repo:app.example.profile")
        #expect(explicit.action == implicit.action)
        #expect(explicit.collection == implicit.collection)
        #expect(try explicit.canonicalScopeString() == implicit.canonicalScopeString())
        // The difference between "stated" and "defaulted" is kept.
        #expect(explicit.scopeParameters.wasStated("action"))
        #expect(!implicit.scopeParameters.wasStated("action"))
    }

    // DIFFERENCE 4: a parsed permission keeps its values as written (order,
    // duplicates, letter case). Only `canonicalScopeString()` sorts,
    // de-duplicates and lowercases.
    @Test("repo: multiple record types")
    func repoMultipleCollections() throws {
        let permission = try RepoPermission.parse("repo?collection=app.example.profile&collection=app.example.post")
        #expect(permission.collection == [.nsid("app.example.profile"), .nsid("app.example.post")])
        #expect(permission.action == RepoAction.allCases)
        #expect(
            try permission.canonicalScopeString()
                == "repo?collection=app.example.post&collection=app.example.profile"
        )
        #expect(
            try ATProtoScope.repo(collections: ["app.example.profile", "app.example.post"]).canonicalScopeString()
                == permission.canonicalScopeString()
        )
    }

    @Test("repo: wildcard, with and without an action")
    func repoWildcard() throws {
        let all = try RepoPermission.parse("repo:*")
        #expect(all.collection == [.any])
        #expect(all.action == [.create, .update, .delete])

        let deleteOnly = try RepoPermission.parse("repo:*?action=delete")
        #expect(deleteOnly.collection == [.any])
        #expect(deleteOnly.action == [.delete])
    }

    @Test("rpc: one method on any service")
    func rpcAnyAudience() throws {
        let permission = try RpcPermission.parse("rpc:app.example.moderation.createReport?aud=*")
        #expect(permission.lxm == [.nsid("app.example.moderation.createReport")])
        #expect(permission.aud == .any)
    }

    @Test("rpc: any method on a specific service")
    func rpcAnyMethod() throws {
        let permission = try RpcPermission.parse("rpc?lxm=*&aud=did:web:api.example.com%23svc_appview")
        #expect(permission.lxm == [.any])
        #expect(permission.aud == .service("did:web:api.example.com#svc_appview"))
    }

    @Test("blob: any type, and video or html")
    func blob() throws {
        #expect(try BlobPermission.parse("blob:*/*").accept == [.any])
        let videoOrHTML = try BlobPermission.parse("blob?accept=video/*&accept=text/html")
        // As written; see DIFFERENCE 4.
        #expect(videoOrHTML.accept == [.type("video"), .exact("text", "html")])
        #expect(videoOrHTML.matches(.init(mime: "video/mp4")))
        #expect(videoOrHTML.matches(.init(mime: "text/html")))
        #expect(!videoOrHTML.matches(.init(mime: "text/plain")))
    }

    @Test("account: read email, import repo")
    func account() throws {
        let email = try AccountPermission.parse("account:email")
        #expect(email.attr == .email)
        #expect(email.action == [.read])
        let repo = try AccountPermission.parse("account:repo?action=manage")
        #expect(repo.attr == .repo)
        #expect(repo.action == [.manage])
    }

    /// "the same permission could be represented as `account?action=manage&attr=repo`"
    @Test("account: positional and named forms are the same permission")
    func accountNamedForm() throws {
        let named = try AccountPermission.parse("account?action=manage&attr=repo")
        let positional = try AccountPermission.parse("account:repo?action=manage")
        #expect(named == positional)
        #expect(try named.canonicalScopeString() == "account:repo?action=manage")
    }

    @Test("identity: handle and wildcard")
    func identity() throws {
        #expect(try IdentityPermission.parse("identity:handle").attr == .handle)
        #expect(try IdentityPermission.parse("identity:*").attr == .any)
        #expect(try IdentityPermission.parse("identity:*?").attr == .any)
    }

    @Test("include: permission set reference with an audience")
    func include() throws {
        let scope = try IncludeScope.parse("include:app.example.authFull?aud=did:web:api.example.com%23svc_chat")
        #expect(scope.nsid == "app.example.authFull")
        #expect(scope.aud == .service("did:web:api.example.com#svc_chat"))
    }

    // MARK: Invalid by the rules of the specification

    static let invalidExamples: [(String, ScopeParseError)] = [
        // "If a parameter is specified in the positional position, it can not
        // also be described in the key/value parameters."
        ("repo:com.example.record?collection=com.example.other", .positionalAndNamedConflict(prefix: "repo", key: "collection")),
        // "Partial wildcards are not supported (eg, can not use com.example.*)."
        ("repo:com.example.*", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.*")),
        ("rpc:com.example.*?aud=*", .invalidPositionalValue(prefix: "rpc", key: "lxm", value: "com.example.*")),
        // "aud and lxm can not both be wildcard"
        ("rpc:*?aud=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        ("rpc?lxm=*&aud=*", .forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")),
        // aud: "Always required in granular string representation"
        ("rpc:app.example.moderation.createReport", .missingRequiredParameter(prefix: "rpc", key: "aud")),
        // aud: "DID followed by required service type fragment"
        ("rpc:app.example.moderation.createReport?aud=did:web:api.example.com", .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web:api.example.com")),
        // account attr: "Wildcard is not supported."
        ("account:*", .invalidPositionalValue(prefix: "account", key: "attr", value: "*")),
        // account action: "Currently supports read or manage."
        ("account:email?action=delete", .invalidParameterValue(prefix: "account", key: "action", value: "delete")),
        // repo action: "Allowed values are create, update, delete."
        ("repo:app.example.profile?action=read", .invalidParameterValue(prefix: "repo", key: "action", value: "read")),
        // collection / lxm / accept / attr are required.
        ("repo", .missingRequiredParameter(prefix: "repo", key: "collection")),
        ("rpc?aud=*", .missingRequiredParameter(prefix: "rpc", key: "lxm")),
        ("blob", .missingRequiredParameter(prefix: "blob", key: "accept")),
        ("account", .missingRequiredParameter(prefix: "account", key: "attr")),
        ("identity", .missingRequiredParameter(prefix: "identity", key: "attr")),
        ("include", .missingRequiredParameter(prefix: "include", key: "nsid")),
        // Matches the general syntax only.
        ("resource", .unknownPrefix("resource")),
        ("resource:positional?key=val", .unknownPrefix("resource:positional?key=val")),
        ("resource:positional&thing?key=val", .unknownPrefix("resource:positional&thing?key=val")),
        ("service:did:web:com.example#type?key=val", .unknownPrefix("service:did:web:com.example#type?key=val")),
        ("resource:", .unknownPrefix("resource:")),
        ("resource:?", .unknownPrefix("resource:?")),
        ("resource:&", .unknownPrefix("resource:&")),
        ("resource?", .unknownPrefix("resource?")),
        // Does not match the general syntax.
        ("resource:positional?key=qu\u{E9}bec", .unknownPrefix("resource:positional?key=qu\u{E9}bec")),
        ("emoji:\u{263A}\u{FE0F}", .unknownPrefix("emoji:\u{263A}\u{FE0F}")),
    ]

    @Test("invalid strings are rejected for the stated reason", arguments: invalidExamples)
    func invalidExample(example: String, error: ScopeParseError) {
        #expect(throws: error) { try ATProtoScope(example) }
    }

    @Test("invalid strings are kept verbatim by lenient parsing", arguments: invalidExamples)
    func invalidExampleIsPreserved(example: String, error: ScopeParseError) {
        let set = ATProtoScopeSet(scope: "atproto \(example)")
        #expect(set.scopes == [.atproto])
        #expect(set.rawScopes == ["atproto", example])
        #expect(set.unrecognized == [example])
        #expect(set.rejected == [example: error])
        #expect(set.scopeString == ["atproto", example].sorted().joined(separator: " "))
    }
}
