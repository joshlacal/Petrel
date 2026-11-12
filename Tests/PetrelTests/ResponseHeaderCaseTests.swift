import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// Response header names are case-insensitive (RFC 9110 §5.1). HTTP/2 sends
/// them in lower case, Darwin may canonicalise them, and
/// swift-corelibs-foundation passes them through as received, so every
/// lookup must ignore case.
@Suite("Response header names are matched without regard to case")
struct ResponseHeaderCaseTests {
    @Test(
        "atproto-content-labelers is read whatever its case",
        arguments: ["atproto-content-labelers", "Atproto-Content-Labelers", "ATPROTO-CONTENT-LABELERS"]
    )
    func contentLabelersHeader(name: String) async throws {
        let service = NetworkService(baseURL: URL(string: "https://pds.example")!)
        // Optional on Darwin, non-optional in swift-corelibs-foundation: the
        // annotation makes it optional on both so `#require` compiles cleanly.
        let built: HTTPURLResponse? = HTTPURLResponse(
            url: URL(string: "https://pds.example/xrpc/app.bsky.feed.getTimeline")!,
            statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: [name: "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:abcdefghijklmnopqrstuvwx"]
        )
        let response = try #require(built)
        let labelers = await service.extractContentLabelers(from: response)
        #expect(labelers.map(\.did) == ["did:plc:ar7c4by46qjdydhdevvrndac", "did:plc:abcdefghijklmnopqrstuvwx"])
        #expect(labelers.map(\.redact) == [true, false])
    }
}
