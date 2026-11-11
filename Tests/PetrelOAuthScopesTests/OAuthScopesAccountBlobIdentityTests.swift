import Foundation
import Testing
@testable import PetrelOAuthScopes

/// `account:`, `blob:` and `identity:` through the typed API: parsed values,
/// matching and canonical form. The one-to-one ports of
/// `scopes/account-permission.test.ts`, `scopes/blob-permission.test.ts`,
/// `lib/mime.test.ts` and `scopes/identity-permission.test.ts` are in
/// `Upstream/`.
@Suite("account: / blob: / identity: families")
struct OAuthScopesAccountBlobIdentityTests {
    // MARK: account

    @Test
    func accountParsesAttrAndDefaultsAction() throws {
        let a = try AccountPermission.parse("account:email?action=read")
        #expect(a.attr == .email && a.action == [.read])
        let b = try AccountPermission.parse("account:repo?action=manage")
        #expect(b.attr == .repo && b.action == [.manage])
        let c = try AccountPermission.parse("account:status")
        #expect(c.action == [.read]) // default
    }

    @Test
    func accountRejectsInvalidAttrOrAction() {
        for scope in ["account:invalid", "account:email?action=invalid", "invalid:email", "account", "", "account:"] {
            #expect(throws: ScopeParseError.self) { try AccountPermission.parse(scope) }
        }
    }

    @Test
    func accountManageSubsumesReadButNotReverse() throws {
        let manage = try AccountPermission.parse("account:email?action=manage")
        #expect(manage.matches(.init(attr: .email, action: .read)))
        let read = try AccountPermission.parse("account:email?action=read")
        #expect(!read.matches(.init(attr: .email, action: .manage)))
        let bare = try AccountPermission.parse("account:email")
        #expect(!bare.matches(.init(attr: .email, action: .manage)))
    }

    @Test
    func accountFormatElidesDefaultAction() throws {
        #expect(try AccountPermission(attr: .email, action: [.manage]).canonicalScopeString() == "account:email?action=manage")
        #expect(try AccountPermission(attr: .repo, action: [.read]).canonicalScopeString() == "account:repo")
    }

    @Test
    func accountRoundTripsEveryCombination() throws {
        for scope in ["account:email", "account:email?action=manage", "account:repo",
                      "account:repo?action=manage", "account:status", "account:status?action=manage"] {
            let parsed = try AccountPermission.parse(scope)
            #expect(try parsed.canonicalScopeString() == scope)
        }
    }

    @Test
    func accountScopeNeeded() throws {
        #expect(try AccountPermission.scopeNeeded(for: .init(attr: .email, action: .read)) == "account:email")
        #expect(try AccountPermission.scopeNeeded(for: .init(attr: .email, action: .manage)) == "account:email?action=manage")
    }

    @Test
    func accountActionHasNoNormalizerAndPreservesInsertionOrder() throws {
        // `action` of `account` is the one multi-valued parameter with no
        // normalizer (scopes/account-permission.ts:49-54), so the canonical
        // form keeps the order written. Sorting would give
        // "action=read&action=manage".
        let parsed = try AccountPermission.parse("account:email?action=manage&action=read")
        #expect(try parsed.canonicalScopeString() == "account:email?action=manage&action=read")
    }

    // MARK: blob

    @Test
    func blobParsesPositionalAndNamedAccept() throws {
        let a = try BlobPermission.parse("blob:image/png")
        #expect(a.accept == [.exact("image", "png")])
        let b = try BlobPermission.parse("blob?accept=image/png&accept=image/jpeg")
        #expect(b.accept == [.exact("image", "png"), .exact("image", "jpeg")])
    }

    @Test
    func blobRequiresAcceptAndRejectsMalformedMime() {
        for scope in ["blob", "blob:invalid", "blob?accept=invalid-mime", "blob?accept=invalid",
                      "blob:*/**", "blob:*/png", "invalid", "scope"] {
            #expect(throws: ScopeParseError.self) { try BlobPermission.parse(scope) }
        }
    }

