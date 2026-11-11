import Foundation

/// A frozen, request-scoped answer to "may this token do X".
///
/// Constructed once per authenticated request from the token's granted scope
/// strings and never mutated. Parsing is eager: a scope string that does not
/// parse is recorded in ``rejected`` and grants nothing (as in
/// `scopes-set.test.ts:41-46`) rather than failing to parse again on every
/// match. The raw strings are retained verbatim so persistence and audit
/// surfaces never see a re-serialized value.
///
/// This is the counterpart of `ScopePermissionsTransition` in the reference
/// implementation's `@atproto/oauth-scopes`
/// (`scope-permissions-transition.ts:13-71`), which the reference PDS
/// constructs for every OAuth credential (`packages/pds/src/auth-verifier.ts:395`).
/// Its base class, `ATProtoScopeSet`, which ignores the `transition:` scopes,
/// has no separate counterpart here: match a parsed ``RepoPermission``,
/// ``RpcPermission``, ``BlobPermission``, ``AccountPermission`` or
/// ``IdentityPermission`` directly to evaluate a granular scope on its own.
public struct ATProtoScopeSet: Sendable, Equatable, Hashable {
    /// Exactly the strings the token carries, unmodified.
    public let rawScopes: Set<String>

    /// Scope strings that did not parse, with the reason. Retained for logging
    /// only and never consulted by a match.
    public let rejected: [String: ScopeParseError]

    let grants: [ATProtoScope]

    /// Parses `rawScopes` once.
    ///
    /// - Parameter rawScopes: the token's effective scope strings, verbatim.
    public init(rawScopes: Set<String>) {
        self.rawScopes = rawScopes
        // Sort so `grants` is a deterministic function of the input.
        var grants: [ATProtoScope] = []
        var rejected: [String: ScopeParseError] = [:]
        for value in rawScopes.sorted() {
            do {
                grants.append(try ATProtoScope.parse(value))
            } catch {
                rejected[value] = error
            }
        }
        self.grants = grants
        self.rejected = rejected
    }

    /// Creates a set from grants that are already typed, without parsing
    /// anything: `rawScopes` are the strings the grants serialise to.
    init(rawScopes: Set<String>, grants: [ATProtoScope], rejected: [String: ScopeParseError]) {
        self.rawScopes = rawScopes
        self.grants = grants
        self.rejected = rejected
    }

    /// Parses an OAuth `scope` value — scope tokens separated by SPACE — as
    /// it appears in a token response or an access-token claim.
    public init(scope: String) {
        self.init(rawScopes: Set(scope.split(separator: " ").map(String.init)))
    }

    /// Two values are equal when they hold the same scope strings; what they
    /// grant is a pure function of those.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawScopes == rhs.rawScopes
    }

    /// Hashes the scope strings.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawScopes)
    }

    /// The base AT Protocol session scope. Nothing is granted without it.
    public var hasBaseATProtocolScope: Bool { rawScopes.containsBytes(of: "atproto") }

    // MARK: - Transition scopes
    //
    // `scope-permissions-transition.ts:14-24`. All three are parameterless
    // exact strings.

    /// `transition:generic` — the broad pre-granular-permissions scope.
    public var hasTransitionGeneric: Bool { rawScopes.containsBytes(of: "transition:generic") }

    /// `transition:email` — grants exactly `account:email?action=read`.
    public var hasTransitionEmail: Bool { rawScopes.containsBytes(of: "transition:email") }

    /// `transition:chat.bsky` — grants exactly the `chat.bsky.*` RPC arm.
    public var hasTransitionChatBsky: Bool { rawScopes.containsBytes(of: "transition:chat.bsky") }
}

// MARK: - repo, rpc, blob, account, identity

public extension ATProtoScopeSet {
    /// Whether the token may write `target` to the repository.
    ///
    /// `transition:generic` allows any action on any collection
    /// (`scope-permissions-transition.ts:46-52`).
    func allowsRepo(_ target: RepoPermission.Target) -> Bool {
        if hasTransitionGeneric { return true }
        return grants.contains { grant in
            guard case let .repo(permission) = grant else { return false }
            return permission.matches(target)
        }
    }

    /// Throws ``ScopeDenied`` unless ``allowsRepo(_:)``.
    func requireRepo(_ target: RepoPermission.Target) throws {
        guard allowsRepo(target) else {
            throw ScopeDenied(
                needed: (try? RepoPermission.scopeNeeded(for: target)) ?? "repo:<unrenderable target>"
            )
        }
    }

