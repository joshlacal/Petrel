import Foundation

// Turning `include:<nsid>` scopes into the concrete `repo:` / `rpc:` grants
// they stand for, at the two points the protocol does it: when an
// authorization request is pushed (so an unresolvable set fails the request
// before the user is asked anything) and when a token is minted or refreshed
// (so a session picks up changes to a published set).
//
// Upstream: `oauth-provider/src/lexicon/lexicon-manager.ts`.

/// Where in the flow a permission set is being resolved. The same root cause
/// is reported with a different OAuth error code at each, as upstream does.
public enum OAuthScopeResolutionStage: Sendable, Equatable {
    /// The pushed authorization request: reported as `invalid_scope`.
    case pushedAuthorizationRequest
    /// Code exchange or refresh: reported as `invalid_request`.
    case tokenMint

    /// The OAuth error code for a failure at this stage.
    public var oauthErrorCode: String {
        switch self {
        case .pushedAuthorizationRequest: "invalid_scope"
        case .tokenMint: "invalid_request"
        }
    }
}


/// Why an `include:` scope could not be turned into permissions.
public enum OAuthScopeResolutionFailure: Error, Sendable, Equatable, CustomStringConvertible {
    /// The permission set could not be resolved (or no resolver is configured).
    case includeUnresolvable(nsid: String)
    /// The NSID resolved to a lexicon whose `main` is not a permission set.
    case includeNotAPermissionSet(nsid: String)
    /// Too many distinct sets, or the group deadline expired.
    case budget(OAuthLexiconResolutionBudgetError)
    /// The expanded grant exceeded the expanded-grant budget.
    case expandedGrantOverBudget(OAuthScopeAdmissionError)
    /// An expanded permission has no canonical scope-string form.
    case unserialisableExpansion(nsid: String)

    public var description: String {
        switch self {
        case let .includeUnresolvable(nsid): "permission set \(nsid) could not be resolved"
        case let .includeNotAPermissionSet(nsid): "lexicon \(nsid) is not a permission set"
        case let .budget(error): "lexicon resolution budget exceeded: \(error)"
        case let .expandedGrantOverBudget(error): "expanded grant is over budget: \(error)"
        case let .unserialisableExpansion(nsid): "expansion of \(nsid) did not serialise"
        }
    }
}

/// A permission-set resolution failure together with the stage it happened at.
public struct OAuthScopeResolutionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Where the failure happened.
    public let stage: OAuthScopeResolutionStage
    /// What failed.
    public let failure: OAuthScopeResolutionFailure

    /// Creates an error.

    public init(stage: OAuthScopeResolutionStage, failure: OAuthScopeResolutionFailure) {
        self.stage = stage
        self.failure = failure
    }

    /// The OAuth error code to report.
    public var oauthErrorCode: String { stage.oauthErrorCode }
    public var description: String { failure.description }
}


/// The result of expanding every `include:` in a scope set.
public struct OAuthExpandedScopeSet: Sendable, Equatable {
    /// The effective grant: every non-`include:` scope unchanged, and each
    /// `include:` replaced by the permissions its set expands to.
    public let scopes: Set<String>

    /// NSIDs of permission sets that resolved but contributed no permission
    /// (every entry was dropped by the family parse or the namespace-authority
    /// gate). Not an error; surfaced so the consent screen and logs can say so.
    public let emptyExpansions: [String]

    /// The resolved permission sets by NSID, for rendering `title` / `detail`
    /// on the consent screen.
    public let permissionSets: [String: LexiconPermissionSet]

    /// Creates an expansion result.
    public init(
        scopes: Set<String>,
        emptyExpansions: [String] = [],
        permissionSets: [String: LexiconPermissionSet] = [:]
    ) {
        self.scopes = scopes
        self.emptyExpansions = emptyExpansions
        self.permissionSets = permissionSets
    }
}

/// `include:` expansion against a ``OAuthLexiconResolving``.
public enum OAuthLexiconScopeResolution {
    /// Expands every `include:<nsid>` scope in `scopes`.
    ///
    /// - A set that cannot be resolved, or resolves to a lexicon that is not a
    ///   permission set, fails the whole request: silently dropping it would
    ///   let whoever controls resolution choose which of a user's permissions
    ///   survive.
    /// - Entries inside a resolved set that name an unknown resource, carry
    ///   unexpected parameters, or reach outside the set's namespace are
    ///   ignored individually, as the specification requires.
    /// - With no resolver configured, a request that contains an `include:`
    ///   scope fails; one that contains none passes through untouched.
    ///
    /// - Throws: ``OAuthScopeResolutionError`` for the cases above; any other
    ///   error from the resolver (cancellation, storage) propagates unchanged.
    public static func expandIncludes(
        _ scopes: Set<String>,
        resolver: (any OAuthLexiconResolving)?,
        stage: OAuthScopeResolutionStage,
        budget: OAuthScopeBudget = .expandedGrant
    ) async throws -> OAuthExpandedScopeSet {
        var includes: [(raw: String, scope: IncludeScope)] = []
        for raw in scopes.sorted() {
            guard case let .include(include)? = try? ATProtoScope.parse(raw) else { continue }
            includes.append((raw, include))
        }
        guard !includes.isEmpty else {
            return OAuthExpandedScopeSet(scopes: scopes)
        }
        guard let resolver else {
            throw OAuthScopeResolutionError(
                stage: stage, failure: .includeUnresolvable(nsid: includes[0].scope.nsid)
            )
        }

        let resolutions: [String: OAuthLexiconResolution]
        do {
            resolutions = try await resolver.resolveAll(
                includes.map(\.scope.nsid), population: .includes
            )
        } catch let error as OAuthLexiconResolutionBudgetError {
            throw OAuthScopeResolutionError(stage: stage, failure: .budget(error))
        }

        var effective = scopes
        var empty: [String] = []
        var sets: [String: LexiconPermissionSet] = [:]
        for (raw, include) in includes {
            let nsid = include.nsid
            switch resolutions[nsid] ?? .unresolvable {
            case .unresolvable:
                throw OAuthScopeResolutionError(
                    stage: stage, failure: .includeUnresolvable(nsid: nsid)
                )
            case let .resolved(document, _, _):
                guard case let .permissionSet(set) = document else {
                    throw OAuthScopeResolutionError(
                        stage: stage, failure: .includeNotAPermissionSet(nsid: nsid)
                    )
                }
                sets[nsid] = set
                effective.remove(raw)
                let permissions = include.expand(set)
                if permissions.isEmpty { empty.append(nsid) }
                for permission in permissions {
                    // A string that parses back to this permission, not its canonical
                    // form: see IncludedPermission.scopeString().
                    guard let string = try? permission.scopeString() else {
                        throw OAuthScopeResolutionError(
                            stage: stage, failure: .unserialisableExpansion(nsid: nsid)
                        )
                    }
                    effective.insert(string)
                }
            }
        }
        do {
            try OAuthScopeAdmissionPolicy.enforceExpandedGrantBudget(effective, budget: budget)
        } catch {
            throw OAuthScopeResolutionError(stage: stage, failure: .expandedGrantOverBudget(error))
        }
        return OAuthExpandedScopeSet(
            scopes: effective, emptyExpansions: empty.sorted(), permissionSets: sets
        )
    }
}
