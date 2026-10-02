import Foundation
import CJSONBridge
import Petrel

/// Partial generated-decoder experiment: timeline, FeedViewPost and PostView are
/// constructed directly. Semantic leaves and complex unions use their real
/// Petrel Decodable implementations. Simple known post records additionally
/// bypass the dynamic raw-graph/typed-graph round trip, under a conservative
/// shape gate. All other records use Petrel's original dynamic decoder.
func directTimeline(_ data: Data) throws -> AppBskyFeedGetTimeline.Output {
    let document = try SIMDDocument(data)
    return try withExtendedLifetime(document) {
        let root = document.root
        try root.requireObject()
        let feedNode = try root.required("feed")
        let feed = try feedNode.mapArray { try directFeedViewPost($0) }
        return AppBskyFeedGetTimeline.Output(cursor: root.tolerant("cursor", as: String.self), feed: feed)
    }
}

private func directFeedViewPost(_ node: DOMNode) throws -> AppBskyFeedDefs.FeedViewPost {
    try node.requireObject()
    return try AppBskyFeedDefs.FeedViewPost(
        post: directPostView(node.required("post")),
        reply: node.tolerant("reply", as: AppBskyFeedDefs.ReplyRef.self),
        reason: node.tolerant("reason", as: AppBskyFeedDefs.FeedViewPostReasonUnion.self),
        feedContext: node.tolerant("feedContext", as: String.self),
        reqId: node.tolerant("reqId", as: String.self)
    )
}

private func directPostView(_ node: DOMNode) throws -> AppBskyFeedDefs.PostView {
    try node.requireObject()
    return try AppBskyFeedDefs.PostView(
        uri: node.required("uri").decoded(ATProtocolURI.self),
        cid: node.required("cid").decoded(CID.self),
        author: node.required("author").decoded(AppBskyActorDefs.ProfileViewBasic.self),
        record: directRecord(node.required("record")),
        embed: node.tolerant("embed", as: AppBskyFeedDefs.PostViewEmbedUnion.self),
        bookmarkCount: node.tolerant("bookmarkCount", as: Int.self),
        replyCount: node.tolerant("replyCount", as: Int.self),
        repostCount: node.tolerant("repostCount", as: Int.self),
        likeCount: node.tolerant("likeCount", as: Int.self),
        quoteCount: node.tolerant("quoteCount", as: Int.self),
        indexedAt: node.required("indexedAt").decoded(ATProtocolDate.self),
        viewer: node.tolerant("viewer", as: AppBskyFeedDefs.ViewerState.self),
        labels: node.tolerant("labels", as: [ComAtprotoLabelDefs.Label].self),
        threadgate: node.tolerant("threadgate", as: AppBskyFeedDefs.ThreadgateView.self),
        debug: node.tolerant("debug", as: ATProtocolValueContainer.self)
    )
}

private func directRecord(_ node: DOMNode) throws -> ATProtocolValueContainer {
    if isSimpleRecordShape(node), let value = try? simpleRecord(node) {
        return .knownType(value)
    }
    return try node.decoded(ATProtocolValueContainer.self)
}

private func simpleRecord(_ node: DOMNode) throws -> AppBskyFeedPost {
    try AppBskyFeedPost(
        text: node.required("text").string(),
        facets: node.tolerant("facets", as: [AppBskyRichtextFacet].self),
        langs: node.tolerant("langs", as: [LanguageCodeContainer].self),
        tags: node.tolerant("tags", as: [String].self),
        createdAt: node.required("createdAt").decoded(ATProtocolDate.self)
    )
}

/// Explicit allowlist: unsupported fields/unknown nested fields fall back to
/// the full baseline semantics. It is intentionally not a general generator.
/// Raw date and language strings are preserved by the existing Petrel types.
private func isSimpleRecordShape(_ node: DOMNode) -> Bool {
    guard node.isObject, (try? node.field("$type")?.string()) == AppBskyFeedPost.typeIdentifier,
          node.onlyKeys(["$type", "text", "createdAt", "facets", "langs", "tags"]) else { return false }
    if let facets = node.field("facets"), !facets.isNull {
        guard facets.allArraySatisfy({ facet in
            guard facet.onlyKeys(["index", "features"]),
                  let index = facet.field("index"), index.onlyKeys(["$type", "byteStart", "byteEnd"]),
                  index.typeIsAbsentOr("app.bsky.richtext.facet#byteSlice"),
                  let features = facet.field("features") else { return false }
            return features.allArraySatisfy { feature in
                guard let type = try? feature.field("$type")?.string() else { return false }
                switch type {
                case "app.bsky.richtext.facet#mention": return feature.onlyKeys(["$type", "did"])
                case "app.bsky.richtext.facet#link":
                    // URI's real Decodable and uriString() may normalize more
                    // than whitespace. Match its actual serialized value before
                    // bypassing the baseline's lossless record check.
                    guard feature.onlyKeys(["$type", "uri"]),
                          let uriNode = feature.field("uri"),
                          let uri = try? uriNode.string(), !uri.isEmpty,
                          let typedURI = try? uriNode.decoded(URI.self),
                          uri == typedURI.uriString() else { return false }
                    return true
                case "app.bsky.richtext.facet#tag": return feature.onlyKeys(["$type", "tag"])
                default: return false
                }
            }
        }) else { return false }
    }
    return true
}

/// Diagnostic only, never run inside a measured decoding interval.
func directRecordCoverage(_ data: Data) throws -> (eligible: Int, total: Int) {
    let document = try SIMDDocument(data)
    return try withExtendedLifetime(document) {
        var eligible = 0, total = 0
        _ = try document.root.required("feed").mapArray { entry -> Int in
            if let record = entry.field("post")?.field("record") {
                total += 1
                if isSimpleRecordShape(record) { eligible += 1 }
            }
            return 0
        }
        return (eligible, total)
    }
}

extension DOMNode {
    func decoded<T: Decodable>(_ type: T.Type) throws -> T { try DOMDecoder(node: self).decode(type) }
    func requireObject() throws {
        guard isObject else { throw mismatch([String: Any].self, []) }
    }
    func required(_ key: String) throws -> DOMNode {
        guard let node = field(key) else {
            throw DecodingError.keyNotFound(DOMKey(key), .init(codingPath: [], debugDescription: "Missing \(key)"))
        }
        return node
    }
    func tolerant<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let child = field(key), !child.isNull else { return nil }
        return try? child.decoded(type)
    }
    func mapArray<T>(_ transform: (DOMNode) throws -> T) throws -> [T] {
        var cursor = sj_value(), end = sj_value(), count = 0, value = sj_value()
        guard sj_array_begin(raw, &cursor, &end, &count) == 0 else { throw mismatch([Any].self, []) }
        var result: [T] = []; result.reserveCapacity(count)
        while sj_array_next(&cursor, end, &value) != 0 { result.append(try transform(DOMNode(raw: value))) }
        return result
    }
    func onlyKeys(_ allowed: Set<String>) -> Bool {
        isObject && keys().allSatisfy { allowed.contains($0) }
    }
    func typeIsAbsentOr(_ expected: String) -> Bool {
        guard let type = field("$type") else { return true }
        return (try? type.string()) == expected
    }
    func allArraySatisfy(_ predicate: (DOMNode) -> Bool) -> Bool {
        var cursor = sj_value(), end = sj_value(), count = 0, value = sj_value()
        guard sj_array_begin(raw, &cursor, &end, &count) == 0 else { return false }
        while sj_array_next(&cursor, end, &value) != 0 {
            if !predicate(DOMNode(raw: value)) { return false }
        }
        return true
    }
}
