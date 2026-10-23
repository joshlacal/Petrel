import Foundation
@testable import Petrel
import Testing

@Suite("Query parameter encoding")
struct QueryParametersTests {
    @Test("Language code containers are emitted as scalar query parameters")
    func languageCodeContainerQueryParameter() {
        let parameters = AppBskyFeedSearchPosts.Parameters(
            q: "swift",
            lang: LanguageCodeContainer(languageCode: "en")
        )

        let queryItems = parameters.asQueryItems()

        #expect(queryItems.first(where: { $0.name == "lang" })?.value == "en")
    }

    @Test("Language code arrays emit one query parameter per language")
    func languageCodeContainerArrayQueryParameters() {
        let parameters = AppBskyFeedSearchPostsV2.Parameters(
            query: "swift",
            languages: [
                LanguageCodeContainer(languageCode: "en"),
                LanguageCodeContainer(languageCode: "fr"),
            ]
        )

        let languageValues = parameters.asQueryItems()
            .filter { $0.name == "languages" }
            .compactMap { $0.value }

        #expect(languageValues == ["en", "fr"])
    }

    enum ProtocolVersion: String, Codable, Sendable {
        case one = "1"
        case two = "2"
    }

    /// Shape of generated lexicon parameters such as
    /// `blue.catbird.chat.getConversations.supportedProtocolVersions`.
    struct VersionedParameters: Parametrizable {
        let limit: Int
        let supportedProtocolVersions: [ProtocolVersion]?
    }

    @Test("Optional enum arrays emit one raw value per element")
    func optionalEnumArrayPresent() {
        let items = VersionedParameters(limit: 5, supportedProtocolVersions: [.one, .two]).asQueryItems()
        #expect(items.filter { $0.name == "supportedProtocolVersions" }.map(\.value) == ["1", "2"])
        #expect(items.first(where: { $0.name == "limit" })?.value == "5")
    }

    @Test("Absent and empty optional enum arrays emit no items")
    func optionalEnumArrayNilAndEmpty() {
        for versions in [nil, []] as [[ProtocolVersion]?] {
            let items = VersionedParameters(limit: 5, supportedProtocolVersions: versions).asQueryItems()
            #expect(items.map(\.name) == ["limit"])
        }
    }

    // `asQueryItems()` used to drop a leaf value it had no encoding for without a
    // trace, so getBlob went out with no `cid`. Every leaf type the generator can
    // emit is pinned below, and an unencodable one now stops a debug build.

    static let cidString = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"

