@testable import Petrel
import XCTest

/// An authorization server writes the account's DID into a `space:` scope that was asked
/// for with its own-account authority. These pin exactly that allowance and nothing wider.
final class GatewayScopeGrantMatchingTests: XCTestCase {
    private let did = "did:plc:alice1234567890abcdefgh"
    private let otherDID = "did:plc:mallory234567890abcdefgh"
    private let mailbox =
        "space:blue.catbird.labyrinth.mailbox?action=create&action=delete&action=read&action=update"
            + "&collection=blue.catbird.labyrinth.device&collection=blue.catbird.labyrinth.epoch"

    private func covers(_ granted: Set<String>, _ required: String) -> Bool {
        GatewayScopeGrantMatching.grants(granted, cover: required, accountDID: did)
    }

    func testExactStringCovers() {
        XCTAssertTrue(covers(["atproto", mailbox], mailbox))
        XCTAssertTrue(covers(["atproto", "identity:handle"], "identity:handle"))
    }

    func testOwnAccountAuthorityResolvedToTheAccountDIDCovers() {
        XCTAssertTrue(covers(["atproto", mailbox + "&authority=\(did)"], mailbox))
        // Parameter order is the server's to choose.
        let reordered = "space:blue.catbird.labyrinth.mailbox?authority=\(did)"
            + "&collection=blue.catbird.labyrinth.epoch&collection=blue.catbird.labyrinth.device"
            + "&action=update&action=read&action=delete&action=create"
        XCTAssertTrue(covers([reordered], mailbox))
        // A percent-encoded DID is the same DID.
        let encoded = did.replacingOccurrences(of: ":", with: "%3A")
        XCTAssertTrue(covers([mailbox + "&authority=\(encoded)"], mailbox))
        // An explicit `self` in the request is the same request.
        XCTAssertTrue(covers([mailbox + "&authority=\(did)"], mailbox + "&authority=self"))
    }

    func testAnotherAccountOrAWildcardAuthorityDoesNotCover() {
        XCTAssertFalse(covers([mailbox + "&authority=\(otherDID)"], mailbox))
        XCTAssertFalse(covers([mailbox + "&authority=*"], mailbox))
    }

    func testAWildcardAuthorityRequestNeedsTheWildcardGrant() {
        let conversation = "space:blue.catbird.labyrinth.conversation?action=read&authority=*"
            + "&collection=blue.catbird.labyrinth.batch"
        XCTAssertTrue(covers([conversation], conversation))
        let narrowed = conversation.replacingOccurrences(of: "authority=*", with: "authority=\(did)")
        XCTAssertFalse(covers([narrowed], conversation))
    }

    func testANarrowerGrantDoesNotCover() {
        let noRead = mailbox.replacingOccurrences(of: "&action=read", with: "") + "&authority=\(did)"
        XCTAssertFalse(covers([noRead], mailbox))
        let oneCollection = mailbox.replacingOccurrences(of: "&collection=blue.catbird.labyrinth.epoch", with: "")
            + "&authority=\(did)"
        XCTAssertFalse(covers([oneCollection], mailbox))
        let otherType = mailbox.replacingOccurrences(of: "labyrinth.mailbox", with: "labyrinth.conversation")
            + "&authority=\(did)"
        XCTAssertFalse(covers([otherType], mailbox))
    }

    func testScopesOutsideTheSpaceFamilyCompareExactly() {
        XCTAssertFalse(covers(["repo:blue.catbird.chat.device"], "repo:blue.catbird.chat.device?action=create"))
        XCTAssertFalse(covers(["transition:generic"], "blob:*/*"))
    }

    func testMalformedSpaceScopesNeverMatchByCanonicalForm() {
        XCTAssertNil(GatewayScopeGrantMatching.canonicalSpaceScope("space:a.b.c?action", accountDID: did))
        XCTAssertNil(GatewayScopeGrantMatching.canonicalSpaceScope("space:a.b.c?authority=self&authority=*", accountDID: did))
        XCTAssertNil(GatewayScopeGrantMatching.canonicalSpaceScope("space:a.b.c?action=read", accountDID: ""))
        XCTAssertNil(GatewayScopeGrantMatching.canonicalSpaceScope("repo:a.b.c?action=create", accountDID: did))
    }

    func testCoverAllNeedsEveryScope() {
        let granted: Set<String> = ["atproto", "blob:*/*", mailbox + "&authority=\(did)"]
        XCTAssertTrue(GatewayScopeGrantMatching.grants(granted, coverAll: ["atproto", mailbox], accountDID: did))
        XCTAssertFalse(
            GatewayScopeGrantMatching.grants(granted, coverAll: ["atproto", mailbox, "identity:handle"], accountDID: did)
        )
    }
}
