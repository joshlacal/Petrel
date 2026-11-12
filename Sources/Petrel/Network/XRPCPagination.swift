import Foundation

/// The parameters of a query that pages with a `cursor`.
///
/// Generated `Parameters` conform when the query takes an optional string `cursor` and
/// its output returns one (`app.bsky.feed.getTimeline`, `com.atproto.repo.listRecords`,
/// and so on).
public protocol XRPCCursorPaginatedParameters: Parametrizable {
    /// The cursor these parameters request the page after, or `nil` for the first page.
    var cursor: String? { get }

    /// The same parameters, requesting the page after `cursor`.
    func withCursor(_ cursor: String?) -> Self
}

/// The output of a query that pages with a `cursor`.
public protocol XRPCCursorPaginatedOutput: Sendable {
    /// The cursor of the next page, or `nil` (or empty) when this is the last page.
    var cursor: String? { get }
}

/// The pages of a cursor-paginated query, fetched one at a time as they are iterated.
///
/// ```swift
/// let pages = XRPCPages(startingAt: AppBskyFeedGetTimeline.Parameters(limit: 50)) {
///     try await client.app.bsky.feed.getTimeline(input: $0)
/// }
/// for try await page in pages {
///     for item in page.feed { ... }
/// }
/// ```
///
/// Iteration ends after the page whose cursor is `nil` or empty, after a 2xx response with
/// no body, after `maxPages` pages, or when the server repeats a cursor it already
/// returned (which would otherwise loop forever). An error from `fetch` (a generated call
/// throws `ATProtoXRPCError` for a non-2xx response) ends iteration by throwing. Nothing is
/// requested until the first call to `next()`, and cancelling the iterating task stops it
/// before the next request.
public struct XRPCPages<Parameters: XRPCCursorPaginatedParameters, Output: XRPCCursorPaginatedOutput>: AsyncSequence, Sendable {
    public typealias Element = Output
    public typealias Fetch = @Sendable (Parameters) async throws -> (responseCode: Int, data: Output?)

    private let first: Parameters
    private let maxPages: Int?
    private let fetch: Fetch

    /// - Parameters:
    ///   - first: The parameters of the first page. Their `cursor`, if any, is where
    ///     paging starts.
    ///   - maxPages: The most pages to fetch, or `nil` for no limit.
    ///   - fetch: Sends the query for one page; usually the generated call.
    public init(startingAt first: Parameters, maxPages: Int? = nil, fetch: @escaping Fetch) {
        precondition(maxPages.map { $0 >= 0 } ?? true, "maxPages must not be negative")
        self.first = first
        self.maxPages = maxPages
        self.fetch = fetch
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(next: first, maxPages: maxPages, fetch: fetch)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var next: Parameters?
        private var remaining: Int?
        private var seenCursors: Set<String> = []
        private let fetch: Fetch

        init(next: Parameters, maxPages: Int?, fetch: @escaping Fetch) {
            self.next = next
            remaining = maxPages
            self.fetch = fetch
            if let cursor = next.cursor { seenCursors.insert(cursor) }
        }

        public mutating func next() async throws -> Output? {
            guard let parameters = next else { return nil }
            if let remaining, remaining <= 0 {
                next = nil
                return nil
            }
            try Task.checkCancellation()
            next = nil
            remaining = remaining.map { $0 - 1 }

            guard let page = try await fetch(parameters).data else { return nil }
            if let cursor = page.cursor, !cursor.isEmpty, seenCursors.insert(cursor).inserted {
                next = parameters.withCursor(cursor)
            }
            return page
        }
    }
}
