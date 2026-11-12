import Foundation
import PetrelOAuthScopes
import Testing

@Suite("ScopePermissions")
struct ScopePermissionsSmokeTests {
    @Test("granular repo scope matches only its collection and actions")
    func repoScope() throws {
        let permissions = ScopePermissions(scope: "atproto repo:app.bsky.feed.post?action=create")
        #expect(permissions.hasBaseATProtocolScope)
        #expect(permissions.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
        #expect(!permissions.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
        #expect(!permissions.allowsRepo(.init(collection: "app.bsky.feed.like", action: .create)))
    }

    @Test("an unknown resource grants nothing and is recorded as rejected")
    func unknownResource() {
        let permissions = ScopePermissions(scope: "atproto space:com.example.thing")
        #expect(permissions.rejected.keys.contains("space:com.example.thing"))
        #expect(!permissions.allowsRepo(.init(collection: "com.example.thing", action: .create)))
    }
}