    @Test("getBlob sends both did and cid")
    func getBlobQueryParameters() throws {
        let parameters = try ComAtprotoSyncGetBlob.Parameters(
            did: DID(didString: "did:plc:asdf123"),
            cid: CID.parse(Self.cidString)
        )

        #expect(parameters.asQueryItems() == [
            URLQueryItem(name: "did", value: "did:plc:asdf123"),
            URLQueryItem(name: "cid", value: Self.cidString),
        ])
    }

    @Test("Every scalar CID parameter is emitted as its base32 string")
    func scalarCIDQueryParameters() throws {
        let cid = try CID.parse(Self.cidString)
        let did = try DID(didString: "did:plc:asdf123")
        let uri = try ATProtocolURI(uriString: "at://did:plc:asdf123/app.bsky.feed.post/3jzfcijpj2z2a")
        let cases: [(endpoint: String, name: String, items: [URLQueryItem])] = try [
            ("com.atproto.sync.getBlob", "cid", ComAtprotoSyncGetBlob.Parameters(did: did, cid: cid).asQueryItems()),
            ("com.atproto.space.getBlob", "cid", ComAtprotoSpaceGetBlob.Parameters(
                space: SpaceRef(uriString: "at://did:plc:asdf123/space/com.example.group/default"),
                repo: did,
                cid: cid
            ).asQueryItems()),
            ("com.atproto.repo.getRecord", "cid", ComAtprotoRepoGetRecord.Parameters(
                repo: ATIdentifier(string: "did:plc:asdf123"),
                collection: NSID(nsidString: "app.bsky.feed.post"),
                rkey: RecordKey(keyString: "3jzfcijpj2z2a"),
                cid: cid
            ).asQueryItems()),
            ("app.bsky.feed.getLikes", "cid", AppBskyFeedGetLikes.Parameters(uri: uri, cid: cid).asQueryItems()),
            ("app.bsky.feed.getQuotes", "cid", AppBskyFeedGetQuotes.Parameters(uri: uri, cid: cid).asQueryItems()),
            ("app.bsky.feed.getRepostedBy", "cid", AppBskyFeedGetRepostedBy.Parameters(uri: uri, cid: cid).asQueryItems()),
            ("com.atproto.admin.getSubjectStatus", "blob", ComAtprotoAdminGetSubjectStatus.Parameters(blob: cid).asQueryItems()),
        ]

        for (endpoint, name, items) in cases {
            #expect(items.filter { $0.name == name }.map(\.value) == [Self.cidString], "\(endpoint).\(name)")
        }
    }

    @Test("Every datetime parameter is emitted as its ISO-8601 wire string")
    func datetimeQueryParameters() throws {
        let wire = "2026-10-01T12:34:56.789Z"
        let date = try #require(ATProtocolDate(iso8601String: wire))
        let handle = try Handle(handleString: "alice.bsky.social")
        let cases: [(endpoint: String, name: String, items: [URLQueryItem])] = [
            ("app.bsky.notification.getUnreadCount", "seenAt", AppBskyNotificationGetUnreadCount.Parameters(seenAt: date).asQueryItems()),
            ("app.bsky.notification.listNotifications", "seenAt", AppBskyNotificationListNotifications.Parameters(seenAt: date).asQueryItems()),
            ("com.atproto.temp.checkHandleAvailability", "birthDate", ComAtprotoTempCheckHandleAvailability.Parameters(handle: handle, birthDate: date).asQueryItems()),
        ]

        for (endpoint, name, items) in cases {
            #expect(items.filter { $0.name == name }.map(\.value) == [wire], "\(endpoint).\(name)")
        }
    }

    /// One field per Swift type the generator may emit for a query parameter
    /// (`QUERY_ENCODABLE_SWIFT_TYPES` in generator/swift_code_generator.py), plus a
    /// closed string enum. Keep the two lists in step.
    struct EveryLeafParameters: Parametrizable {
        let string: String
        let int: Int
        let bool: Bool
        let cid: CID
        let datetime: ATProtocolDate
        let uri: URI
        let atUri: ATProtocolURI
        let space: SpaceRef
        let actor: ATIdentifier
        let did: DID
        let handle: Handle
        let nsid: NSID
        let tid: TID
        let rkey: RecordKey
        let lang: LanguageCodeContainer
        let version: ProtocolVersion
    }

    @Test("Every leaf type the generator can emit becomes exactly one query item")
    func everyGeneratableLeafTypeIsEncoded() throws {
        let parameters = try EveryLeafParameters(
            string: "swift",
            int: 25,
            bool: false,
            cid: CID.parse(Self.cidString),
            datetime: #require(ATProtocolDate(iso8601String: "2026-10-01T12:34:56.789Z")),
            uri: URI(uriString: "https://example.com/page"),
            atUri: ATProtocolURI(uriString: "at://did:plc:asdf123/app.bsky.feed.post/3jzfcijpj2z2a"),
            space: SpaceRef(uriString: "at://did:plc:asdf123/space/com.example.group/default"),
            actor: ATIdentifier(string: "alice.bsky.social"),
            did: DID(didString: "did:plc:asdf123"),
            handle: Handle(handleString: "alice.bsky.social"),
            nsid: NSID(nsidString: "app.bsky.feed.post"),
            tid: TID(tidString: "3jzfcijpj2z2a"),
            rkey: RecordKey(keyString: "self"),
            lang: LanguageCodeContainer(languageCode: "en"),
            version: .two
        )

        #expect(parameters.asQueryItems() == [
            URLQueryItem(name: "string", value: "swift"),
            URLQueryItem(name: "int", value: "25"),
            URLQueryItem(name: "bool", value: "false"),
            URLQueryItem(name: "cid", value: Self.cidString),
            URLQueryItem(name: "datetime", value: "2026-10-01T12:34:56.789Z"),
            URLQueryItem(name: "uri", value: "https://example.com/page"),
            URLQueryItem(name: "atUri", value: "at://did:plc:asdf123/app.bsky.feed.post/3jzfcijpj2z2a"),
            URLQueryItem(name: "space", value: "at://did:plc:asdf123/space/com.example.group/default"),
            URLQueryItem(name: "actor", value: "alice.bsky.social"),
            URLQueryItem(name: "did", value: "did:plc:asdf123"),
            URLQueryItem(name: "handle", value: "alice.bsky.social"),
            URLQueryItem(name: "nsid", value: "app.bsky.feed.post"),
            URLQueryItem(name: "tid", value: "3jzfcijpj2z2a"),
            URLQueryItem(name: "rkey", value: "self"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "version", value: "2"),
        ])
    }

    // Exit tests (`processExitsWith:`) arrived in Swift 6.2; the minimum CI lanes run 6.1.
    #if compiler(>=6.2) && DEBUG && (os(macOS) || os(Linux))
        @Test("An unencodable leaf stops a debug build instead of leaving the request")
        func unencodableLeafTrapsInDebug() async {
            await #expect(processExitsWith: .failure) {
                _ = UnencodableLeafParameters(leaf: UnencodableLeaf()).asQueryItems()
            }
        }

        @Test("An unencodable array element stops a debug build instead of being sent as its description")
        func unencodableArrayElementTrapsInDebug() async {
            await #expect(processExitsWith: .failure) {
                _ = UnencodableArrayParameters(leaves: [UnencodableLeaf()]).asQueryItems()
            }
        }
    #endif
}

/// A value type `asQueryItems()` has no encoding for.
private struct UnencodableLeaf: Sendable {}

private struct UnencodableLeafParameters: Parametrizable {
    let leaf: UnencodableLeaf
}

private struct UnencodableArrayParameters: Parametrizable {
    let leaves: [UnencodableLeaf]
}
