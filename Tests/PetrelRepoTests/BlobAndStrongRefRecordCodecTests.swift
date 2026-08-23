import Foundation
import Petrel
import XCTest

@testable import PetrelRepo

/// Petrel's `toCBORValue()` returns `CIDAsLink` for every CID, never
/// `ATProtoLink`: `.link` for a `$link` (tag 42) and `.string` for a bare `cid`
/// field. While the converter recognised only `ATProtoLink`, every record
/// carrying a blob or a StrongRef fell through to `invalidRecordType` — which
/// on the wire was `putRecord` answering 400 for an avatar, an image post, a
/// like, a repost, a reply, or a quote.
final class BlobAndStrongRefRecordCodecTests: XCTestCase {
    private static let blobCID = "bafkreiexxtxgfx3tvpg4h5pjzlzvmc2rozjbt5wc6fjlzyqgz4fswzyliq"
    private static let recordCID = "bafyreiae5sz3cd4ohalt7yiwrdfke4wjof3rbnufaxo533zzxocygc3uwa"

    func testABlobRefSurvivesAsALinkWithItsTypedClaims() throws {
        let record = try publicRecord(
            #"""
            {"$type":"app.bsky.actor.profile","displayName":"Swan","avatar":{"$type":"blob",\#
            "ref":{"$link":"\#(Self.blobCID)"},"mimeType":"image/jpeg","size":17}}
            """#,
            collection: "app.bsky.actor.profile"
        )
        guard case let .object(avatar)? = record.fields["avatar"] else {
            return XCTFail("the blob object did not survive conversion")
        }
        XCTAssertEqual(avatar["ref"]?.linkCIDString, Self.blobCID)
        XCTAssertEqual(avatar["mimeType"], .string("image/jpeg"))
        XCTAssertEqual(avatar["size"], .integer(17))

        // Both projections the mutation layer checks reachability with.
        XCTAssertEqual(
            PublicRepositoryRecordCodec.publicBlobCIDs(in: record).map(\.string), [Self.blobCID])
        let typed = try PublicRepositoryRecordCodec.publicTypedBlobReferences(in: record)
        XCTAssertEqual(typed.count, 1)
        XCTAssertEqual(typed.first?.cid.string, Self.blobCID)
        XCTAssertEqual(typed.first?.mimeType, "image/jpeg")
        XCTAssertEqual(typed.first?.size, 17)
    }

    func testAStrongRefCIDStaysAStringAndCarriesNoBlobClaim() throws {
        let record = try publicRecord(
            #"""
            {"$type":"app.bsky.feed.like","createdAt":"2026-08-20T19:00:00.000Z",\#
            "subject":{"uri":"at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/abc",\#
            "cid":"\#(Self.recordCID)"}}
            """#,
            collection: "app.bsky.feed.like"
        )
        guard case let .object(subject)? = record.fields["subject"] else {
            return XCTFail("the StrongRef did not survive conversion")
        }
        // A StrongRef's `cid` is a plain string on the wire, not a link, and it
        // must not be mistaken for a blob reference.
        XCTAssertEqual(subject["cid"], .string(Self.recordCID))
        XCTAssertEqual(PublicRepositoryRecordCodec.publicBlobCIDs(in: record), [])
        XCTAssertEqual(try PublicRepositoryRecordCodec.publicTypedBlobReferences(in: record), [])
    }

    func testARecordWithNoLinksIsUnaffected() throws {
        let record = try publicRecord(
            #"{"$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-08-20T19:00:00.000Z"}"#,
            collection: "app.bsky.feed.post"
        )
        XCTAssertEqual(record.fields["text"], .string("hello"))
        XCTAssertEqual(PublicRepositoryRecordCodec.publicBlobCIDs(in: record), [])
    }

    private func publicRecord(_ json: String, collection: String) throws -> PublicRecord {
        let container = try JSONDecoder().decode(
            ATProtocolValueContainer.self, from: Data(json.utf8)
        )
        return try PublicRepositoryRecordCodec.publicRecord(from: container, collection: collection)
    }
}

extension PublicRecordValue {
    fileprivate var linkCIDString: String? {
        guard case let .link(cid) = self else { return nil }
        return cid.string
    }
}
