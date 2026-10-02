import Foundation
import Petrel

/// Foundation-only counterpart to the partial direct SIMD experiment. It still
/// constructs actual Petrel models and delegates semantic leaves and complex
/// records/unions to their existing Codable implementations. No production code
/// or generator output is changed.
func directFoundationTimeline(_ data: Data) throws -> AppBskyFeedGetTimeline.Output {
    try JSONDecoder().decode(FoundationFastTimeline.self, from: data).value
}

private struct FoundationFastTimeline: Decodable {
    let value: AppBskyFeedGetTimeline.Output
    private enum Keys: String, CodingKey { case cursor, feed }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        var array = try container.nestedUnkeyedContainer(forKey: .feed)
        var feed: [AppBskyFeedDefs.FeedViewPost] = []
        if let count = array.count { feed.reserveCapacity(count) }
        while !array.isAtEnd {
            feed.append(try array.decode(FoundationFastFeed.self).value)
        }
        value = AppBskyFeedGetTimeline.Output(
            cursor: container.foundationFastTolerant(String.self, forKey: .cursor),
            feed: feed
        )
    }
}

private struct FoundationFastFeed: Decodable {
    let value: AppBskyFeedDefs.FeedViewPost
    private enum Keys: String, CodingKey { case post, reply, reason, feedContext, reqId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        value = try AppBskyFeedDefs.FeedViewPost(
            post: container.decode(FoundationFastPost.self, forKey: .post).value,
            reply: container.foundationFastTolerant(AppBskyFeedDefs.ReplyRef.self, forKey: .reply),
            reason: container.foundationFastTolerant(AppBskyFeedDefs.FeedViewPostReasonUnion.self, forKey: .reason),
            feedContext: container.foundationFastTolerant(String.self, forKey: .feedContext),
            reqId: container.foundationFastTolerant(String.self, forKey: .reqId)
        )
    }
}

private struct FoundationFastPost: Decodable {
    let value: AppBskyFeedDefs.PostView
    private enum Keys: String, CodingKey {
        case uri, cid, author, record, embed, bookmarkCount, replyCount
        case repostCount, likeCount, quoteCount, indexedAt, viewer, labels, threadgate, debug
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        value = try AppBskyFeedDefs.PostView(
            uri: container.decode(ATProtocolURI.self, forKey: .uri),
            cid: container.decode(CID.self, forKey: .cid),
            author: container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author),
            record: container.decode(FoundationFastRecord.self, forKey: .record).value,
            embed: container.foundationFastTolerant(AppBskyFeedDefs.PostViewEmbedUnion.self, forKey: .embed),
            bookmarkCount: container.foundationFastTolerant(Int.self, forKey: .bookmarkCount),
            replyCount: container.foundationFastTolerant(Int.self, forKey: .replyCount),
            repostCount: container.foundationFastTolerant(Int.self, forKey: .repostCount),
            likeCount: container.foundationFastTolerant(Int.self, forKey: .likeCount),
            quoteCount: container.foundationFastTolerant(Int.self, forKey: .quoteCount),
            indexedAt: container.decode(ATProtocolDate.self, forKey: .indexedAt),
            viewer: container.foundationFastTolerant(AppBskyFeedDefs.ViewerState.self, forKey: .viewer),
            labels: container.foundationFastTolerant([ComAtprotoLabelDefs.Label].self, forKey: .labels),
            threadgate: container.foundationFastTolerant(AppBskyFeedDefs.ThreadgateView.self, forKey: .threadgate),
            debug: container.foundationFastTolerant(ATProtocolValueContainer.self, forKey: .debug)
        )
    }
}

private extension KeyedDecodingContainer {
    /// Matches generated optional-field degradation to nil. Logging is omitted
    /// in this benchmark prototype; successful well-formed corpus cases do not
    /// depend on warning side effects.
    func foundationFastTolerant<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}

private struct FoundationFastRecord: Decodable {
    let value: ATProtocolValueContainer

