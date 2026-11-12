import Foundation
import Testing
@testable import PetrelOAuthScopes

/// Expansion of an `include:` scope against its permission set.
///
/// Permission sets are decoded from JSON literals rather than built in memory,
/// so each case also exercises the `Decodable` path that gives
/// `inheritAud: true` its boolean type and keeps a scalar distinct from a
/// one-element array.
///
/// The one-to-one port of `scopes/include-scope.test.ts` is in `Upstream/`;
/// line references below are to that file.
@Suite("include: expansion")
struct OAuthScopesIncludeExpansionTests {
    // MARK: - Helpers

    private func permissionSet(_ json: String) throws -> LexiconPermissionSet {
        try JSONDecoder().decode(LexiconPermissionSet.self, from: Data(json.utf8))
    }

    /// `compilePermissions`, scopes/include-scope.test.ts:165-168.
    private func compile(_ scope: String, _ json: String) throws -> [String] {
        try IncludeScope.parse(scope).expandToScopeStrings(permissionSet(json))
    }

    private let auth = "include:com.example.calendar.auth"

    // MARK: - isParentAuthorityOf (:117-158)

    @Test
    func isParentAuthorityOfAcceptsSameAndChildAuthorities() throws {
        let scope = try IncludeScope.parse("include:com.example.foo.auth")
        #expect(scope.isParentAuthorityOf("com.example.foo.identifier"))
        #expect(scope.isParentAuthorityOf("com.example.foo.bar.baz"))
        #expect(scope.isParentAuthorityOf("com.example.foo.bar.baz.quz"))
    }

    @Test
    func isParentAuthorityOfRejectsShortSiblingAndForeignNSIDs() throws {
        let scope = try IncludeScope.parse("include:com.example.foo.auth")
        // Shorter than the group prefix.
        #expect(!scope.isParentAuthorityOf("com"))
        #expect(!scope.isParentAuthorityOf("com.example"))
        // Siblings of the root domain.
        #expect(!scope.isParentAuthorityOf("com.example.bar"))
        #expect(!scope.isParentAuthorityOf("com.example.bar.foo"))
        #expect(!scope.isParentAuthorityOf("com.example.bar.qux"))
        // Other domains.
        #expect(!scope.isParentAuthorityOf("com.atproto.foo"))
        #expect(!scope.isParentAuthorityOf("com.atproto.foo.auth"))
        #expect(!scope.isParentAuthorityOf("com.atproto.foo.bar"))
    }

    @Test
    func isParentAuthorityOfAlwaysRejectsTheBareWildcard() throws {
        // A permission set may never grant "everything", whatever the
        // include's own NSID is (scopes/include-scope.ts:130-132).
        for nsid in ["include:com.example.foo.auth", "include:com.example.bar", "include:a.b.c.d.e"] {
            #expect(!(try IncludeScope.parse(nsid).isParentAuthorityOf("*")))
        }
    }

    @Test
    func isParentAuthorityOfIsByteSafeOnUnvalidatedInput() throws {
        // `other` reaches this function straight from a lexicon document, so it
        // is not necessarily ASCII, not necessarily an NSID, and may be empty.
        // The requirement is that no unit mismatch and no index arithmetic can
        // make any of these true or trap.
        let scope = try IncludeScope.parse("include:com.example.foo.auth")
        #expect(!scope.isParentAuthorityOf(""))
        #expect(!scope.isParentAuthorityOf("."))
        #expect(!scope.isParentAuthorityOf("com.example.foo."))
        #expect(!scope.isParentAuthorityOf("com.example.foo"))
        #expect(!scope.isParentAuthorityOf("\u{1F600}\u{1F600}\u{1F600}\u{1F600}\u{1F600}"))
        // One byte past the group prefix is the shortest accepted candidate.
        #expect(scope.isParentAuthorityOf("com.example.foo.a"))
        // Non-ASCII beyond the group prefix: 18 UTF-8 bytes, 17 UTF-16 units,
        // and the ASCII prefix matches either way, so byte units and upstream's
        // code-unit count agree.
        #expect(scope.isParentAuthorityOf("com.example.foo.\u{00E9}"))
        // The straddling case: 16 UTF-8 bytes, 15 UTF-16 units, 15 Characters.
        // The length guard rejects under bytes; the prefix check rejects under
        // every unit. Both answers are false, which is the invariant that
        // matters — the guard may never be the ONLY thing standing between an
        // arbitrary string and a grant.
        #expect(!scope.isParentAuthorityOf("com.example.fo\u{00E9}"))
    }

    // MARK: - Resources that cannot be part of a permission set

