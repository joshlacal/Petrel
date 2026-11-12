import Foundation

/// Post text together with its facets (mentions, links and tags).
///
/// Facet positions are UTF-8 byte offsets into the text, as the
/// `app.bsky.richtext.facet` lexicon requires. `RichText` keeps those offsets
/// correct while the text is edited, detects facets in plain text, and splits
/// the text into segments for rendering.
///
/// ```swift
/// var richText = RichText(text: "Hello @alice.bsky.social, see https://atproto.com #atproto")
/// await richText.detectFacets { handle in
///     try await client.bsky.resolveHandle(handle)
/// }
/// for segment in richText.segments() {
///     // segment.text, segment.link, segment.mention, segment.tag
/// }
/// ```
///
/// Offsets coming from the network are untrusted. Out-of-range, negative,
/// overlapping or mid-character offsets never trap: slices are clamped to the
/// text and decoded leniently, like the reference implementation's
/// `TextDecoder`.
public struct RichText: Sendable, Hashable {
    /// The maximum length of a post in grapheme clusters (`app.bsky.feed.post`).
    public static let maxPostGraphemes = 300
    /// The maximum length of a post in UTF-8 bytes (`app.bsky.feed.post`).
    public static let maxPostUTF8Bytes = 3000

    /// The plain text.
    public private(set) var text: String

    /// The facets, sorted by start offset. Facets whose end precedes their
    /// start are dropped on creation; zero-length facets are kept.
    public private(set) var facets: [AppBskyRichtextFacet]

    /// Creates rich text from text and existing facets.
    ///
    /// - Parameters:
    ///   - text: The plain text.
    ///   - facets: Facets positioned by UTF-8 byte offsets.
    ///   - entities: Deprecated `app.bsky.feed.post#entity` annotations, used
    ///     only when there are no facets. Their UTF-16 offsets are converted.
    ///   - cleanNewlines: Collapse runs of three or more line breaks into two.
    public init(
        text: String,
        facets: [AppBskyRichtextFacet]? = nil,
        entities: [AppBskyFeedPost.Entity]? = nil,
        cleanNewlines: Bool = false
    ) {
        self.text = text
        var resolved = facets ?? []
        if resolved.isEmpty, let entities, !entities.isEmpty {
            resolved = Self.facets(from: entities, in: text)
        }
        self.facets = Self.sorted(resolved.filter { $0.index.byteStart <= $0.index.byteEnd })
        if cleanNewlines {
            self = sanitized(cleanNewlines: true)
        }
    }

    /// Creates rich text from a post record.
    public init(post: AppBskyFeedPost) {
        self.init(text: post.text, facets: post.facets, entities: post.entities)
    }

    // MARK: Lengths

    /// The length of the text in UTF-8 bytes, the unit facet offsets use.
    public var utf8Length: Int {
        text.utf8.count
    }

    /// The length of the text in grapheme clusters, the unit post length limits use.
    public var graphemeLength: Int {
        text.count
    }

    /// Whether the text is longer than a post may be (300 graphemes or 3000 bytes).
    public var exceedsPostLimits: Bool {
        utf8Length > Self.maxPostUTF8Bytes || graphemeLength > Self.maxPostGraphemes
    }

    /// The facets in the form a record field takes: `nil` when there are none.
    public var recordFacets: [AppBskyRichtextFacet]? {
        facets.isEmpty ? nil : facets
    }

    // MARK: Slicing and segments

    /// The text between two UTF-8 byte offsets.
    ///
    /// Offsets are clamped to the text. A slice that cuts through a multi-byte
    /// character decodes the partial bytes as U+FFFD instead of failing.
    public func slice(byteStart: Int, byteEnd: Int) -> String {
        Self.slice(Array(text.utf8), byteStart, byteEnd)
    }

    private static func slice(_ bytes: [UInt8], _ byteStart: Int, _ byteEnd: Int) -> String {
        let start = min(max(byteStart, 0), bytes.count)
        let end = min(max(byteEnd, start), bytes.count)
        return String(decoding: bytes[start ..< end], as: UTF8.self)
    }