    init(from decoder: Decoder) throws {
        if let shape = try? FoundationSimpleRecordShape(from: decoder), shape.eligible,
           let post = try? AppBskyFeedPost(from: decoder),
           // A malformed optional can otherwise be swallowed by AppBskyFeedPost
           // while the original dynamic raw walk throws or preserves fallback.
           // Only shortcut when every non-null optional successfully survived.
           (!shape.hasFacets || post.facets != nil),
           (!shape.hasLangs || post.langs != nil),
           (!shape.hasTags || post.tags != nil) {
            value = .knownType(post)
        } else {
            value = try ATProtocolValueContainer(from: decoder)
        }
    }
}

private struct FoundationAnyKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

private func foundationAllowedKeys(
    _ container: KeyedDecodingContainer<FoundationAnyKey>,
    _ allowed: Set<String>
) throws {
    guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw FoundationFastShapeError.unsupported
    }
}

private enum FoundationFastShapeError: Error { case unsupported }

private struct FoundationSimpleRecordShape: Decodable {
    private static let allowed: Set<String> = ["$type", "text", "createdAt", "facets", "langs", "tags"]
    let eligible: Bool
    let hasFacets: Bool
    let hasLangs: Bool
    let hasTags: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FoundationAnyKey.self)
        guard c.allKeys.allSatisfy({ Self.allowed.contains($0.stringValue) }),
              try c.decode(String.self, forKey: FoundationAnyKey("$type")) == AppBskyFeedPost.typeIdentifier else {
            // Unsupported complex records are normal, so avoid allocating and
            // throwing an error for this common fallback decision.
            eligible = false
            hasFacets = false
            hasLangs = false
            hasTags = false
            return
        }
        func hasNonNull(_ key: String) throws -> Bool {
            let codingKey = FoundationAnyKey(key)
            return try c.contains(codingKey) && !c.decodeNil(forKey: codingKey)
        }
        hasFacets = try hasNonNull("facets")
        hasLangs = try hasNonNull("langs")
        hasTags = try hasNonNull("tags")
        if hasFacets {
            var facets = try c.nestedUnkeyedContainer(forKey: FoundationAnyKey("facets"))
            while !facets.isAtEnd { _ = try facets.decode(FoundationFacetShape.self) }
        }
        eligible = true
    }
}

private struct FoundationFacetShape: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FoundationAnyKey.self)
        try foundationAllowedKeys(c, ["index", "features"])
        let index = try c.nestedContainer(keyedBy: FoundationAnyKey.self, forKey: FoundationAnyKey("index"))
        try foundationAllowedKeys(index, ["$type", "byteStart", "byteEnd"])
        if index.contains(FoundationAnyKey("$type")) {
            guard try index.decode(String.self, forKey: FoundationAnyKey("$type")) == "app.bsky.richtext.facet#byteSlice" else {
                throw FoundationFastShapeError.unsupported
            }
        }
        var features = try c.nestedUnkeyedContainer(forKey: FoundationAnyKey("features"))
        while !features.isAtEnd { _ = try features.decode(FoundationFacetFeatureShape.self) }
    }
}

private struct FoundationFacetFeatureShape: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FoundationAnyKey.self)
        switch try c.decode(String.self, forKey: FoundationAnyKey("$type")) {
        case "app.bsky.richtext.facet#mention": try foundationAllowedKeys(c, ["$type", "did"])
        case "app.bsky.richtext.facet#link":
            try foundationAllowedKeys(c, ["$type", "uri"])
            let key = FoundationAnyKey("uri")
            let wire = try c.decode(String.self, forKey: key)
            // URI trims whitespace and reconstructs some schemes through
            // URLComponents. Either can change the value emitted by CBOR/JSON
            // and must trigger the baseline's raw/typed fidelity fallback.
            // Checking only whitespace misses percent-encoding, invalid-scheme,
            // userinfo/port and other reconstruction differences. Decode the
            // real leaf and require exact wire fidelity before shortcutting.
            guard !wire.isEmpty, try c.decode(URI.self, forKey: key).uriString() == wire else {
                throw FoundationFastShapeError.unsupported
            }
        case "app.bsky.richtext.facet#tag": try foundationAllowedKeys(c, ["$type", "tag"])
        default: throw FoundationFastShapeError.unsupported
        }
    }
}
