// Expansion of an `include:` scope into the permissions its permission set
// stands for. Pure: the permission set is given, already resolved and
// authenticated (`OAuthLexiconResolving`). No network, no I/O.
//
// Port of `scopes/include-scope.ts:36-159` in the reference implementation's
// `@atproto/oauth-scopes`.

// MARK: - IncludedPermission

/// A permission an `include:` scope expands to.
///
/// There is no case for another include: a permission set cannot reference a
/// permission set (`scopes/include-scope.ts:68-102` handles `repo` and `rpc`
/// and nothing else), so expansion is one level deep and cannot cycle.
public enum IncludedPermission: Sendable, Equatable {
    /// A `repo:` permission.
    case repo(RepoPermission)
    /// An `rpc:` permission.
    case rpc(RpcPermission)
}

extension IncludedPermission {
    /// Parses a permission-set entry as its resource's permission. `nil` on
    /// any failure: a malformed `collection`, `action` or `lxm` makes the
    /// entry ignored, not the set invalid (`scopes/include-scope.ts:59-60`).
    init?(_ syntax: LexPermissionSyntax) {
        do {
            switch syntax.prefix {
            case RepoPermission.prefix:
                self = .repo(try RepoPermission(parameters: RepoPermission.schema.parse(syntax)))
            case RpcPermission.prefix:
                self = .rpc(try RpcPermission(parameters: RpcPermission.schema.parse(syntax)))
            default:
                // `lexSyntax(for:)` produces only these two resources. The
                // value still derives from an untrusted document, so this is
                // a total switch rather than a trap.
                return nil
            }
        } catch {
            return nil
        }
    }

    /// The canonical scope string of this permission.
    public func canonicalScopeString() throws(ScopeParseError) -> String {
        switch self {
        case let .repo(permission): try permission.canonicalScopeString()
        case let .rpc(permission): try permission.canonicalScopeString()
        }
    }
}

// MARK: - Expansion

extension IncludeScope {
    /// The permissions this include stands for, given its permission set
    /// (`toPermissions`, `scopes/include-scope.ts:36-66`).
    ///
    /// An entry is kept only if it passes three checks; one that fails any of
    /// them is ignored and never invalidates the rest of the set, as the
    /// permission specification requires of "an unknown resource, or
    /// unexpected parameter names or values":
    ///
    ///  1. its resource is `repo` or `rpc`. `blob`, `account` and `identity`
    ///     permissions cannot be part of a permission set;
    ///  2. it parses as a permission of that resource;
    ///  3. every NSID it names is under this include's namespace authority
    ///     (``isParentAuthorityOf(_:)``).
    ///
    /// An empty result is not an error: an include whose every entry was
    /// ignored grants nothing.
    ///
    /// Call this only with a permission set whose proof of authenticity has
    /// been verified. A failed proof must end resolution before expansion,
    /// never be treated as an ignored entry: otherwise the host serving the
    /// document would decide which of the requested permissions survive.
    public func expand(_ set: LexiconPermissionSet) -> [IncludedPermission] {
        set.permissions.compactMap { entry in
            guard let syntax = lexSyntax(for: entry) else { return nil }
            guard let permission = IncludedPermission(syntax) else { return nil }
            guard isAllowed(permission) else { return nil }
            return permission
        }
    }

    /// ``expand(_:)`` as canonical scope strings
    /// (`toScopes`, `scopes/include-scope.ts:42-46`).
    public func expandToScopeStrings(
        _ set: LexiconPermissionSet
    ) throws(ScopeParseError) -> [String] {
        var strings: [String] = []
        strings.reserveCapacity(set.permissions.count)
        for permission in expand(set) {
            strings.append(try permission.canonicalScopeString())
        }
        return strings
    }

