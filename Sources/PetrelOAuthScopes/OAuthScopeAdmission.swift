import Foundation

/// A bounded scope budget.
///
/// There are two, and they stay two even while the numbers coincide, because
/// they measure different strings, are enforced in different places, and blame
/// different parties:
///
/// | budget | measures | enforced at | at fault |
/// |---|---|---|---|
/// | ``rawInput`` | exactly the bytes the client sent | the wire tokenizer | the client |
/// | ``expandedGrant`` | the grant after `include:` expansion | token mint and persistence | the permission set's publisher |
///
/// An 80-byte `include:com.example.authBasic` passes the first comfortably and
/// can then inflate past the second. Upstream's `oauthScopeSchema` has no byte
/// or token cap at all, so these limits are this library's own and are sized to
/// be far above anything a real client sends.
public struct OAuthScopeBudget: Sendable, Equatable, Hashable {
    /// The longest single scope token, in UTF-8 bytes.
    public let bytesPerScope: Int
    /// The largest number of scope tokens.
    public let scopeCount: Int
    /// The longest space-joined scope value, in UTF-8 bytes.
    public let bytesPerSet: Int

    /// Creates a budget.
    public init(bytesPerScope: Int, scopeCount: Int, bytesPerSet: Int) {
        self.bytesPerScope = bytesPerScope
        self.scopeCount = scopeCount
        self.bytesPerSet = bytesPerSet
    }

    /// Measured against the client's own bytes, at the wire.
    public static let rawInput = OAuthScopeBudget(bytesPerScope: 1024, scopeCount: 64, bytesPerSet: 8192)

    /// Measured against the grant after permission-set expansion.
    public static let expandedGrant = OAuthScopeBudget(bytesPerScope: 1024, scopeCount: 256, bytesPerSet: 32768)
}

/// Failures of the scope admission pipeline, each mapped to the OAuth error
/// code the endpoint reports.
public enum OAuthScopeAdmissionError: Error, Sendable, Equatable, CustomStringConvertible {
    // Wire tokenizer — raw-input budget.

    /// The `scope` parameter was empty or only spaces.
    case emptyScopeRequest
    /// The same scope token appeared twice.
    case duplicateScope
    /// A token was not an RFC 6749 §3.3 `scope-token`.
    case notAScopeToken
    /// More tokens than the budget allows.
    case tooManyScopes(count: Int, limit: Int)
    /// One token exceeded the per-scope byte limit.
    case rawScopeTooLong(bytes: Int, limit: Int)
    /// The whole parameter exceeded the per-set byte limit.
    case rawRequestTooLong(bytes: Int, limit: Int)
    /// `openid` was requested. OpenID Connect is not part of the profile.
    case forbiddenScope

    // Grammar.

    /// A requested scope does not parse as any known permission.
    case unparseableScope(ScopeParseError)

    // requested ⊆ declared.

    /// A requested scope is not declared in the client's metadata.
    case notRegistered

    // Base-scope floor.

    /// The request does not include `atproto`.
    case missingBaseScope

    // Expanded-grant budget.

    /// One expanded scope exceeded the per-scope byte limit.
    case expandedScopeTooLong(bytes: Int, limit: Int)
    /// Expansion produced more scopes than the budget allows.
    case expandedGrantTooManyScopes(count: Int, limit: Int)
    /// The expanded grant exceeded the per-set byte limit.
    case expandedGrantTooLong(bytes: Int, limit: Int)

    /// The RFC 6749 error code for this failure.
    public var oauthErrorCode: String {
        switch self {
        case .emptyScopeRequest, .duplicateScope, .notAScopeToken,
             .tooManyScopes, .rawScopeTooLong, .rawRequestTooLong,
             .expandedScopeTooLong, .expandedGrantTooManyScopes, .expandedGrantTooLong:
            "invalid_request"
        case .forbiddenScope, .unparseableScope, .missingBaseScope, .notRegistered:
            "invalid_scope"
        }
    }

    public var description: String {
        switch self {
        case .emptyScopeRequest: "scope request is empty"
        case .duplicateScope: "scope request repeats a scope"
        case .notAScopeToken: "scope request contains a non RFC 6749 scope-token"
        case let .tooManyScopes(count, limit): "scope request has \(count) scopes, limit \(limit)"
        case let .rawScopeTooLong(bytes, limit): "requested scope is \(bytes) bytes, limit \(limit)"
        case let .rawRequestTooLong(bytes, limit): "scope request is \(bytes) bytes, limit \(limit)"
        case .forbiddenScope: "OpenID Connect scopes are not compatible with atproto"
        case let .unparseableScope(error): "requested scope did not parse: \(error)"
        case .notRegistered: "requested scope is not declared in the client metadata"
        case .missingBaseScope: "the \"atproto\" scope is required"
        case let .expandedScopeTooLong(bytes, limit): "expanded scope is \(bytes) bytes, limit \(limit)"
        case let .expandedGrantTooManyScopes(count, limit): "expanded grant has \(count) scopes, limit \(limit)"
        case let .expandedGrantTooLong(bytes, limit): "expanded grant is \(bytes) bytes, limit \(limit)"
        }
    }
}

