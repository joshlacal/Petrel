import Foundation
@testable import Petrel
import Testing

/// Cursor pagination over generated queries (lex-24) and parameter defaults (lex-21).
@Suite("XRPC pagination and parameter defaults")
struct XRPCPagesTests {
    private actor CallLog {
        private(set) var cursors: [String?] = []
        func record(_ cursor: String?) { cursors.append(cursor) }
    }

    private static func page(_ cursor: String?) -> AppBskyFeedGetTimeline.Output {
        AppBskyFeedGetTimeline.Output(cursor: cursor, feed: [])
    }

    @Test("Pages follow the cursor and stop after the page without one")
    func followsCursorToTheLastPage() async throws {
        let log = CallLog()
        let replies: [String?: String?] = [nil: "c1", "c1": "c2", "c2": nil]
        let pages = XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters(algorithm: "reverse-chronological", limit: 3)) { parameters in
            #expect(parameters.algorithm == "reverse-chronological")
            #expect(parameters.limit == 3)
            await log.record(parameters.cursor)
            return (200, Self.page(replies[parameters.cursor] ?? nil))
        }

        var cursors: [String?] = []
        for try await page in pages {
            cursors.append(page.cursor)
        }

        #expect(cursors == ["c1", "c2", nil])
        #expect(await log.cursors == [nil, "c1", "c2"])
    }

    @Test("An empty or repeated cursor ends iteration instead of looping")
    func emptyOrRepeatedCursorEnds() async throws {
        for (start, reply) in [("a", ""), ("a", "a")] {
            let log = CallLog()
            let pages = XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters(cursor: start)) { parameters in
                await log.record(parameters.cursor)
                return (200, Self.page(reply))
            }
            var count = 0
            for try await _ in pages {
                count += 1
            }
            #expect(count == 1)
            #expect(await log.cursors == [start])
        }
    }

    @Test("maxPages bounds the requests, and a body-less response ends iteration")
    func maxPagesAndEmptyBody() async throws {
        let log = CallLog()
        let bounded = XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters(), maxPages: 2) { parameters in
            await log.record(parameters.cursor)
            return (200, Self.page(UUID().uuidString))
        }
        var count = 0
        for try await _ in bounded {
            count += 1
        }
        #expect(count == 2)
        #expect(await log.cursors.count == 2)

        let empty = XRPCPages<AppBskyFeedGetTimeline.Parameters, AppBskyFeedGetTimeline.Output>(startingAt: .init()) { _ in (200, nil) }
        var iterator = empty.makeAsyncIterator()
        #expect(try await iterator.next() == nil)
    }

    @Test("An error from the call ends iteration by throwing")
    func errorsPropagate() async throws {
        struct Failure: Error {}
        let pages = XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters()) { parameters -> (responseCode: Int, data: AppBskyFeedGetTimeline.Output?) in
            if parameters.cursor == nil { return (200, Self.page("next")) }
            throw Failure()
        }
        var iterator = pages.makeAsyncIterator()
        #expect(try await iterator.next()?.cursor == "next")
        await #expect(throws: Failure.self) { _ = try await iterator.next() }
    }

    @Test("Generated paginated queries conform, and withCursor keeps every other parameter")
    func generatedConformance() throws {
        let parameters = ComAtprotoRepoListRecords.Parameters(
            repo: try ATIdentifier(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz"),
            collection: try NSID(nsidString: "app.bsky.feed.post"),
            limit: 10,
            cursor: "old",
            reverse: true
        )
        let next = parameters.withCursor("new")

        #expect(next.cursor == "new")
        #expect(next.repo == parameters.repo)
        #expect(next.collection == parameters.collection)
        #expect(next.limit == 10)
        #expect(next.reverse == true)
        #expect((ComAtprotoRepoListRecords.Output.self as Any.Type) is XRPCCursorPaginatedOutput.Type)
    }

    @Test("A parameter's Lexicon default is the initializer default, so it is sent")
    func defaultsAreSent() {
        let items = AppBskyFeedGetTimeline.Parameters().asQueryItems()

        #expect(items.map(\.name) == ["limit"])
        #expect(items.first?.value == "50")
        #expect(AppBskyFeedGetTimeline.Parameters(limit: nil).asQueryItems().isEmpty)
    }
}