    /// The syntax adapter for one permission-set entry, or `nil` when the
    /// entry cannot be part of a permission set
    /// (`parseLexPermission`, `scopes/include-scope.ts:68-102`).
    ///
    /// For an `rpc` entry:
    ///
    ///  - an `aud` other than `*` is not allowed in a permission set, and the
    ///    entry is ignored (`:82-84`);
    ///  - when `inheritAud` is the boolean `true`, the entry names no `aud`,
    ///    and this include has one, the include's `aud` is used and
    ///    `inheritAud` is removed (`:89-96`).
    ///
    /// In every other case `inheritAud` stays in the entry, where it is not a
    /// parameter of `rpc`, so the entry is ignored. That covers the two cases
    /// the permission specification calls invalid: `inheritAud` together with
    /// `aud`, and `inheritAud` on an include that has no `aud`.
    func lexSyntax(for entry: LexiconPermission) -> LexPermissionSyntax? {
        switch entry.resource {
        case RepoPermission.prefix:
            return LexPermissionSyntax(permission: entry)

        case RpcPermission.prefix:
            let declaredAud = entry.fields["aud"]
            if let declaredAud, declaredAud != .string("*") { return nil }

            // `inheritAud === true` compares with the boolean; `1` and
            // `"true"` do not qualify.
            if entry.fields["inheritAud"] == .bool(true),
               declaredAud == nil,
               case let .service(inherited)? = aud {
                var fields = entry.fields
                fields.removeValue(forKey: "inheritAud")
                fields["aud"] = .string(inherited)
                return LexPermissionSyntax(
                    permission: LexiconPermission(
                        type: entry.type, resource: entry.resource, fields: fields
                    )
                )
            }

            return LexPermissionSyntax(permission: entry)

        default:
            return nil
        }
    }

    /// Whether every NSID `permission` names is under this include's
    /// namespace authority (`isAllowedPermission`,
    /// `scopes/include-scope.ts:110-122`): every `lxm` of an `rpc`
    /// permission, every `collection` of a `repo` permission.
    ///
    /// The check is per entry. One NSID outside the namespace makes the whole
    /// entry it appears in ignored; other entries are unaffected.
    func isAllowed(_ permission: IncludedPermission) -> Bool {
        switch permission {
        case let .rpc(rpc):
            return rpc.lxm.allSatisfy { isParentAuthorityOf($0.stringValue) }
        case let .repo(repo):
            return repo.collection.allSatisfy { isParentAuthorityOf($0.stringValue) }
        }
    }

    /// Whether `other` is in the same NSID group as this permission set, or in
    /// a child group, at any depth (`scopes/include-scope.ts:129-159`).
    ///
    /// The set `app.example.feed.authOnlyPost` may name
    /// `app.example.feed.post`, and `app.example.feed.deeper.record`, but not
    /// `app.example.actor.profile`. Concretely, `other` must begin with this
    /// include's NSID up to and including its last `.`, and continue past it.
    ///
    /// The wildcard `*` is never under any authority: a permission set cannot
    /// grant access to every collection or method.
    ///
    /// `other` is compared as UTF-8 bytes where the reference implementation
    /// compares UTF-16 code units. The answers are the same for every string:
    /// ``nsid`` is ASCII, so `other` shares the prefix only if it is ASCII up
    /// to that point, and what follows needs only to be non-empty.
    public func isParentAuthorityOf(_ other: String) -> Bool {
        guard other != "*" else { return false }

        let nsidBytes = Array(nsid.utf8)
        guard let groupPrefixEnd = nsidBytes.lastIndex(of: 0x2E) else {
            // The reference implementation throws here
            // (`scopes/include-scope.ts:138-142`). ``nsid`` is validated as an
            // NSID when the scope is parsed, so this is unreachable from a
            // parsed scope; `false` denies if it is ever reached.
            return false
        }

        let otherBytes = Array(other.utf8)
        // `other` must be longer than the group prefix. Signed arithmetic, so
        // an empty `other` gives `0 < -1`, which is false.
        guard groupPrefixEnd < otherBytes.count - 1 else { return false }
        return otherBytes.starts(with: nsidBytes[...groupPrefixEnd])
    }
}
