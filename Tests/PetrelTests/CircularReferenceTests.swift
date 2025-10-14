@testable import Petrel
import XCTest

final class CircularReferenceTests: XCTestCase {
    func testKnownFollowersDecodingDoesNotStackOverflow() throws {
        // This JSON has the circular structure:
        // ProfileViewBasic -> ViewerState -> KnownFollowers -> [ProfileViewBasic]
        let json = """
        {
            "$type": "app.bsky.actor.defs#knownFollowers",
            "count": 1,
            "followers": [
                {
                    "$type": "app.bsky.actor.defs#profileViewBasic",
                    "did": "did:plc:test123",
                    "handle": "test.bsky.social",
                    "viewer": {
                        "$type": "app.bsky.actor.defs#viewerState",
                        "knownFollowers": {
                            "$type": "app.bsky.actor.defs#knownFollowers",
                            "count": 0,
                            "followers": []
                        }
                    }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        // This should not cause a stack overflow
        let result = try decoder.decode(AppBskyActorDefs.KnownFollowers.self, from: data)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.followers.count, 1)
        XCTAssertEqual(result.followers[0].did.value, "did:plc:test123")
        XCTAssertEqual(result.followers[0].handle.value, "test.bsky.social")

        // Verify nested knownFollowers
        XCTAssertNotNil(result.followers[0].viewer)
        XCTAssertNotNil(result.followers[0].viewer?.knownFollowers)
        XCTAssertEqual(result.followers[0].viewer?.knownFollowers?.count, 0)
    }

    func testKnownFollowersEncodingWorks() throws {
        let knownFollowers = AppBskyActorDefs.KnownFollowers(
            count: 1,
            followers: [
                AppBskyActorDefs.ProfileViewBasic(
                    did: DID(value: "did:plc:test123"),
                    handle: Handle(value: "test.bsky.social"),
                    displayName: nil,
                    avatar: nil,
                    associated: nil,
                    viewer: nil,
                    labels: nil,
                    createdAt: nil,
                    verification: nil,
                    status: nil
                ),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        // This should not cause a stack overflow
        let data = try encoder.encode(knownFollowers)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"count\" : 1"))
        XCTAssertTrue(jsonString.contains("did:plc:test123"))
    }
}
