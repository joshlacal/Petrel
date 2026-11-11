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
        let values = raw.scopeTokens
        guard !values.isEmpty else { throw .emptyScopeRequest }
        guard values.count <= budget.scopeCount else {
            throw .tooManyScopes(count: values.count, limit: budget.scopeCount)
        }
        // A duplicate is the same token twice: identical bytes. Two spellings of
        // one permission are not duplicates here; whether they are the same
        // grant is a question for admission, which compares meanings. Bytes
        // rather than `String` equality, which would call two canonically
        // equivalent strings one.
        guard values.count == Set(values.map(\.scopeBytes)).count else { throw .duplicateScope }
        for value in values {
            guard ScopeToken.isScopeToken(value) else { throw .notAScopeToken }
            guard value.utf8.count <= budget.bytesPerScope else {
                throw .rawScopeTooLong(bytes: value.utf8.count, limit: budget.bytesPerScope)
            }
            guard !value.isByteEqual(to: "openid") else { throw .forbiddenScope }
        }
        // Every value is now known to be an ASCII scope-token, and no two
        // distinct ASCII strings are equal as `String`s, so the set holds
        // exactly the tokens that were sent.
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
    /// 2. Every admitted scope must be declared in the client metadata: some
    ///    declared scope must grant exactly what it grants (``isDeclared(_:by:)``).
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
        guard isDeclared(admitted, by: declared) else { throw .notRegistered }
        guard admitted.containsBytes(of: "atproto") else { throw .missingBaseScope }
        return admitted
    }

    /// Whether every scope of `requested` is declared: for each, some scope of
    /// `declared` grants exactly the same thing.
    ///
    /// A client can legitimately spell one grant differently in its metadata
    /// and in its request (`repo:a.b.c?action=create` versus
    /// `repo?collection=a.b.c&action=create`), so the comparison is not on the
    /// strings as written. Nor is it on canonical strings, which are not a
    /// faithful key for a grant: `rpc:m?aud=did:web:example.com%23svc%26admin`
    /// (audience `…#svc&admin`) and `…%23svc%2526admin` (audience
    /// `…#svc%26admin`) are different services with one canonical string, and
    /// comparing those would admit a scope the client never declared. Both
    /// sides are parsed and compared by what they grant, as the matchers see
    /// it: `isDeclared` holding implies that everything a requested scope
    /// allows, the declared scopes allow.
    ///
    /// A scope that does not parse grants nothing that can be compared. A
    /// requested one is declared only if `declared` holds the identical bytes;
    /// a declared one never vouches for anything but those bytes. It is kept,
    /// not dropped, so a client is not locked out over a declared scope it is
    /// not currently asking for.
    public static func isDeclared(_ requested: Set<String>, by declared: Set<String>) -> Bool {
        let declaredMeanings = Set(declared.compactMap { (try? ATProtoScope.parse($0))?.meaning })
        return requested.allSatisfy { scope in
            if let parsed = try? ATProtoScope.parse(scope) {
                return declaredMeanings.contains(parsed.meaning)
            }
            return declared.containsBytes(of: scope)
        }
    }

    /// Enforces the expanded-grant budget on a grant about to be persisted.
    ///
    /// This measures storage — how many strings and how many bytes — so it
    /// counts the strings as they are, not the distinct grants among them.
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
}
