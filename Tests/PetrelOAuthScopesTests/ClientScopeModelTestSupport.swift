import Foundation
import PetrelOAuthScopes
import Testing

/// Shared helpers for the client scope model suites.
///
/// These suites are a second, independently written set of expectations over
/// `PetrelOAuthScopes`: the permission specification's examples, the reference
/// implementation's test vectors, and the questions an OAuth client asks of a
/// scope (is it valid, what is its canonical form, does a grant cover it).
/// Where this module answers differently from a literal reading of the
/// specification, the test pins this module's answer and says so in a
/// `DIFFERENCE` comment.
enum ClientScopeModelTestSupport {
    /// Decodes a `permission-set` definition whose `permissions` array is the
    /// given JSON text.
    static func permissionSet(permissions json: String) throws -> LexiconPermissionSet {
        try decodePermissionSet("{\"type\":\"permission-set\",\"permissions\":\(json)}")
    }

    /// Decodes JSON text as a `permission-set` definition.
    static func decodePermissionSet(_ json: String) throws -> LexiconPermissionSet {
        try JSONDecoder().decode(LexiconPermissionSet.self, from: Data(json.utf8))
    }

    /// A Lexicon document whose main definition is a permission set.
    struct LexiconDocument: Decodable {
        struct Definitions: Decodable {
            let main: LexiconPermissionSet
        }

        let id: String
        let defs: Definitions
    }

    /// Decodes JSON text as a whole Lexicon document.
    static func decodeLexiconDocument(_ json: String) throws -> LexiconDocument {
        try JSONDecoder().decode(LexiconDocument.self, from: Data(json.utf8))
    }

    /// The canonical form of a scope string.
    static func canonical(_ scope: String) throws -> String {
        try ATProtoScope(scope).canonicalScopeString()
    }

    /// The resource a parsed scope belongs to.
    static func resource(of scope: ATProtoScope) -> String {
        switch scope {
        case .atproto: "atproto"
        case .transitionEmail, .transitionGeneric, .transitionChatBsky: "transition"
        case .account: "account"
        case .blob: "blob"
        case .identity: "identity"
        case .include: "include"
        case .repo: "repo"
        case .rpc: "rpc"
        }
    }

    /// A `repo` permission built from validated values.
    static func repo(_ collections: [String], _ actions: [RepoAction] = RepoAction.allCases) throws -> RepoPermission {
        guard case let .repo(permission) = try ATProtoScope.repo(collections: collections, actions: actions) else {
            throw Unexpected.notTheBuiltResource
        }
        return permission
    }

    /// An `rpc` permission built from validated values.
    static func rpc(_ lxm: [String], aud: String) throws -> RpcPermission {
        guard case let .rpc(permission) = try ATProtoScope.rpc(lxm: lxm, aud: aud) else {
            throw Unexpected.notTheBuiltResource
        }
        return permission
    }

    /// A `blob` permission built from validated values.
    static func blob(_ accept: [String]) throws -> BlobPermission {
        guard case let .blob(permission) = try ATProtoScope.blob(accept: accept) else {
            throw Unexpected.notTheBuiltResource
        }
        return permission
    }

    /// A builder returned a scope of another resource than the one it builds.
    enum Unexpected: Error {
        case notTheBuiltResource
    }

    /// Every scope string used as a valid vector somewhere in these suites,
    /// paired with its canonical form. Feeds the round-trip tests.
    static let validScopes: [(String, String)] = {
        let groups: [[(String, String)]] = [
            staticScopes,
            ClientScopeModelSpecExampleTests.validExamples,
            ClientScopeModelRepoTests.consistency,
            ClientScopeModelRPCTests.consistency,
            ClientScopeModelBlobTests.consistency,
            ClientScopeModelAccountTests.consistency,
            ClientScopeModelIdentityTests.consistency,
            ClientScopeModelIncludeTests.consistency,
        ]
        return groups.flatMap { $0 }
    }()

    static let staticScopes: [(String, String)] = [
        ("atproto", "atproto"),
        ("transition:generic", "transition:generic"),
        ("transition:chat.bsky", "transition:chat.bsky"),
        ("transition:email", "transition:email"),
    ]
}