    /// Whether the token may call the method `target.lxm` on the service
    /// `target.aud`.
    ///
    /// The transition scopes apply first, in the reference implementation's
    /// order (`scope-permissions-transition.ts:54-70`): `transition:generic`
    /// for the wildcard `lxm`; `transition:generic` for any `lxm` outside
    /// `chat.bsky.`; and `transition:chat.bsky` for any `lxm` inside it. That
    /// split is why direct messages are the one thing `transition:generic`
    /// alone cannot reach.
    ///
    /// None of the three consults `aud`, so a transition scope is not
    /// restricted to an audience. A resource server that needs such a
    /// restriction applies it separately.
    func allowsRPC(_ target: RpcPermission.Target) -> Bool {
        // Byte comparisons, as everywhere a request is matched: a text prefix
        // test would not see `chat.bsky.` in a name whose next character is a
        // combining mark, and transition:generic would then allow it.
        if hasTransitionGeneric, target.lxm.isByteEqual(to: "*") { return true }
        if hasTransitionGeneric, !target.lxm.hasBytePrefix("chat.bsky.") { return true }
        if hasTransitionChatBsky, target.lxm.hasBytePrefix("chat.bsky.") { return true }
        return grants.contains { grant in
            guard case let .rpc(permission) = grant else { return false }
            return permission.matches(target)
        }
    }

    /// Throws ``ScopeDenied`` unless ``allowsRPC(_:)``.
    func requireRPC(_ target: RpcPermission.Target) throws {
        guard allowsRPC(target) else {
            throw ScopeDenied(
                needed: (try? RpcPermission.scopeNeeded(for: target)) ?? "rpc:<unrenderable target>"
            )
        }
    }

    /// Whether the token may upload a blob of the media type `target.mime`.
    ///
    /// `transition:generic` allows any media type
    /// (`scope-permissions-transition.ts:38-44`), including a string that is
    /// not a well-formed `type/subtype` and that no `blob:` permission would
    /// match.
    func allowsBlob(_ target: BlobPermission.Target) -> Bool {
        if hasTransitionGeneric { return true }
        return grants.contains { grant in
            guard case let .blob(permission) = grant else { return false }
            return permission.matches(target)
        }
    }

    /// Throws ``ScopeDenied`` unless ``allowsBlob(_:)``.
    func requireBlob(_ target: BlobPermission.Target) throws {
        guard allowsBlob(target) else {
            throw ScopeDenied(
                needed: (try? BlobPermission.scopeNeeded(for: target)) ?? "blob:<unrenderable target>"
            )
        }
    }

    /// Whether the token may perform `target.action` on the account attribute
    /// `target.attr`.
    ///
    /// `transition:email` grants exactly `email` with `read`
    /// (`scope-permissions-transition.ts:26-36`). It does not imply `manage`,
    /// and it says nothing about `repo` or `status`.
    func allowsAccount(_ target: AccountPermission.Target) -> Bool {
        if target.attr == .email, target.action == .read, hasTransitionEmail { return true }
        return grants.contains { grant in
            guard case let .account(permission) = grant else { return false }
            return permission.matches(target)
        }
    }

    /// Throws ``ScopeDenied`` unless ``allowsAccount(_:)``.
    func requireAccount(_ target: AccountPermission.Target) throws {
        guard allowsAccount(target) else {
            throw ScopeDenied(
                needed: (try? AccountPermission.scopeNeeded(for: target)) ?? "account:<unrenderable target>"
            )
        }
    }

    /// Whether the token may change the identity attribute `target.attr`. No
    /// transition scope grants this.
    func allowsIdentity(_ target: IdentityPermission.Target) -> Bool {
        grants.contains { grant in
            guard case let .identity(permission) = grant else { return false }
            return permission.matches(target)
        }
    }

    /// Throws ``ScopeDenied`` unless ``allowsIdentity(_:)``.
    func requireIdentity(_ target: IdentityPermission.Target) throws {
        guard allowsIdentity(target) else {
            throw ScopeDenied(
                needed: (try? IdentityPermission.scopeNeeded(for: target)) ?? "identity:<unrenderable target>"
            )
        }
    }
}

/// A scope check that failed, carrying the minimal scope string that would
/// have satisfied it.
///
/// The counterpart of the reference implementation's `ScopeMissingError`
/// (`scope-missing-error.ts:1-15`), which reports the needed scope to the
/// client with status 403. Whether to expose ``needed`` on the wire or only
/// log it is the resource server's decision.
public struct ScopeDenied: Error, Sendable, Equatable {
    /// The narrowest scope string that would have allowed the request.
    public let needed: String

    /// Creates a denial naming the scope that was missing.
    public init(needed: String) {
        self.needed = needed
    }
}

/// The name this type had before it was shared with the OAuth client. Both
/// names refer to the same type.
public typealias ScopePermissions = ATProtoScopeSet