    @Test
    func blobMatchingGatesOnConcreteRequestMimeFirst() throws {
        let anyAny = try BlobPermission.parse("blob:*/*")
        #expect(anyAny.matches(.init(mime: "image/jpeg")))
        #expect(anyAny.matches(.init(mime: "application/json")))
        // lib/mime.test.ts:72-73: a malformed requested media type matches
        // nothing, not even */*.
        #expect(!anyAny.matches(.init(mime: "image/")))
        #expect(!anyAny.matches(.init(mime: "/mime")))

        let typeWildcard = try BlobPermission.parse("blob:image/*")
        #expect(typeWildcard.matches(.init(mime: "image/gif")))

        let exact = try BlobPermission.parse("blob:image/png")
        #expect(!exact.matches(.init(mime: "image/jpeg")))
    }

    @Test
    func blobEmptyAcceptSetMatchesNothing() {
        // lib/mime.test.ts:89-91 — matchesAnyAccept([], "image/png") is false.
        // The parser never produces an empty list (`accept` is required), so
        // the value is constructed directly.
        let empty = BlobPermission(accept: [])
        #expect(!empty.matches(.init(mime: "image/png")))
    }

    @Test
    func blobNormalizeAcceptCollapsesWildcardsAndSortsAndStripsRedundant() throws {
        #expect(try BlobPermission(accept: [.any, .type("image")]).canonicalScopeString() == "blob:*/*")
        #expect(try BlobPermission(accept: [.any, .exact("image", "png")]).canonicalScopeString() == "blob:*/*")
        #expect(try BlobPermission(accept: [.type("image"), .exact("image", "png")]).canonicalScopeString() == "blob:image/*")
        #expect(try BlobPermission(accept: [.exact("image", "png"), .exact("image", "jpeg")]).canonicalScopeString()
            == "blob?accept=image/jpeg&accept=image/png")
    }

    @Test
    func blobSingleValueSerialisesPositionally() throws {
        #expect(try BlobPermission(accept: [.exact("image", "png")]).canonicalScopeString() == "blob:image/png")
        #expect(try BlobPermission(accept: [.type("image")]).canonicalScopeString() == "blob:image/*")
        #expect(try BlobPermission(accept: [.any]).canonicalScopeString() == "blob:*/*")
    }

    @Test
    func blobScopeNeeded() throws {
        #expect(try BlobPermission.scopeNeeded(for: .init(mime: "image/png")) == "blob:image/png")
    }

    // MARK: identity

    @Test
    func identityParsesHandleAndWildcard() throws {
        #expect(try IdentityPermission.parse("identity:handle").attr == .handle)
        #expect(try IdentityPermission.parse("identity:*").attr == .any)
    }

    @Test
    func identityRejectsInvalidAndActionKey() {
        // scopes/identity-permission.test.ts:23-35 — `action` is not a
        // parameter of `identity`.
        for scope in ["identity:invalid", "invalid", "identity:*?action=*", "identity:*?action=manage",
                      "identity:*?action=submit", "identity:handle?action=invalid",
                      "identity?attribute=invalid&action=invalid"] {
            #expect(throws: ScopeParseError.self) { try IdentityPermission.parse(scope) }
        }
    }

    @Test
    func identityWildcardGrantIsAsymmetric() throws {
        let handle = try IdentityPermission.parse("identity:handle")
        #expect(handle.matches(.init(attr: .handle)))
        #expect(!handle.matches(.init(attr: .any))) // handle grant does NOT satisfy a `*` request

        let any = try IdentityPermission.parse("identity:*")
        #expect(any.matches(.init(attr: .any)))
        #expect(any.matches(.init(attr: .handle)))
    }

    @Test
    func identityFormatAndScopeNeeded() throws {
        #expect(try IdentityPermission(.handle).canonicalScopeString() == "identity:handle")
        #expect(try IdentityPermission(.any).canonicalScopeString() == "identity:*")
        #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .handle)) == "identity:handle")
        #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .any)) == "identity:*")
    }
}
