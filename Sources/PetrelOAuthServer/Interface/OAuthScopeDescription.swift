import Foundation

/// One line of the consent screen: what a group of requested scopes lets the
/// application do, in plain language.
public struct OAuthScopeSummary: Sendable, Equatable {
    /// What kind of access the line describes.
    public enum Kind: String, Sendable, Equatable {
        /// A named permission set (`include:`).
        case permissionSet
        /// Writing records to the account's repository (`repo:`).
        case repository
        /// Calling other services as the account (`rpc:`).
        case remoteProcedure
        /// Uploading media (`blob:`).
        case blob
        /// Account settings (`account:`).
        case account
        /// The account's network identity (`identity:`).
        case identity
        /// A broad pre-granular scope (`transition:`).
        case transition
        /// A scope this server recognises nothing about. It grants nothing.
        case unrecognized
    }

    /// The kind of access.
    public let kind: Kind
    /// A short heading.
    public let title: String
    /// One sentence per grant under the heading.
    public let details: [String]
    /// True when the line deserves emphasis: broad or account-critical access.
    public let isSensitive: Bool
    /// The scope strings this line describes, for an "advanced" disclosure.
    public let scopes: [String]

    /// Creates a summary line.
    public init(kind: Kind, title: String, details: [String], isSensitive: Bool = false, scopes: [String]) {
        self.kind = kind
        self.title = title
        self.details = details
        self.isSensitive = isSensitive
        self.scopes = scopes
    }
}

/// Turns requested scopes into consent-screen text.
///
/// The bare `atproto` scope produces no line: it is the session itself, shown
/// as "sign in" by the surrounding page. A permission set is described by its
/// own `title` / `detail` (localised when the set carries `title:lang`), and
/// the individual permissions it expands to are listed underneath so the user
/// can see what the bundle contains.
public enum OAuthScopeDescription {
    /// Describes a requested scope set.
    ///
    /// - Parameters:
    ///   - requestedScopes: the scopes as the client requested them.
    ///   - permissionSets: the resolved sets for the `include:` scopes, by NSID.
    ///   - languages: the user's preferred languages, most preferred first
    ///     (from `Accept-Language`).
    public static func summarize(
        requestedScopes: Set<String>,
        permissionSets: [String: LexiconPermissionSet] = [:],
        languages: [String] = []
    ) -> [OAuthScopeSummary] {
        var sets: [OAuthScopeSummary] = []
        var repo: [(String, String)] = []
        var rpc: [(String, String)] = []
        var blob: [(String, String)] = []
        var account: [(String, String, Bool)] = []
        var identity: [(String, String)] = []
        var transition: [(String, String)] = []
        var unrecognized: [String] = []

        for raw in requestedScopes.sorted() {
            guard let scope = try? ATProtoScope.parse(raw) else {
                unrecognized.append(raw)
                continue
            }
            switch scope {
            case .atproto:
                continue
            case .transitionGeneric:
                transition.append((raw, "Full access to your repository, media uploads and most services, as apps had before granular permissions"))
            case .transitionChatBsky:
                transition.append((raw, "Read and send your Bluesky direct messages"))
            case .transitionEmail:
                transition.append((raw, "Read your account email address"))
            case let .repo(permission):
                repo.append((raw, describe(permission)))
            case let .rpc(permission):
                rpc.append((raw, describe(permission)))
            case let .blob(permission):
                blob.append((raw, describe(permission)))
            case let .account(permission):
                account.append((raw, describe(permission), permission.action.contains(.manage)))
            case let .identity(permission):
                identity.append((raw, describe(permission)))
            case let .include(include):
                sets.append(describe(include, raw: raw, set: permissionSets[include.nsid], languages: languages))
            }
        }

        var lines = sets
        if !repo.isEmpty {
            lines.append(.init(
                kind: .repository, title: "Your repository",
                details: repo.map(\.1), isSensitive: repo.contains { $0.0.contains("*") },
                scopes: repo.map(\.0)
            ))
        }
        if !rpc.isEmpty {
            lines.append(.init(
                kind: .remoteProcedure, title: "Other services",
                details: rpc.map(\.1), isSensitive: rpc.contains { $0.0.contains("*") },
                scopes: rpc.map(\.0)
            ))
        }
        if !blob.isEmpty {
            lines.append(.init(kind: .blob, title: "Media uploads", details: blob.map(\.1), scopes: blob.map(\.0)))
        }
        if !account.isEmpty {
            lines.append(.init(
                kind: .account, title: "Your account",
                details: account.map(\.1), isSensitive: account.contains { $0.2 },
                scopes: account.map(\.0)
            ))
        }
        if !identity.isEmpty {
            lines.append(.init(
                kind: .identity, title: "Your identity",
                details: identity.map(\.1), isSensitive: true, scopes: identity.map(\.0)
            ))
        }
        if !transition.isEmpty {
            lines.append(.init(
                kind: .transition, title: "Broad access",
                details: transition.map(\.1), isSensitive: true, scopes: transition.map(\.0)
            ))
        }
        if !unrecognized.isEmpty {
            lines.append(.init(
                kind: .unrecognized, title: "Not recognised",
                details: ["This server does not recognise these scopes and grants nothing for them"],
                scopes: unrecognized
            ))
        }
        return lines
    }

    private static func describe(
        _ include: IncludeScope,
        raw: String,
        set: LexiconPermissionSet?,
        languages: [String]
    ) -> OAuthScopeSummary {
        guard let set else {
            return .init(
                kind: .permissionSet, title: include.nsid,
                details: ["A permission set this server could not describe"], scopes: [raw]
            )
        }
        var details: [String] = []
        if let detail = set.localizedDetail(for: languages) { details.append(detail) }
        let expanded = include.expand(set)
        if expanded.isEmpty {
            details.append("This permission set currently grants nothing")
        }
        for permission in expanded {
            switch permission {
            case let .repo(repo): details.append(describe(repo))
            case let .rpc(rpc): details.append(describe(rpc))
            }
        }
        return .init(
            kind: .permissionSet,
            title: set.localizedTitle(for: languages) ?? include.nsid,
            details: details,
            scopes: [raw]
        )
    }

    private static func describe(_ permission: RepoPermission) -> String {
        let verbs = prose(permission.action.map(\.rawValue))
        if permission.collection.contains(.any) {
            return "\(verbs.capitalizedFirst) any record in your repository"
        }
        return "\(verbs.capitalizedFirst) records of type \(prose(permission.collection.map(\.stringValue)))"
    }

    private static func describe(_ permission: RpcPermission) -> String {
        let methods = permission.lxm.contains(.any) ? "any method" : prose(permission.lxm.map(\.stringValue))
        let service = switch permission.aud {
        case .any: "any service"
        case let .service(did): did
        }
        return "Call \(methods) on \(service) as you"
    }

    private static func describe(_ permission: BlobPermission) -> String {
        if permission.accept.contains(.any) { return "Upload files of any type" }
        return "Upload files of type \(prose(permission.accept.map(\.stringValue)))"
    }

    private static func describe(_ permission: AccountPermission) -> String {
        let verb = permission.action.contains(.manage) ? "Read and change" : "Read"
        return switch permission.attr {
        case .email: "\(verb) your account email address"
        case .repo: "\(verb) your whole repository, including importing a replacement"
        case .status: "\(verb) your account status, including deactivating it"
        }
    }

    private static func describe(_ permission: IdentityPermission) -> String {
        switch permission.attr {
        case .handle: "Change your handle"
        case .any: "Change your handle and your identity's signing keys and hosting server"
        }
    }

    private static func prose(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