/// Splits a wire `scope` value into its tokens under the raw-input budget.
public enum OAuthScopeTokenizer {
    /// Tokenizes a space-delimited `scope` value.
    ///
    /// Rejects an empty value, repeated tokens, anything that is not an RFC
    /// 6749 `scope-token`, and the literal `openid` (as the reference
    /// implementation does).
    public static func tokenize(
        _ raw: String,
        budget: OAuthScopeBudget = .rawInput
    ) throws(OAuthScopeAdmissionError) -> Set<String> {
        guard raw.utf8.count <= budget.bytesPerSet else {
            throw .rawRequestTooLong(bytes: raw.utf8.count, limit: budget.bytesPerSet)
        }
        let values = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !values.isEmpty else { throw .emptyScopeRequest }
        guard values.count <= budget.scopeCount else {
            throw .tooManyScopes(count: values.count, limit: budget.scopeCount)
        }
        guard values.count == Set(values).count else { throw .duplicateScope }
        for value in values {
            guard ScopeToken.isScopeToken(value) else { throw .notAScopeToken }
            guard value.utf8.count <= budget.bytesPerScope else {
                throw .rawScopeTooLong(bytes: value.utf8.count, limit: budget.bytesPerScope)
            }
            guard value != "openid" else { throw .forbiddenScope }
        }
        return Set(values)
    }
}

/// What to do with a requested scope that is a well-formed scope token but not
/// a permission this library understands (for example a resource type added to
/// the protocol later).
public enum OAuthUnknownScopePolicy: Sendable, Equatable {
    /// Fail the request with `invalid_scope`, so the developer sees the cause
    /// at the authorization request and not as an unexplained denial later.
    case reject
    /// Drop the scope from the grant, as the reference implementation does
    /// (`request-manager.ts`). The token response's `scope` then shows what was
    /// actually granted.
    case ignore
}

/// Decides which scopes an authorization request may ask for. Nothing here
/// matches a resource request; that is ``ScopePermissions``.
public enum OAuthScopeAdmissionPolicy {
    /// Admits a tokenized request.
    ///
    /// 1. Every requested scope must parse (or is dropped, per `unknownScopes`).
    /// 2. Every admitted scope must be declared in the client metadata,
    ///    comparing canonical forms on both sides.
    /// 3. The admitted set must contain `atproto`.
    ///
    /// - Returns: the admitted scope strings, exactly as the client wrote them.
    public static func admit(
        requested: Set<String>,
        declaredBy declared: Set<String>,
        unknownScopes: OAuthUnknownScopePolicy = .reject
    ) throws(OAuthScopeAdmissionError) -> Set<String> {
        var admitted: Set<String> = []
        for scope in requested {
            do {
                _ = try ATProtoScope.parse(scope)
                admitted.insert(scope)
            } catch {
                if unknownScopes == .reject { throw .unparseableScope(error) }
            }
        }
        guard isCanonicalSubset(admitted, of: declared) else { throw .notRegistered }
        guard admitted.contains("atproto") else { throw .missingBaseScope }
        return admitted
    }

    /// requested ⊆ declared, with both sides canonicalised.
    ///
    /// A client can legitimately spell the same grant differently in its
    /// metadata and its request (`repo:a.b.c?action=create` versus
    /// `repo?collection=a.b.c&action=create`). A declared value that does not
    /// parse is kept and compared as its raw bytes, never dropped: dropping it
    /// could lock a client out over a scope it is not currently asking for.
    public static func isCanonicalSubset(_ requested: Set<String>, of declared: Set<String>) -> Bool {
        let canonicalDeclared = Set(declared.map(canonicalisedOrRaw))
        return requested.allSatisfy { scope in
            declared.contains(scope) || canonicalDeclared.contains(canonicalisedOrRaw(scope))
        }
    }

    /// Enforces the expanded-grant budget on a grant about to be persisted.
    public static func enforceExpandedGrantBudget(
        _ scopes: Set<String>,
        budget: OAuthScopeBudget = .expandedGrant
    ) throws(OAuthScopeAdmissionError) {
        guard scopes.count <= budget.scopeCount else {
            throw .expandedGrantTooManyScopes(count: scopes.count, limit: budget.scopeCount)
        }
        var total = 0
        for scope in scopes {
            let bytes = scope.utf8.count
            guard bytes <= budget.bytesPerScope else {
                throw .expandedScopeTooLong(bytes: bytes, limit: budget.bytesPerScope)
            }
            total += bytes + (total == 0 ? 0 : 1)
        }
        guard total <= budget.bytesPerSet else {
            throw .expandedGrantTooLong(bytes: total, limit: budget.bytesPerSet)
        }
    }

    private static func canonicalisedOrRaw(_ scope: String) -> String {
        guard let parsed = try? ATProtoScope.parse(scope),
              let canonical = try? parsed.canonicalScopeString()
        else {
            return scope
        }
        return canonical
    }
}
