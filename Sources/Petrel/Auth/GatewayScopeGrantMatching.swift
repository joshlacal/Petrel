import Foundation

/// Decides whether the scopes a gateway reports cover the scopes an upgrade asked for.
///
/// Scopes compare as exact strings, with one allowance. An authorization server replaces a
/// `space:` scope's own-account authority (`self`, the default when no `authority` is given)
/// with the account's DID in the token it issues, so a request for
/// `space:<type>?action=read` is granted as `space:<type>?action=read&authority=<did>`.
/// That grant is the request, for this account, and is accepted as covering it. Every
/// other difference (a missing action or collection, another account's DID, a wildcard
/// authority the request did not name) is not a match.
enum GatewayScopeGrantMatching {
    /// Whether `granted` covers every scope in `required` for `accountDID`.
    static func grants(_ granted: Set<String>, coverAll required: Set<String>, accountDID: String) -> Bool {
        required.allSatisfy { grants(granted, cover: $0, accountDID: accountDID) }
    }

    /// Whether `granted` covers the single scope `required` for `accountDID`.
    static func grants(_ granted: Set<String>, cover required: String, accountDID: String) -> Bool {
        if granted.contains(required) {
            return true
        }
        guard let wanted = canonicalSpaceScope(required, accountDID: accountDID) else {
            return false
        }
        return granted.contains { canonicalSpaceScope($0, accountDID: accountDID) == wanted }
    }

    /// A `space:` scope as its type plus sorted parameters, with an absent or `self`
    /// authority written as `accountDID`. `nil` for any other scope, or one with a
    /// parameter that is not `name=value`.
    static func canonicalSpaceScope(_ scope: String, accountDID: String) -> String? {
        guard scope.hasPrefix("space:"), !accountDID.isEmpty else {
            return nil
        }
        let parts = scope.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let spaceType = String(parts[0])
        var parameters: [String] = []
        var hasAuthority = false
        if parts.count == 2 {
            for pair in parts[1].split(separator: "&", omittingEmptySubsequences: false) {
                let fields = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard fields.count == 2, !fields[0].isEmpty,
                      let value = String(fields[1]).removingPercentEncoding, !value.isEmpty
                else {
                    return nil
                }
                let name = String(fields[0])
                if name == "authority" {
                    guard !hasAuthority else { return nil }
                    hasAuthority = true
                    parameters.append("authority=\(value == "self" ? accountDID : value)")
                } else {
                    parameters.append("\(name)=\(value)")
                }
            }
        }
        if !hasAuthority {
            parameters.append("authority=\(accountDID)")
        }
        return spaceType + "?" + parameters.sorted().joined(separator: "&")
    }
}