    /// Splits the text into runs with and without a facet, in order.
    ///
    /// A facet that starts before the previous one ended is skipped, and a
    /// facet that covers only whitespace yields a plain segment. Concatenating
    /// the segments' text always gives back the original text.
    public func segments() -> [RichTextSegment] {
        guard !facets.isEmpty else {
            return [RichTextSegment(text: text)]
        }
        let bytes = Array(text.utf8)
        var segments: [RichTextSegment] = []
        var textCursor = 0
        var facetCursor = 0

        func appendPlain(_ start: Int, _ end: Int) {
            let piece = Self.slice(bytes, start, end)
            if !piece.isEmpty {
                segments.append(RichTextSegment(text: piece))
            }
        }

        repeat {
            let facet = facets[facetCursor]
            let start = facet.index.byteStart
            let end = facet.index.byteEnd
            if textCursor < start {
                appendPlain(textCursor, start)
            } else if textCursor > start {
                facetCursor += 1
                continue
            }
            if start < end {
                let piece = Self.slice(bytes, start, end)
                if JSText.isBlank(piece) {
                    // Do not attach a facet to nothing but whitespace.
                    if !piece.isEmpty {
                        segments.append(RichTextSegment(text: piece))
                    }
                } else {
                    segments.append(RichTextSegment(text: piece, facet: facet))
                }
            }
            textCursor = end
            facetCursor += 1
        } while facetCursor < facets.count

        if textCursor < bytes.count {
            appendPlain(textCursor, bytes.count)
        }
        return segments
    }

    // MARK: Editing

    /// Inserts text at a UTF-8 byte offset and moves the facets accordingly.
    ///
    /// Facets at or after the insertion point shift; a facet the insertion
    /// point lies inside grows; facets before it are untouched. The offset is
    /// clamped to the text.
    ///
    /// - Parameters:
    ///   - insertText: The text to insert.
    ///   - byteIndex: Where to insert, in UTF-8 bytes.
    public mutating func insert(_ insertText: String, at byteIndex: Int) {
        let bytes = Array(text.utf8)
        let index = min(max(byteIndex, 0), bytes.count)
        let inserted = Array(insertText.utf8)
        text = String(decoding: bytes[..<index] + inserted + bytes[index...], as: UTF8.self)

        let added = inserted.count
        guard added > 0, !facets.isEmpty else { return }
        facets = facets.map { facet in
            let start = facet.index.byteStart
            let end = facet.index.byteEnd
            if index <= start {
                return Self.moving(facet, start: Self.offset(start, by: added), end: Self.offset(end, by: added))
            } else if index < end {
                return Self.moving(facet, start: start, end: Self.offset(end, by: added))
            }
            return facet
        }
    }

    /// Removes the text between two UTF-8 byte offsets and adjusts the facets.
    ///
    /// Facets entirely inside the removed range are dropped; facets that
    /// overlap it shrink; facets after it shift. Offsets are clamped to the
    /// text, and an empty or inverted range does nothing.
    public mutating func delete(byteStart: Int, byteEnd: Int) {
        let bytes = Array(text.utf8)
        let removeStart = min(max(byteStart, 0), bytes.count)
        let removeEnd = min(max(byteEnd, 0), bytes.count)
        guard removeStart < removeEnd else { return }
        text = String(decoding: bytes[..<removeStart] + bytes[removeEnd...], as: UTF8.self)

        guard !facets.isEmpty else { return }
        let removed = removeEnd - removeStart
        facets = facets.compactMap { facet in
            var start = facet.index.byteStart
            var end = facet.index.byteEnd
            if removeStart <= start, removeEnd >= end {
                // Entirely covered: drop.
                return nil
            } else if removeStart > end {
                // Entirely after the facet: unchanged.
            } else if removeStart > start, removeStart <= end, removeEnd > end {
                // Cuts off the facet's tail.
                end = removeStart
            } else if removeStart >= start, removeEnd <= end {
                // Inside the facet.
                end = Self.offset(end, by: -removed)
            } else if removeStart < start, removeEnd >= start, removeEnd <= end {
                // Cuts off the facet's head.
                start = removeStart
                end = Self.offset(end, by: -removed)
            } else if removeEnd < start {
                // Entirely before the facet.
                start = Self.offset(start, by: -removed)
                end = Self.offset(end, by: -removed)
            }
            guard start < end else { return nil }
            return Self.moving(facet, start: start, end: end)
        }
    }

