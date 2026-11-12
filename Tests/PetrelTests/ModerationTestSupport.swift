import Foundation
@testable import Petrel
import Testing

// Test support for the moderation suites: Swift counterparts of
// `@atproto/api`'s `src/mocker.ts` and `tests/util/moderation-behavior.ts`.
//
// Views are assembled as JSON objects and decoded through the generated types,
// so the suites exercise the same decoding path as responses from an AppView.

typealias JSONObject = [String: Any]

enum ModerationMock {
    static let fakeCID = "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq"
    static let timestamp = "2024-01-01T00:00:00.000Z"
    static let fakeLabeler = "did:plc:fake-labeler"

    static func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(type, from: data)
    }

    static func decode<T: Decodable>(_ object: Any) throws -> T {
        try decode(T.self, object)
    }

    static func did(_ string: String) throws -> DID {
        try DID(didString: string)
    }

    /// `mock.post`: an `app.bsky.feed.post` record.
    static func post(
        text: String,
        facets: [JSONObject]? = nil,
        embed: JSONObject? = nil,
        langs: [String]? = ["en"]
    ) -> JSONObject {
        var record: JSONObject = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": timestamp,
        ]
        if let facets { record["facets"] = facets }
        if let embed { record["embed"] = embed }
        if let langs { record["langs"] = langs }
        return record
    }

    /// `mock.profileViewBasic`.
    static func profile(
        handle: String,
        displayName: String? = nil,
        viewer: JSONObject? = nil,
        labels: [JSONObject]? = nil
    ) -> JSONObject {
        var profile: JSONObject = [
            "did": "did:web:\(handle)",
            "handle": handle,
        ]
        if let displayName { profile["displayName"] = displayName }
        if let viewer { profile["viewer"] = viewer }
        if let labels { profile["labels"] = labels }
        return profile
    }

    static func profileViewBasic(
        handle: String,
        displayName: String? = nil,
        viewer: JSONObject? = nil,
        labels: [JSONObject]? = nil
    ) throws -> AppBskyActorDefs.ProfileViewBasic {
        try decode(profile(handle: handle, displayName: displayName, viewer: viewer, labels: labels))
    }

    /// `mock.postView`.
    static func postView(
        record: JSONObject,
        author: JSONObject,
        embed: JSONObject? = nil,
        labels: [JSONObject]? = nil
    ) throws -> AppBskyFeedDefs.PostView {
        var view: JSONObject = [
            "$type": "app.bsky.feed.defs#postView",
            "uri": "at://\(author["did"] as? String ?? "")/app.bsky.feed.post/fake",
            "cid": fakeCID,
            "author": author,
            "record": record,
            "indexedAt": timestamp,
        ]
        if let embed { view["embed"] = embed }
        if let labels { view["labels"] = labels }
        return try decode(view)
    }

    /// `mock.embedRecordView`: an `app.bsky.embed.record#view` quoting a post.
    static func embedRecordView(
        record: JSONObject,
        author: JSONObject,
        labels: [JSONObject]? = nil
    ) -> JSONObject {
        var viewRecord: JSONObject = [
            "$type": "app.bsky.embed.record#viewRecord",
            "uri": "at://\(author["did"] as? String ?? "")/app.bsky.feed.post/fake",
            "cid": fakeCID,
            "author": author,
            "value": record,
            "indexedAt": timestamp,
        ]
        if let labels { viewRecord["labels"] = labels }
        return [
            "$type": "app.bsky.embed.record#view",
            "record": viewRecord,
        ]
    }

    /// `mock.listViewBasic`.
    static func listViewBasic(name: String) -> JSONObject {
        [
            "uri": "at://did:plc:fake/app.bsky.graph.list/fake",
            "cid": fakeCID,
            "name": name,
            "purpose": "app.bsky.graph.defs#modlist",
            "indexedAt": timestamp,
        ]
    }

    /// `mock.label`.
    static func label(val: String, uri: String, src: String = fakeLabeler) -> JSONObject {
        [
            "src": src,
            "uri": uri,
            "val": val,
            "cts": timestamp,
        ]
    }

    static func blob() -> JSONObject {
        [
            "$type": "blob",
            "ref": ["$link": fakeCID],
            "mimeType": "image/jpeg",
            "size": 1234,
        ]
    }

    /// A muted word preference, as the tests in `moderation-mutewords.test.ts` write them.
    static func mutedWord(
        _ value: String,
        targets: [String] = ["content"],
        actorTarget: String? = "all",
        expiresAt: Date? = nil
    ) -> AppBskyActorDefs.MutedWord {
        AppBskyActorDefs.MutedWord(
            value: value,
            targets: targets.map { AppBskyActorDefs.MutedWordTarget(rawValue: $0) },
            actorTarget: actorTarget,
            expiresAt: expiresAt.map { ATProtocolDate(date: $0) }
        )
    }

    /// Tag facets for every `#tag` in `text`. Stands in for
    /// `RichText.detectFacetsWithoutResolution()` in the reference tests, which
    /// only need the tags; the inputs used here are plain ASCII tags.
    static func tagFacets(in text: String) -> [AppBskyRichtextFacet] {
        var facets: [AppBskyRichtextFacet] = []
        let bytes = Array(text.utf8)
        var index = 0
        while index < bytes.count {
            let startsWord = index == 0 || bytes[index - 1] == 0x20 || bytes[index - 1] == 0x0A
            if bytes[index] == 0x23, startsWord {
                var end = index + 1
                while end < bytes.count, isTagByte(bytes[end]) {
                    end += 1
                }
                if end > index + 1, let tag = String(bytes: bytes[(index + 1) ..< end], encoding: .utf8) {
                    facets.append(
                        AppBskyRichtextFacet(
                            index: AppBskyRichtextFacet.ByteSlice(byteStart: index, byteEnd: end),
                            features: [.appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: tag))]
                        )
                    )
                }
                index = end
            } else {
                index += 1
            }
        }
        return facets
    }

    private static func isTagByte(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }
}