    @Test
    func blobEntriesAreDroppedWhetherValidOrNot() throws {
        // `:170-215` — both the well-formed and the malformed blob entry.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"blob","accept":["image/*"]}]}
        """) == [])
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"blob","accept":"image/*"}]}
        """) == [])
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"blob","accept":["image/*"],"extra":"property"}]}
        """) == [])
    }

    @Test
    func accountAndIdentityEntriesAreRejectedEvenWithValidSyntax() throws {
        // `:578-633`. The reference suite first shows that the syntax is valid
        // for those resources (`:586-594`, `:615-622`), so that the rejection
        // is not a false negative; the same control is below.
        let accountJSON = """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"account","attr":"email","action":["read"]}]}
        """
        let identityJSON = """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"identity","attr":"handle"}]}
        """
        #expect(try compile(auth, accountJSON) == [])
        #expect(try compile(auth, identityJSON) == [])

        // Positive control: the same entries do parse as their own resources
        // through the same adapter, so the `[]` above is about the resource
        // and not a broken adapter.
        let account = try permissionSet(accountJSON).permissions[0]
        let accountPermission = try AccountPermission(
            parameters: AccountPermission.schema.parse(LexPermissionSyntax(permission: account))
        )
        #expect(accountPermission.attr == .email)

        let identity = try permissionSet(identityJSON).permissions[0]
        let identityPermission = try IdentityPermission(
            parameters: IdentityPermission.schema.parse(LexPermissionSyntax(permission: identity))
        )
        #expect(identityPermission.attr == .handle)
    }

    @Test
    func unknownResourcesAreDropped() throws {
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"nonsense","collection":["com.example.calendar.event"]}]}
        """) == [])
        // `space` is not a resource the permission specification defines.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"space","spaceType":"com.example.calendar.group"}]}
        """) == [])
    }

    // MARK: - rpc (:218-443)

    @Test
    func rpcWildcardAudienceExpands() throws {
        // `:220-234` and its duplicate `:411-425`.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":"*",
           "lxm":["com.example.calendar.listEvents"]}]}
        """) == ["rpc:com.example.calendar.listEvents?aud=*"])
    }

    @Test
    func rpcInheritsTheIncludesAudience() throws {
        // `:236-262`. Inheriting requires all three of `inheritAud === true`,
        // no `aud` on the entry, and an `aud` on the include
        // (scopes/include-scope.ts:89-96); the tests below drop one each.
        #expect(try compile("\(auth)?aud=did:web:example.com#foo", """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","inheritAud":true,
           "lxm":["com.example.calendar.listEvents"]},
          {"type":"permission","resource":"rpc","inheritAud":true,
           "lxm":["com.example.calendar.getEventDetails"]}]}
        """) == [
            "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23foo",
            "rpc:com.example.calendar.getEventDetails?aud=did:web:example.com%23foo",
        ])
    }

    @Test
    func rpcDropsAnUnsplicedInheritAud() throws {
        // `:395-409` "un-specified inherited-aud" — no `?aud=` on the include,
        // so nothing is inherited and `inheritAud` remains, which is not a
        // parameter of `rpc`.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","inheritAud":true,
           "lxm":["com.example.calendar.listEvents"]}]}
        """) == [])
    }

    @Test
    func rpcDropsInheritAudSpelledAsAnythingButTheBooleanTrue() throws {
        // The comparison is `=== true` (scopes/include-scope.ts:90). `1` and
        // `"true"` are not the boolean, and must not be coerced into it.
        for spelling in ["1", "\"true\"", "false", "[true]"] {
            #expect(try compile("\(auth)?aud=did:web:example.com#foo", """
            {"type":"permission-set","permissions":[
              {"type":"permission","resource":"rpc","inheritAud":\(spelling),
               "lxm":["com.example.calendar.listEvents"]}]}
            """) == [], "inheritAud spelled \(spelling) must not splice")
        }
    }

    @Test
    func rpcRejectsAConcreteAudience() throws {
        // `:266-280`, and the same rule covers `:282-296` (invalid lxm syntax),
        // `:298-313` (extra properties), `:315-328` (missing lxm),
        // `:359-377` (both inheritAud and aud), `:379-393` (invalid authority).
        for entry in [
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"]}"#,
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":"com.example.calendar.listEvents"}"#,
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"],"extra":"property"}"#,
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo"}"#,
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}"#,
            #"{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.atproto.moderation.createReport"]}"#,
        ] {
            #expect(try compile("\(auth)?aud=did:web:example.com#bar", """
            {"type":"permission-set","permissions":[\(entry)]}
            """) == [], "entry \(entry)")
        }
    }

    @Test
    func rpcDropsEntriesMissingRequiredParameters() throws {
        // `:330-343` missing "aud"; `:345-357` missing "aud" and "lxm".
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","lxm":["com.example.calendar.listEvents"]}]}
        """) == [])
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[{"type":"permission","resource":"rpc"}]}
        """) == [])
    }

    @Test
    func rpcAuthorityGateAppliesToEveryLxm() throws {
        // `:427-441` "wildcard-aud for invalid authority" — the permission
        // parses, and is dropped for its namespace.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":"*",
           "lxm":["com.atproto.moderation.createReport"]}]}
        """) == [])
        // Every `lxm` is checked, so one foreign method drops the entry that
        // carries it even though the other is in the namespace.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":"*",
           "lxm":["com.example.calendar.listEvents","com.atproto.moderation.createReport"]}]}
        """) == [])
    }

    // MARK: - repo (:445-576)

    @Test
    func repoValidPermissionExpands() throws {
        // `:447-461`.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "action":["create","update","delete"]}]}
        """) == ["repo:com.example.calendar.event"])
    }

    @Test
    func repoPartialActionsCanonicalise() throws {
        // `:463-489` — pins declaration order, action re-ordering into
        // REPO_ACTIONS order, and the multi-collection non-positional form.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "action":["delete","update"]},
          {"type":"permission","resource":"repo",
           "collection":["com.example.calendar.event","com.example.calendar.rsvp"],
           "action":["delete","create"]}]}
        """) == [
            "repo:com.example.calendar.event?action=update&action=delete",
            "repo?collection=com.example.calendar.event&collection=com.example.calendar.rsvp&action=create&action=delete",
        ])
    }

    /// `:493-507`. A `collection` given as a scalar where an array is required
    /// makes the whole entry invalid. Reading the scalar as a one-element
    /// array would turn this `[]` into a `repo:` grant. Asserted end to end
    /// and at the adapter, so that a regression names the layer it broke in.
    @Test
    func repoScalarWhereAnArrayIsRequiredRejectsTheWholeEntry() throws {
        let json = """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":"com.example.calendar.event",
           "action":["create","update","delete"]}]}
        """
        #expect(try compile(auth, json) == [])

        let entry = try permissionSet(json).permissions[0]
        let syntax = LexPermissionSyntax(permission: entry)
        // The adapter must report "present but not an array", never "absent"
        // and never a one-element list.
        #expect(syntax.getMulti("collection") == .rejected)
        #expect(syntax.getMulti("collection") != .values(["com.example.calendar.event"]))
        // ... and the schema must turn that into a throw, not a default.
        #expect(throws: ScopeParseError.self) {
            try RepoPermission.schema.parse(syntax)
        }
        // The companion fixture at `:509-523`: `action: 'all'`. Not itself a
        // widening (`'all'` fails RepoAction's validate either way), but the
        // same mechanism.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "action":"all"}]}
        """) == [])
    }

    @Test
    func repoInvalidActionValuesRejectTheEntry() throws {
        // `:525-539`.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "action":["create","update","manage"]}]}
        """) == [])
    }

    @Test
    func repoInvalidAuthorityIsDropped() throws {
        // `:541-555`.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["app.bsky.feed.post"],
           "action":["create","update","delete"]}]}
        """) == [])
    }

    /// `:557-574`, 'permissions with one valid and one invalid authority': one
    /// entry whose `collection` holds one NSID inside the namespace and one
    /// outside it expands to `[]`, because `isAllowedPermission` requires every
    /// collection of the entry to qualify (scopes/include-scope.ts:117-119).
    ///
    /// The second case shows the complement: the check is per entry, not per
    /// set.
    @Test
    func repoAuthorityGateIsPerEntryAndUsesEveryWithinAnEntry() throws {
        // One entry, two collections, one foreign -> [].
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo",
           "collection":["com.example.calendar.event","app.bsky.feed.post"],
           "action":["create","update","delete"]}]}
        """) == [])

        // Two entries, one entirely inside the namespace and one entirely
        // outside it. A per-set check would give [] here.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "action":["create","update","delete"]},
          {"type":"permission","resource":"repo","collection":["app.bsky.feed.post"],
           "action":["create","update","delete"]}]}
        """) == ["repo:com.example.calendar.event"])

        // The same across resources and across a parse failure: a dropped
        // entry never takes the others with it.
        #expect(try compile("\(auth)?aud=did:web:example.com#foo", """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"blob","accept":["image/*"]},
          {"type":"permission","resource":"repo","collection":"com.example.calendar.event"},
          {"type":"permission","resource":"rpc","inheritAud":true,
           "lxm":["com.example.calendar.listEvents"]},
          {"type":"permission","resource":"repo","collection":["com.example.calendar.rsvp"],
           "action":["create"]}]}
        """) == [
            "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23foo",
            "repo:com.example.calendar.rsvp?action=create",
        ])
    }

    // MARK: - LexPermissionSyntax

    @Test
    func reservedKeysAreFilteredRatherThanRejectingTheEntry() throws {
        // Every entry carries `type` and `resource`. Neither is a parameter of
        // any resource, so `keys()` must not report them.
        let repo = LexPermissionSyntax(permission: LexiconPermission(
            type: "permission", resource: "repo",
            fields: ["collection": .list([.string("com.example.calendar.event")])]
        ))
        #expect(repo.keys() == ["collection"])
        #expect(repo.getSingle("resource") == .absent)
        #expect(repo.getSingle("type") == .absent)
        #expect(repo.prefix == "repo")
        #expect(repo.positional == nil)
    }

    @Test
    func anUnknownFieldDropsTheEntry() throws {
        // scopes/include-scope.test.ts:298-313, and the permission
        // specification: a declaration with an unexpected parameter name is
        // ignored, since the parameter might narrow the permission.
        let repo = LexPermissionSyntax(permission: LexiconPermission(
            resource: "repo",
            fields: ["collection": .list([.string("com.example.calendar.event")]),
                     "spaceType": .string("com.example.calendar.group")]
        ))
        #expect(repo.keys().sorted() == ["collection", "spaceType"])
        #expect(throws: ScopeParseError.unknownParameter(prefix: "repo", key: "spaceType")) {
            try RepoPermission.schema.parse(repo)
        }
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"],
           "spaceType":"com.example.calendar.group"}]}
        """) == [])
    }

    // MARK: - LexiconValue: string | number | boolean, or an array of those

    @Test
    func lexiconValueKeepsScalarsTyped() throws {
        let set = try permissionSet("""
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","inheritAud":true,"count":1,"ratio":1.5,
           "name":"x","list":["a","b"],"nested":[["a"]]}]}
        """)
        let fields = set.permissions[0].fields
        // A boolean must NOT arrive as the number 1, and a number must NOT
        // arrive as a boolean — `inheritAud === true` is an identity check.
        #expect(fields["inheritAud"] == .bool(true))
        #expect(fields["count"] == .number(1))
        #expect(fields["ratio"] == .number(1.5))
        #expect(fields["name"] == .string("x"))
        #expect(fields["list"] == .list([.string("a"), .string("b")]))
        #expect(fields["nested"] == .list([.list([.string("a")])]))
        // Arity is not erased by the stringifier either.
        #expect(LexiconValue.bool(true).scalarText == "true")
        #expect(LexiconValue.number(1).scalarText == "1")
        #expect(LexiconValue.number(1.5).scalarText == "1.5")
        #expect(LexiconValue.list([.string("a")]).scalarText == nil)
    }

    @Test
    func lexiconValueDoesNotTrapOnOutOfRangeNumbers() throws {
        // `String(Int(_:))` traps outside Int's range, and this value comes from
        // an attacker-reachable document. Rejection is fine; a crash is not.
        let set = try permissionSet("""
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":[1e300,-1e300]}]}
        """)
        let collection = set.permissions[0].fields["collection"]
        #expect(collection?.scalarText == nil)
        if case let .list(items)? = collection {
            for item in items { _ = item.scalarText }
        }
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":[1e300]}]}
        """) == [])
    }

    @Test
    func aNullFieldIgnoresThatEntryAndNeverWidensIt() throws {
        // As the reference implementation does (`lib/syntax-lexicon.ts:39-50`,
        // `lib/parser.ts:121-134`): `null` is not a parameter value, so the
        // entry carrying it is ignored and the other entries stand. In
        // particular a `null` where a list is required is never read as
        // "absent", which for an optional parameter would mean its default.
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":null},
          {"type":"permission","resource":"repo","collection":["com.example.calendar.post"],"action":null},
          {"type":"permission","resource":"repo","collection":["com.example.calendar.like"],"extra":{"nested":true}},
          {"type":"permission","resource":"repo","collection":["com.example.calendar.kept"]}]}
        """) == ["repo:com.example.calendar.kept"])
    }

    @Test
    func arrayWhereASingleValueIsRequiredRejectsTheWholeEntry() throws {
        // The mirror of the scalar-where-array case: `getSingle` returns `null`
        // for an array (lib/syntax-lexicon.ts:39-43). `aud` is single-valued,
        // so `["*"]` is rejected rather than read as `"*"`.
        let syntax = LexPermissionSyntax(permission: try permissionSet("""
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":["*"],
           "lxm":["com.example.calendar.listEvents"]}]}
        """).permissions[0])
        #expect(syntax.getSingle("aud") == .repeated([]))
        #expect(throws: ScopeParseError.self) {
            try RpcPermission.schema.parse(syntax)
        }
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":["*"],
           "lxm":["com.example.calendar.listEvents"]}]}
        """) == [])
    }

    // MARK: - Typed results

    @Test
    func expandReturnsTypedPermissionsNotOnlyStrings() throws {
        // `expand` returns typed permissions; the string form is derived from
        // them.
        let expanded = try IncludeScope.parse("\(auth)?aud=did:web:example.com#foo")
            .expand(permissionSet("""
            {"type":"permission-set","permissions":[
              {"type":"permission","resource":"repo","collection":["com.example.calendar.event"]},
              {"type":"permission","resource":"rpc","inheritAud":true,
               "lxm":["com.example.calendar.listEvents"]}]}
            """))
        #expect(expanded.count == 2)
        guard case let .repo(repo) = expanded[0] else {
            Issue.record("expected repo, got \(expanded[0])"); return
        }
        #expect(repo.collection == [.nsid("com.example.calendar.event")])
        #expect(repo.action == REPO_ACTIONS)
        guard case let .rpc(rpc) = expanded[1] else {
            Issue.record("expected rpc, got \(expanded[1])"); return
        }
        #expect(rpc.aud == .service("did:web:example.com#foo"))
        #expect(rpc.lxm == [.nsid("com.example.calendar.listEvents")])
        // A value the permission set left to the schema's default is marked
        // as such; one it named is not.
        #expect(!repo.scopeParameters.wasStated("action"))
        #expect(repo.scopeParameters.wasStated("collection"))
        #expect(rpc.scopeParameters.wasStated("aud"))
    }

    @Test
    func anEmptyPermissionSetExpandsToNothingWithoutFailing() throws {
        // A set whose every entry is dropped expands to nothing; that is not
        // an error.
        #expect(try compile(auth, #"{"type":"permission-set","permissions":[]}"#) == [])
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"blob","accept":["image/*"]}]}
        """) == [])
    }

    @Test
    func permissionSetDecodesItsDiscriminatorAndOptionalProse() throws {
        // `type` survives decoding, so that a resolver can tell a permission
        // set from another kind of definition.
        let set = try permissionSet("""
        {"type":"permission-set","title":"Calendar","detail":"Manage events",
         "title:lang":{"fr":"Agenda"},"detail:lang":{"fr":"Gerer"},
         "permissions":[{"type":"permission","resource":"blob","accept":["image/*"]}]}
        """)
        #expect(set.type == "permission-set")
        #expect(set.title == "Calendar")
        #expect(set.detail == "Manage events")
        #expect(set.permissions.count == 1)
        #expect(set.permissions[0].type == "permission")
        #expect(set.permissions[0].resource == "blob")
        #expect(set.permissions[0].fields.keys.sorted() == ["accept"])
    }

    /// `include:<nsid>?aud=*` does not parse. The `aud` of an include is
    /// validated with `isAtprotoDidRefAbsolute` alone
    /// (scopes/include-scope.ts:169-173), which has no wildcard.
    @Test
    func aWildcardIncludeAudienceIsRefusedAtParse() throws {
        #expect(throws: ScopeParseError.self) {
            try IncludeScope.parse("\(auth)?aud=*")
        }
        // Positive control: a concrete audience on the same include parses.
        let concrete = try IncludeScope.parse("\(auth)?aud=did:web:example.com%23svc")
        #expect(concrete.aud == .service("did:web:example.com#svc"))
    }

    /// An `aud` of `"*"` on an entry is a different rule and does expand
    /// (`:220-234`): the `aud` of `rpc` allows the wildcard
    /// (`isAudParam`, scopes/rpc-permission.ts:19-20) though that of an
    /// include does not.
    @Test
    func anEntryLevelWildcardAudienceStillExpands() throws {
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","aud":"*",
           "lxm":["com.example.calendar.listEvents"]}]}
        """) == ["rpc:com.example.calendar.listEvents?aud=*"])
    }

    /// `inheritAud` on an include without an `aud` drops the entry, as the
    /// permission specification requires (scopes/include-scope.ts:89-96).
    @Test
    func inheritAudWithoutAnIncludeAudienceDropsTheEntry() throws {
        #expect(try compile(auth, """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"rpc","inheritAud":true,
           "lxm":["com.example.calendar.listEvents"]}]}
        """) == [])
    }
}