    /// Appends plain text.
    public mutating func append(_ string: String) {
        insert(string, at: utf8Length)
    }

    /// Appends text that links to `uri`.
    public mutating func appendLink(_ string: String, uri: URI) {
        appendFaceted(string, feature: .appBskyRichtextFacetLink(AppBskyRichtextFacet.Link(uri: uri)))
    }

    /// Appends text that mentions the account `did`.
    public mutating func appendMention(_ string: String, did: DID) {
        appendFaceted(string, feature: .appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: did)))
    }

    /// Appends text that carries the hashtag `tag` (without the `#`).
    public mutating func appendTag(_ string: String, tag: String) {
        appendFaceted(string, feature: .appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: tag)))
    }

    private mutating func appendFaceted(
        _ string: String,
        feature: AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion
    ) {
        let start = utf8Length
        text += string
        guard !string.isEmpty else { return }
        facets.append(AppBskyRichtextFacet(
            index: AppBskyRichtextFacet.ByteSlice(byteStart: start, byteEnd: utf8Length),
            features: [feature]
        ))
    }

    // MARK: Detection

    /// Finds mentions, links, hashtags and cashtags in plain text.
    ///
    /// This is the same detection the official client performs. Mentions are
    /// reported with their handle; turning them into facets needs a DID, see
    /// ``detectFacets(resolveMention:)``.
    public static func detect(in text: String) -> [RichTextDetection] {
        RichTextDetector.detect(text).enumerated()
            .sorted { ($0.element.byteStart, $0.offset) < ($1.element.byteStart, $1.offset) }
            .map(\.element)
    }

    /// Replaces the facets with the ones detected in the text, resolving
    /// mentioned handles to DIDs.
    ///
    /// Handles are resolved concurrently, each one once. A mention whose handle
    /// does not resolve (the closure returns `nil` or throws) is left as plain
    /// text, because a mention facet without a DID is not a valid record.
    ///
    /// - Parameter resolveMention: Maps a handle (without `@`) to its DID.
    public mutating func detectFacets(
        resolveMention: @escaping @Sendable (String) async throws -> DID?
    ) async {
        let detections = Self.detect(in: text)
        var handles: Set<String> = []
        for detection in detections {
            if case let .mention(handle) = detection.kind {
                handles.insert(handle)
            }
        }

        let resolved = await withTaskGroup(of: (String, DID?).self) { group -> [String: DID] in
            for handle in handles {
                group.addTask {
                    let did = try? await resolveMention(handle)
                    return (handle, did)
                }
            }
            var resolved: [String: DID] = [:]
            for await (handle, did) in group {
                if let did {
                    resolved[handle] = did
                }
            }
            return resolved
        }
        facets = Self.facets(from: detections, mentions: resolved)
    }

    /// Replaces the facets with the links and tags detected in the text.
    ///
    /// Mentions are not turned into facets, because that requires resolving
    /// each handle to a DID. Use ``detectFacets(resolveMention:)`` for posts
    /// that may mention accounts.
    public mutating func detectFacetsWithoutResolution() {
        facets = Self.facets(from: Self.detect(in: text), mentions: [:])
    }

    private static func facets(
        from detections: [RichTextDetection],
        mentions: [String: DID]
    ) -> [AppBskyRichtextFacet] {
        detections.compactMap { detection in
            let feature: AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion
            switch detection.kind {
            case let .mention(handle):
                guard let did = mentions[handle] else { return nil }
                feature = .appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: did))
            case let .link(uri):
                feature = .appBskyRichtextFacetLink(AppBskyRichtextFacet.Link(uri: URI(uriString: uri)))
            case let .tag(tag):
                feature = .appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: tag))
            }
            return AppBskyRichtextFacet(
                index: AppBskyRichtextFacet.ByteSlice(byteStart: detection.byteStart, byteEnd: detection.byteEnd),
                features: [feature]
            )
        }
    }

    // MARK: Sanitizing

    /// `/[\r\n]([­⁠‍‌​\s]*[\r\n]){2,}/`
    private static let excessSpaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[\r\n]([­⁠‍‌​\#(JSText.whitespaceClass)]*[\r\n]){2,}"#,
        options: []
    )

    /// Returns a cleaned copy of the rich text with facets kept in place.
    ///
    /// - Parameter cleanNewlines: Collapse every run of three or more line
    ///   breaks (ignoring whitespace and zero-width characters between them)
    ///   into exactly two.
    public func sanitized(cleanNewlines: Bool) -> RichText {
        guard cleanNewlines, let regex = Self.excessSpaceRegex else { return self }
        var result = self
        while true {
            let utf16 = NSString(string: result.text)
            guard let match = regex.firstMatch(
                in: result.text,
                options: [],
                range: NSRange(location: 0, length: utf16.length)
            ) else {
                break
            }
            let before = result.text
            let removeStart = UTF16ToUTF8Offsets(before).utf8Offset(atUTF16: match.range.location)
            let removeEnd = removeStart + utf16.substring(with: match.range).utf8.count
            result.delete(byteStart: removeStart, byteEnd: removeEnd)
            if result.text == before {
                break
            }
            result.insert("\n\n", at: removeStart)
        }
        return result
    }

    // MARK: Link shortening

    /// Shortens a URL for display: the scheme is dropped and a long path is
    /// cut to 13 characters followed by `...`.
    ///
    /// `https://example.com/a/very/long/path?query` becomes
    /// `example.com/a/very/long/...`. Text that is not an `http` or `https` URL
    /// is returned unchanged. Only the displayed text should be shortened; the
    /// link facet keeps the full URI.
    public static func shortenedURL(_ url: String) -> String {
        guard let components = URLComponents(string: url),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let rawHost = components.host, !rawHost.isEmpty
        else {
            return url
        }
        var host = rawHost.lowercased()
        if let port = components.port {
            host += ":\(port)"
        }
        var path = components.percentEncodedPath == "/" ? "" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            path += "?" + query
        }
        if let fragment = components.percentEncodedFragment {
            path += "#" + fragment
        }
        if path.count > 15 {
            return host + path.prefix(13) + "..."
        }
        return host + path
    }

    /// Returns a copy in which the visible text of every link facet is
    /// replaced by its shortened form, with all facet offsets updated.
    ///
    /// The facets' URIs are untouched, so links still lead to the full address.
    public func shorteningLinks() -> RichText {
        var result = self
        for position in result.facets.indices {
            let facet = result.facets[position]
            guard facet.features.contains(where: {
                if case .appBskyRichtextFacetLink = $0 { return true }
                return false
            }) else { continue }

            let bytes = Array(result.text.utf8)
            let start = facet.index.byteStart
            let end = facet.index.byteEnd
            guard start >= 0, start < end, end <= bytes.count else { continue }

            let shown = Self.slice(bytes, start, end)
            let shortened = Self.shortenedURL(shown)
            guard shortened != shown else { continue }

            let replacement = Array(shortened.utf8)
            result.text = String(decoding: bytes[..<start] + replacement + bytes[end...], as: UTF8.self)
            let delta = replacement.count - (end - start)
            result.facets = result.facets.enumerated().map { other, candidate in
                let otherStart = candidate.index.byteStart
                let otherEnd = candidate.index.byteEnd
                if other == position {
                    return Self.moving(candidate, start: start, end: start + replacement.count)
                } else if otherStart >= end {
                    return Self.moving(
                        candidate,
                        start: Self.offset(otherStart, by: delta),
                        end: Self.offset(otherEnd, by: delta)
                    )
                } else if otherStart <= start, otherEnd >= end {
                    return Self.moving(candidate, start: otherStart, end: Self.offset(otherEnd, by: delta))
                }
                return candidate
            }
        }
        return result
    }

    // MARK: Helpers

    /// Adds without trapping. Offsets come from untrusted records and may be
    /// anywhere in the `Int` range, so shifts saturate instead of overflowing.
    private static func offset(_ value: Int, by delta: Int) -> Int {
        let (result, overflow) = value.addingReportingOverflow(delta)
        guard overflow else { return result }
        return delta > 0 ? Int.max : Int.min
    }

    private static func moving(_ facet: AppBskyRichtextFacet, start: Int, end: Int) -> AppBskyRichtextFacet {
        AppBskyRichtextFacet(
            index: AppBskyRichtextFacet.ByteSlice(byteStart: start, byteEnd: end),
            features: facet.features
        )
    }

    /// Sorts by start offset, keeping the given order for equal starts.
    private static func sorted(_ facets: [AppBskyRichtextFacet]) -> [AppBskyRichtextFacet] {
        facets.enumerated()
            .sorted { ($0.element.index.byteStart, $0.offset) < ($1.element.index.byteStart, $1.offset) }
            .map(\.element)
    }

    private static func facets(
        from entities: [AppBskyFeedPost.Entity],
        in text: String
    ) -> [AppBskyRichtextFacet] {
        let offsets = UTF16ToUTF8Offsets(text)
        return entities.compactMap { entity in
            let feature: AppBskyRichtextFacet.AppBskyRichtextFacetFeaturesUnion
            switch entity.type {
            case "link":
                feature = .appBskyRichtextFacetLink(AppBskyRichtextFacet.Link(uri: URI(uriString: entity.value)))
            case "mention":
                guard let did = try? DID(didString: entity.value) else { return nil }
                feature = .appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention(did: did))
            default:
                return nil
            }
            return AppBskyRichtextFacet(
                index: AppBskyRichtextFacet.ByteSlice(
                    byteStart: offsets.utf8Offset(atUTF16: entity.index.start),
                    byteEnd: offsets.utf8Offset(atUTF16: entity.index.end)
                ),
                features: [feature]
            )
        }
    }
}

