import Foundation
import Petrel

/// Runs outside measured regions. Petrel intentionally tolerates failed optional
/// decodes, so decoding success alone is insufficient to validate fixture shape.
func validateCorpus(_ fixtures: [Fixture], strategy: Strategy = .foundationFresh) throws -> [String] {
    let context = Context(strategy)
    var checks: [String] = []
    for fixture in fixtures {
        let name = fixture.entry.id
        let root = try JSONSerialization.jsonObject(with: fixture.data) as! [String: Any]
        switch fixture.entry.modelKind {
        case "profile":
            let model = try decode(fixture, context) as! AppBskyActorGetProfile.Output
            try corpusRequire(model.displayName == root["displayName"] as? String, "\(name): displayName")
            try corpusRequire(model.avatar != nil && model.banner != nil && model.website != nil, "\(name): profile URLs")
            try corpusRequire(model.createdAt != nil && model.indexedAt != nil, "\(name): profile dates")
            try corpusRequire(model.pinnedPost != nil && model.associated?.chat != nil && model.viewer?.following != nil, "\(name): nested profile fields")
            checks.append("\(name): detailed profile, URLs, dates, pinned post, associated chat and viewer decoded")
        case "search":
            let model = try decode(fixture, context) as! AppBskyActorSearchActors.Output
            let actors = root["actors"] as! [[String: Any]]
            try corpusRequire(model.actors.count == 50 && model.actors.count == actors.count, "\(name): actor count")
            for (index, actor) in model.actors.enumerated() {
                try corpusRequire(actor.displayName == actors[index]["displayName"] as? String, "\(name)[\(index)]: displayName")
                try corpusRequire(actor.avatar != nil && actor.createdAt != nil && actor.indexedAt != nil && actor.associated?.chat != nil && actor.viewer?.following != nil, "\(name)[\(index)]: optional model fields")
            }
            checks.append("\(name): 50 actors including Unicode names; nested fields and dates retained")
        case "timeline":
            let model = try decode(fixture, context) as! AppBskyFeedGetTimeline.Output
            if fixture.entry.validator == "fidelity-edge" {
                checks.append(try validateFidelityEdge(fixture, model, root))
                continue
            }
            let feed = root["feed"] as! [[String: Any]]
            let expected = name == "very-large-feed" ? 800 : 100
            try corpusRequire(model.feed.count == expected && feed.count == expected, "\(name): feed count")
            var known = 0, unknown = 0, embeds = 0, replies = 0, reasons = 0
            for (index, item) in model.feed.enumerated() {
                let raw = feed[index]
                let rawPost = raw["post"] as! [String: Any]
                try validateCorpusPost(item.post, raw: rawPost, path: "\(name).feed[\(index)].post")
                if case .knownType = item.post.record { known += 1 }
                if case .unknownType = item.post.record { unknown += 1 }
                if item.post.embed != nil { embeds += 1 }
                try corpusRequire((item.reply != nil) == (raw["reply"] != nil), "\(name)[\(index)]: reply retained")
                if let reply = item.reply {
                    replies += 1
                    let rawReply = raw["reply"] as! [String: Any]
                    guard case let .appBskyFeedDefsPostView(rootPost) = reply.root,
                          case let .appBskyFeedDefsPostView(parentPost) = reply.parent else {
                        throw BenchError.message("\(name)[\(index)]: reply unions lost typed post views")
                    }
                    try validateCorpusPost(rootPost, raw: rawReply["root"] as! [String: Any], path: "\(name)[\(index)].reply.root")
                    try validateCorpusPost(parentPost, raw: rawReply["parent"] as! [String: Any], path: "\(name)[\(index)].reply.parent")
                    try corpusRequire(reply.grandparentAuthor != nil, "\(name)[\(index)]: grandparent author")
                }
                try corpusRequire((item.reason != nil) == (raw["reason"] != nil), "\(name)[\(index)]: reason retained")
                if let reason = item.reason {
                    reasons += 1
                    let tag = (raw["reason"] as! [String: Any])["$type"] as! String
                    switch reason {
                    case .appBskyFeedDefsReasonRepost:
                        try corpusRequire(tag == "app.bsky.feed.defs#reasonRepost", "\(name): repost reason tag")
                    case let .unexpected(value):
                        guard case let .unknownType(type, _) = value, type == tag else {
                            throw BenchError.message("\(name): unknown reason not retained")
                        }
                    default: throw BenchError.message("\(name): unexpected fixture reason case")
                    }
                }
            }
            try corpusRequire(known == (name == "difficult-feed" ? 80 : expected), "\(name): expected typed AppBskyFeedPost record count")
            try corpusRequire(unknown == (name == "difficult-feed" ? 20 : 0), "\(name): expected unknown record count")
            checks.append("\(name): \(expected) feed entries, \(known) typed records, \(unknown) unknown records, \(embeds) embeds, \(replies) replies, \(reasons) reasons; facets, quote records, labels and optional fields retained")
        case "records":
            let model = try decode(fixture, context) as! ComAtprotoRepoListRecords.Output
            try corpusRequire(model.records.count == 32, "\(name): record count")
            var bytes = 0
            for record in model.records {
                guard case let .unknownType(type, inner) = record.value,
                      type == "test.example.binary",
                      case let .object(properties) = inner,
                      let payload = properties["payload"],
                      case let .bytes(value) = payload else {
                    throw BenchError.message("\(name): dynamic IPLD $bytes not retained as Bytes")
                }
                try corpusRequire(value.data.count == 32_768, "\(name): decoded payload length")
                bytes += value.data.count
            }
            try corpusRequire(bytes == 1_048_576, "\(name): decoded bytes total")
            checks.append("\(name): 32 unknown extension records with 1,048,576 decoded binary bytes")
        default:
            throw BenchError.message("Unsupported corpus model kind: \(fixture.entry.modelKind)")
        }
    }
    return checks
}

