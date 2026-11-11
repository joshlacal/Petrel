import Foundation
@testable import PetrelOAuthScopes
import Testing

/// Every scope-string example in the permission specification
/// (atproto.com/specs/permission), with the meaning the specification states
/// for it.
@Suite("Scopes: every example in the permission specification")
struct PermissionSpecificationExamplesTests {
    static let validExamples = [
        "repo:app.example.profile",
        "repo:app.example.profile?action=create&action=update&action=delete",
        "repo?collection=app.example.profile&collection=app.example.post",
        "repo:*",
        "repo:*?action=delete",
        "rpc:app.example.moderation.createReport?aud=*",
        "rpc?lxm=*&aud=did:web:api.example.com%23svc_appview",
        "blob:*/*",
        "blob?accept=video/*&accept=text/html",
        "account:email",
        "account:repo?action=manage",
        "account?action=manage&attr=repo",
        "identity:handle",
        "identity:*",
        "identity:*?",
        "include:app.example.authFull?aud=did:web:api.example.com%23svc_chat",
        "include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview",
        "atproto",
        "transition:generic",
        "transition:chat.bsky",
        "transition:email",
    ]

    /// `ATProtoScope` equality is structural (it distinguishes a parameter that
    /// was written from one that was defaulted), so semantic equality is
    /// compared through the canonical string.
    @Test("every example parses, and canonicalisation is stable", arguments: validExamples)
    func parsesAndRoundTrips(example: String) throws {
        let canonical = try ATProtoScope.parse(example).canonicalScopeString()
        #expect(try ATProtoScope.parse(canonical).canonicalScopeString() == canonical)
        #expect(ScopeToken.isScopeToken(canonical))
    }

    @Test("a positional parameter may not also be given by name")
    func positionalAndNamedConflict() {
        #expect(throws: ScopeParseError.self) {
            _ = try ATProtoScope.parse("repo:com.example.record?collection=com.example.other")
        }
    }

    @Test("partial wildcards, a both-wildcard rpc and an rpc without an audience are refused", arguments: [
        "repo:com.example.*", "rpc:com.example.*?aud=*", "rpc:*?aud=*", "rpc:app.example.getThing",
        "rpc:app.example.getThing?aud=did:web:api.example.com", "account:password", "account:email?action=delete",
        "identity:email", "blob:image", "repo:app.example.profile?action=read", "include:not-an-nsid",
    ])
    func refused(example: String) {
        #expect(throws: ScopeParseError.self, "\(example)") { _ = try ATProtoScope.parse(example) }
    }

    @Test("the examples mean what the specification says they mean")
    func meanings() {
        func permissions(_ scope: String) -> ScopePermissions { ScopePermissions(scope: "atproto \(scope)") }

        // "full permission (create, update, delete) on a single record type"
        let single = permissions("repo:app.example.profile")
        for action in RepoAction.allCases {
            #expect(single.allowsRepo(.init(collection: "app.example.profile", action: action)))
        }
        #expect(!single.allowsRepo(.init(collection: "app.example.post", action: .create)))
        // "same as above, with actions being explicit"
        let explicit = try? ATProtoScope.parse("repo:app.example.profile?action=create&action=update&action=delete")
            .canonicalScopeString()
        #expect(explicit == "repo:app.example.profile")
        // "full permissions on multiple record types"
        let multiple = permissions("repo?collection=app.example.profile&collection=app.example.post")
        #expect(multiple.allowsRepo(.init(collection: "app.example.post", action: .delete)))
        // "delete only permission on all record types"
        let deleteOnly = permissions("repo:*?action=delete")
        #expect(deleteOnly.allowsRepo(.init(collection: "any.record.type", action: .delete)))
        #expect(!deleteOnly.allowsRepo(.init(collection: "any.record.type", action: .create)))

        // "Submit moderation reports to any service"
        let report = permissions("rpc:app.example.moderation.createReport?aud=*")
        #expect(report.allowsRPC(.init(lxm: "app.example.moderation.createReport", aud: "did:web:any.example#svc")))
        #expect(!report.allowsRPC(.init(lxm: "app.example.other", aud: "did:web:any.example#svc")))
        // "Call any RPC method on a specific service"
        let service = permissions("rpc?lxm=*&aud=did:web:api.example.com%23svc_appview")
        #expect(service.allowsRPC(.init(lxm: "app.example.anything", aud: "did:web:api.example.com#svc_appview")))
        #expect(!service.allowsRPC(.init(lxm: "app.example.anything", aud: "did:web:other.example.com#svc_appview")))

        // "Upload any type of blob" / "Upload video or html"
        #expect(permissions("blob:*/*").allowsBlob(.init(mime: "application/pdf")))
        let media = permissions("blob?accept=video/*&accept=text/html")
        #expect(media.allowsBlob(.init(mime: "video/mp4")))
        #expect(media.allowsBlob(.init(mime: "text/html")))
        #expect(!media.allowsBlob(.init(mime: "text/plain")))
        #expect(!media.allowsBlob(.init(mime: "image/png")))

        // "read account email" / "Import repo"
        let email = permissions("account:email")
        #expect(email.allowsAccount(.init(attr: .email, action: .read)))
        #expect(!email.allowsAccount(.init(attr: .email, action: .manage)))
        #expect(permissions("account:repo?action=manage").allowsAccount(.init(attr: .repo, action: .manage)))

        // "Update account handle"
        #expect(permissions("identity:handle").allowsIdentity(.init(attr: .handle)))
        #expect(!permissions("identity:handle").allowsIdentity(.init(attr: .any)))
        #expect(permissions("identity:*").allowsIdentity(.init(attr: .handle)))

        // An include: matches nothing until it is expanded.
        let include = permissions("include:app.example.authFull?aud=did:web:api.example.com%23svc_chat")
        #expect(!include.allowsRepo(.init(collection: "app.example.post", action: .create)))
    }
}