/// A run of rich text: plain text, or text annotated by one facet.
public struct RichTextSegment: Sendable, Hashable {
    /// The text of this run.
    public let text: String
    /// The facet annotating this run, or `nil` for plain text.
    public let facet: AppBskyRichtextFacet?

    /// Creates a segment.
    public init(text: String, facet: AppBskyRichtextFacet? = nil) {
        self.text = text
        self.facet = facet
    }

    /// The link feature of this run, if it is a link.
    public var link: AppBskyRichtextFacet.Link? {
        guard let facet else { return nil }
        for feature in facet.features {
            if case let .appBskyRichtextFacetLink(link) = feature { return link }
        }
        return nil
    }

    /// The mention feature of this run, if it is a mention.
    public var mention: AppBskyRichtextFacet.Mention? {
        guard let facet else { return nil }
        for feature in facet.features {
            if case let .appBskyRichtextFacetMention(mention) = feature { return mention }
        }
        return nil
    }

    /// The tag feature of this run, if it is a hashtag or cashtag.
    public var tag: AppBskyRichtextFacet.Tag? {
        guard let facet else { return nil }
        for feature in facet.features {
            if case let .appBskyRichtextFacetTag(tag) = feature { return tag }
        }
        return nil
    }

    /// Whether this run is a link.
    public var isLink: Bool {
        link != nil
    }

    /// Whether this run is a mention.
    public var isMention: Bool {
        mention != nil
    }

    /// Whether this run is a hashtag or cashtag.
    public var isTag: Bool {
        tag != nil
    }
}