private func corpusRequire(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw BenchError.message("Corpus validation: " + message) }
}

private func validateCorpusRecord(_ container: ATProtocolValueContainer, raw: [String: Any], path: String) throws {
    let tag = raw["$type"] as! String
    if tag != "app.bsky.feed.post" {
        guard case let .unknownType(actual, .object(properties)) = container,
              actual == tag, properties["settings"] != nil else {
            throw BenchError.message("Corpus validation: \(path): unknown record not preserved")
        }
        return
    }
    guard case let .knownType(value) = container, let post = value as? AppBskyFeedPost else {
        throw BenchError.message("Corpus validation: \(path): expected typed AppBskyFeedPost, got fallback")
    }
    try corpusRequire(post.text == raw["text"] as? String, "\(path): text")
    try corpusRequire(post.facets?.count == 3 && post.langs != nil && post.tags?.count == 2, "\(path): facets/languages/tags retained")
    try corpusRequire((post.embed != nil) == (raw["embed"] != nil), "\(path): record embed retained")
    try corpusRequire((post.reply != nil) == (raw["reply"] != nil), "\(path): record reply retained")
    let utf8 = Array(post.text.utf8)
    for facet in post.facets ?? [] {
        let lower = facet.index.byteStart, upper = facet.index.byteEnd
        try corpusRequire(lower >= 0 && upper <= utf8.count && lower < upper, "\(path): UTF-8 facet range")
        try corpusRequire(String(bytes: utf8[lower..<upper], encoding: .utf8) != nil && facet.features.count == 1, "\(path): facet boundaries and features")
    }
    if let embed = post.embed, case .unexpected = embed {
        throw BenchError.message("Corpus validation: \(path): known record embed lost typed union case")
    }
}

private func validateCorpusQuote(_ view: AppBskyEmbedRecord.View, raw: [String: Any], path: String) throws {
    guard case let .appBskyEmbedRecordViewRecord(quote) = view.record else {
        throw BenchError.message("Corpus validation: \(path): missing typed quoted record view")
    }
    let rawQuote = raw["record"] as! [String: Any]
    try validateCorpusRecord(quote.value, raw: rawQuote["value"] as! [String: Any], path: path + ".value")
    try corpusRequire(quote.embeds?.count == 1 && quote.author.avatar != nil, "\(path): quote embed and author")
}

private func validateCorpusPost(_ post: AppBskyFeedDefs.PostView, raw: [String: Any], path: String) throws {
    try validateCorpusRecord(post.record, raw: raw["record"] as! [String: Any], path: path + ".record")
    try corpusRequire(post.author.avatar != nil && post.author.associated?.chat != nil && post.author.viewer?.following != nil, "\(path): author fields")
    try corpusRequire(post.viewer?.like != nil && post.labels?.count == (raw["labels"] as! [Any]).count, "\(path): post viewer and labels")
    try corpusRequire((post.embed != nil) == (raw["embed"] != nil), "\(path): view embed retained")
    try corpusRequire((post.debug != nil) == (raw["debug"] != nil), "\(path): dynamic debug retained")
    guard let embed = post.embed else { return }
    let rawEmbed = raw["embed"] as! [String: Any]
    let tag = rawEmbed["$type"] as! String
    switch embed {
    case let .appBskyEmbedImagesView(images):
        try corpusRequire(tag == "app.bsky.embed.images#view" && images.images.count == (rawEmbed["images"] as! [Any]).count, "\(path): image view count")
        try corpusRequire(images.images.allSatisfy { $0.aspectRatio != nil }, "\(path): image ratios")
    case let .appBskyEmbedExternalView(external):
        try corpusRequire(tag == "app.bsky.embed.external#view" && external.external.thumb != nil, "\(path): link card thumbnail")
    case let .appBskyEmbedRecordView(quote):
        try corpusRequire(tag == "app.bsky.embed.record#view", "\(path): quote view tag")
        try validateCorpusQuote(quote, raw: rawEmbed, path: path + ".embed")
    case let .appBskyEmbedRecordWithMediaView(combined):
        try corpusRequire(tag == "app.bsky.embed.recordWithMedia#view", "\(path): quote-with-media tag")
        try validateCorpusQuote(combined.record, raw: rawEmbed["record"] as! [String: Any], path: path + ".embed.record")
        guard case let .appBskyEmbedImagesView(images) = combined.media else {
            throw BenchError.message("Corpus validation: \(path): quote-with-media images lost")
        }
        let rawMedia = rawEmbed["media"] as! [String: Any]
        try corpusRequire(images.images.count == (rawMedia["images"] as! [Any]).count, "\(path): combined image count")
    case let .unexpected(container):
        guard case let .unknownType(actual, .object(properties)) = container,
              tag == "test.example.futureEmbed#view", actual == tag, properties["items"] != nil else {
            throw BenchError.message("Corpus validation: \(path): unknown embed lost")
        }
    default:
        throw BenchError.message("Corpus validation: \(path): unexpected view embed case")
    }
}
