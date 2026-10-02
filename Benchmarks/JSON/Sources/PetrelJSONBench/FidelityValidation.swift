import Foundation
import Petrel

/// Corpus validator for `fidelity-edge-feed`.
///
/// Expectations are those of wire-preserving URI decoding plus lossless legacy-blob
/// decoding: a post record is demoted to `unknownType` only when it carries a
/// whitespace-padded URI (decoding trims it, so the typed re-encode cannot match the
/// wire), every typed URI re-encodes as its trimmed wire text, `URI.url` resolves that
/// text, and legacy `{cid, mimeType}` blobs re-encode in that shape. A library without
/// those fixes fails this validator by design; the failure lists every divergence.
func validateFidelityEdge(_ fixture: Fixture, _ model: AppBskyFeedGetTimeline.Output, _ root: [String: Any]) throws -> String {
    let name = fixture.entry.id
    let feed = root["feed"] as! [[String: Any]]
    let counts = fixture.entry.expectedTopLevelCounts ?? [:]
    guard model.feed.count == feed.count, counts["feed"] == feed.count else {
        throw BenchError.message("Corpus validation: \(name): feed count")
    }
    var audit = FidelityAudit()
    var known = 0, unknown = 0
    for (index, item) in model.feed.enumerated() {
        let rawItem = feed[index]
        let rawPost = rawItem["post"] as! [String: Any]
        let path = "\(name)[\(index)]"
        if audit.record(item.post.record, raw: rawPost["record"] as! [String: Any], path: path + ".post.record") {
            known += 1
        } else {
            unknown += 1
        }
        if case let .appBskyEmbedExternalView(view)? = item.post.embed {
            let rawEmbed = rawPost["embed"] as! [String: Any]
            let rawURI = (rawEmbed["external"] as! [String: Any])["uri"] as! String
            audit.uri(view.external.uri, raw: rawURI, path: path + ".post.embed.external.uri")
        }
        if let reply = item.reply, let rawReply = rawItem["reply"] as? [String: Any] {
            var views: [(String, AppBskyFeedDefs.PostView?)] = []
            if case let .appBskyFeedDefsPostView(view) = reply.root { views.append(("root", view)) } else { views.append(("root", nil)) }
            if case let .appBskyFeedDefsPostView(view) = reply.parent { views.append(("parent", view)) } else { views.append(("parent", nil)) }
            for (key, candidate) in views {
                guard let view = candidate else {
                    audit.problems.append("\(path).reply.\(key): lost typed post view")
                    continue
                }
                let rawView = rawReply[key] as! [String: Any]
                _ = audit.record(view.record, raw: rawView["record"] as! [String: Any], path: "\(path).reply.\(key).record")
            }
        }
    }
    if known != counts["knownPostRecords"] || unknown != counts["unknownPostRecords"] {
        audit.problems.append("\(name): typed/unknown top-level records \(known)/\(unknown), manifest expects \(counts["knownPostRecords"] ?? -1)/\(counts["unknownPostRecords"] ?? -1)")
    }
    guard audit.problems.isEmpty else {
        throw BenchError.message("Corpus validation: \(name): \(audit.problems.count) fidelity problems: " + audit.problems.prefix(16).joined(separator: " | "))
    }
    return "\(name): \(feed.count) feed entries, \(known) typed / \(unknown) unknown top-level records (unknown only for whitespace-padded URIs), \(audit.uris) typed URIs equal their trimmed wire text and URL, \(audit.legacyBlobs) legacy blobs re-encode as {cid, mimeType}"
}

/// True when the raw record carries a link-facet or link-card URI with surrounding whitespace.
func rawRecordHasPaddedURI(_ raw: [String: Any]) -> Bool {
    var uris: [String] = []
    for facet in raw["facets"] as? [[String: Any]] ?? [] {
        for feature in facet["features"] as? [[String: Any]] ?? [] {
            if let uri = feature["uri"] as? String { uris.append(uri) }
        }
    }
    if let embed = raw["embed"] as? [String: Any], embed["$type"] as? String == "app.bsky.embed.external",
       let uri = (embed["external"] as? [String: Any])?["uri"] as? String {
        uris.append(uri)
    }
    return uris.contains { $0 != $0.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct FidelityAudit {
    var problems: [String] = []
    var uris = 0
    var legacyBlobs = 0

    /// Returns true when the record decoded as a typed post.
    mutating func record(_ container: ATProtocolValueContainer, raw: [String: Any], path: String) -> Bool {
        let expectUnknown = rawRecordHasPaddedURI(raw)
        guard case let .knownType(value) = container, let post = value as? AppBskyFeedPost else {
            if !expectUnknown { problems.append("\(path): demoted to unknownType") }
            return false
        }
        if expectUnknown { problems.append("\(path): padded URI record unexpectedly typed") }
        let rawFacets = raw["facets"] as? [[String: Any]] ?? []
        for (facetIndex, facet) in (post.facets ?? []).enumerated() {
            let rawFeatures = rawFacets[facetIndex]["features"] as! [[String: Any]]
            for (featureIndex, feature) in facet.features.enumerated() {
                if case let .appBskyRichtextFacetLink(link) = feature {
                    uri(link.uri, raw: rawFeatures[featureIndex]["uri"] as! String, path: "\(path).facets[\(facetIndex)].uri")
                }
            }
        }
        let rawEmbed = raw["embed"] as? [String: Any]
        switch post.embed {
        case let .appBskyEmbedExternal(external)?:
            uri(external.external.uri, raw: (rawEmbed!["external"] as! [String: Any])["uri"] as! String, path: path + ".embed.external.uri")
        case let .appBskyEmbedImages(images)?:
            blobs(images, raw: rawEmbed!, path: path + ".embed")
        case let .appBskyEmbedRecordWithMedia(combined)?:
            if case let .appBskyEmbedImages(images) = combined.media {
                blobs(images, raw: rawEmbed!["media"] as! [String: Any], path: path + ".embed.media")
            }
        default:
            break
        }
        return true
    }

    mutating func uri(_ value: URI, raw: String, path: String) {
        uris += 1
        let wire = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.uriString() != wire {
            problems.append("\(path): re-encodes \(value.uriString().debugDescription), wire \(wire.debugDescription)")
        }
        if value.url?.absoluteString != URL(string: wire)?.absoluteString {
            problems.append("\(path): url \(value.url?.absoluteString.debugDescription ?? "nil"), expected \(URL(string: wire)?.absoluteString.debugDescription ?? "nil")")
        }
    }

    mutating func blobs(_ images: AppBskyEmbedImages, raw: [String: Any], path: String) {
        let rawImages = raw["images"] as! [[String: Any]]
        for (index, image) in images.images.enumerated() {
            let rawBlob = rawImages[index]["image"] as! [String: Any]
            guard rawBlob["$type"] == nil else { continue }
            legacyBlobs += 1
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let reencoded = (try? encoder.encode(image.image)).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? NSDictionary
            if reencoded != rawBlob as NSDictionary {
                problems.append("\(path).images[\(index)].image: legacy blob re-encodes as \(reencoded.map { "\($0)" } ?? "nil")")
            }
        }
    }
}