// MARK: - Vectors

enum ModerationVectors {
    static func url(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Vectors/moderation"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url(name)))
    }
}

/// The eight UI contexts with the flags a scenario expects in each.
struct ExpectedBehaviors: Decodable, Sendable {
    var profileList: [String]?
    var profileView: [String]?
    var avatar: [String]?
    var banner: [String]?
    var displayName: [String]?
    var contentList: [String]?
    var contentView: [String]?
    var contentMedia: [String]?

    subscript(context: ModerationBehavior.Context) -> [String]? {
        switch context {
        case .profileList: return profileList
        case .profileView: return profileView
        case .avatar: return avatar
        case .banner: return banner
        case .displayName: return displayName
        case .contentList: return contentList
        case .contentView: return contentView
        case .contentMedia: return contentMedia
        }
    }
}

/// `toBeModerationResult`: every one of filter / blur / alert / inform /
/// noOverride must be set exactly when it is listed in `expected`. `nil` and
/// `[]` both mean "no moderation at all".
func expectModerationResult(
    _ ui: ModerationUI,
    _ expected: [String]?,
    _ context: String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let expected = Set(expected ?? [])
    let unknown = expected.subtracting(["filter", "blur", "alert", "inform", "noOverride"])
    #expect(unknown.isEmpty, "\(context): unknown expected flags \(unknown)", sourceLocation: sourceLocation)
    #expect(ui.inform == expected.contains("inform"), "\(context): inform", sourceLocation: sourceLocation)
    #expect(ui.alert == expected.contains("alert"), "\(context): alert", sourceLocation: sourceLocation)
    #expect(ui.blur == expected.contains("blur"), "\(context): blur", sourceLocation: sourceLocation)
    #expect(ui.filter == expected.contains("filter"), "\(context): filter", sourceLocation: sourceLocation)
    #expect(
        ui.noOverride == expected.contains("noOverride"),
        "\(context): noOverride",
        sourceLocation: sourceLocation
    )
}

/// Checks all eight contexts of a decision against the expected flags.
func expectModerationResults(
    _ decision: ModerationDecision,
    _ expected: ExpectedBehaviors,
    _ name: String = "",
    contexts: [ModerationBehavior.Context] = ModerationBehavior.Context.allCases,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for context in contexts {
        expectModerationResult(
            decision.ui(context),
            expected[context],
            "\(name) [\(context.rawValue)]",
            sourceLocation: sourceLocation
        )
    }
}
