import Foundation
@testable import Petrel
import Testing

// Wire-level tests of the record verbs: each helper is driven through the real
// `NetworkService` against an in-memory PDS, and the exact request it sends is
// asserted.

private let alice = BskyStubServer.alice
private let postCollection = "app.bsky.feed.post"

private func strongRef(_ uri: String, seed: String = "x") throws -> ComAtprotoRepoStrongRef {
    try ComAtprotoRepoStrongRef(
        uri: ATProtocolURI(uriString: uri),
        cid: CIDString(CID.fromDAGCBOR(Data(seed.utf8)))
    )
}

/// The `record` of the only `createRecord` request with its volatile timestamp removed.
private func createdRecord(_ pds: BskyFakePDS, index: Int = 0) throws -> BskyJSON {
    let requests = pds.server.requests(to: "com.atproto.repo.createRecord")
    var record = try #require(requests.count > index ? requests[index].json?["record"] : nil)
    #expect(record["createdAt"]?.stringValue != nil)
    record["createdAt"] = nil
    return record
}

@Suite("BskyAgent posting")
struct BskyAgentPostTests {
    @Test("post sends createRecord for app.bsky.feed.post and returns the new reference")
    func plainPost() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()

        let ref = try await agent.post("Hello from Petrel")

        let request = try #require(pds.server.requests.last)
        #expect(request.method == "POST")
        #expect(request.nsid == "com.atproto.repo.createRecord")
        #expect(request.header("Content-Type") == "application/json")
        #expect(request.header("atproto-proxy") == nil) // repository writes go to the PDS itself
        #expect(request.json?["repo"] == .string(alice))
        #expect(request.json?["collection"] == .string(postCollection))
        #expect(request.json?["rkey"] == nil)
        try expectRecord(createdRecord(pds), ["$type": "app.bsky.feed.post", "text": "Hello from Petrel"])

        #expect(ref.uri.authority == alice)
        #expect(ref.uri.collection == postCollection)
        #expect(pds.record(at: ref.uri.uriString())?.cid == ref.cid.string)
    }

    @Test("post detects links, tags and mentions, resolving handles through the PDS")
    func postWithDetectedFacets() async throws {
        let pds = BskyFakePDS()
        pds.setHandle("bob.test", did: "did:plc:bob")
        let agent = try await pds.server.makeAgent()

        try await agent.post("héllo @bob.test and @ghost.test, see atproto.com #atproto")

        #expect(pds.server.requests(to: "com.atproto.identity.resolveHandle").flatMap { $0.query("handle") }.sorted()
            == ["bob.test", "ghost.test"])
        try expectRecord(createdRecord(pds), [
            "$type": "app.bsky.feed.post",
            "text": "héllo @bob.test and @ghost.test, see atproto.com #atproto",
            "facets": [
                [
                    "index": ["byteStart": 7, "byteEnd": 16],
                    "features": [["$type": "app.bsky.richtext.facet#mention", "did": "did:plc:bob"]],
                ],
                [
                    "index": ["byteStart": 38, "byteEnd": 49],
                    "features": [["$type": "app.bsky.richtext.facet#link", "uri": "https://atproto.com"]],
                ],
                [
                    "index": ["byteStart": 50, "byteEnd": 58],
                    "features": [["$type": "app.bsky.richtext.facet#tag", "tag": "atproto"]],
                ],
            ],
        ])
    }

    @Test("post with RichText sends exactly the given facets and makes no resolution calls")
    func postWithRichText() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        var richText = RichText(text: "")
        richText.append("by ")
        try richText.appendMention("@carol.test", did: DID(didString: "did:plc:carol"))

        try await agent.post(richText, langs: ["en", "pt-BR"], labels: ["graphic-media"], tags: ["birds"])

        #expect(pds.server.requests(to: "com.atproto.identity.resolveHandle").isEmpty)
        try expectRecord(createdRecord(pds), [
            "$type": "app.bsky.feed.post",
            "text": "by @carol.test",
            "facets": [[
                "index": ["byteStart": 3, "byteEnd": 14],
                "features": [["$type": "app.bsky.richtext.facet#mention", "did": "did:plc:carol"]],
            ]],
            "langs": ["en", "pt-BR"],
            "labels": ["$type": "com.atproto.label.defs#selfLabels", "values": [["val": "graphic-media"]]],
            "tags": ["birds"],
        ])
    }

    @Test("post uses the given creation time")
    func postCreatedAt() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        try await agent.post("old news", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let record = try #require(pds.server.requests.last?.json?["record"])
        #expect(record["createdAt"]?.stringValue?.hasPrefix("2023-11-14T22:13:20") == true)
    }

    @Test("post rejects text over the limits before sending anything")
    func postTooLong() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        await #expect(throws: BskyAgentError.self) {
            try await agent.post(RichText(text: String(repeating: "a", count: 301)))
        }
        await #expect(throws: BskyAgentError.self) {
            try await agent.post(RichText(text: "hi"), langs: ["en", "fr", "de", "es"])
        }
        #expect(pds.server.requests.isEmpty)
    }

    @Test("writing without a session throws notAuthenticated and sends nothing")
    func notAuthenticated() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent(did: nil)
        await #expect(throws: BskyAgentError.notAuthenticated) {
            try await agent.post(RichText(text: "hi"))
        }
        await #expect(throws: BskyAgentError.notAuthenticated) {
            try await agent.deletePost(ATProtocolURI(uriString: "at://\(alice)/app.bsky.feed.post/3kabc"))
        }
        #expect(pds.server.requests.isEmpty)
    }

    @Test("a server error surfaces as BskyAgentError.xrpc with the error name and message")
    func serverError() async throws {
        let pds = BskyFakePDS()
        pds.setResponse(.error(400, "InvalidRecord", "Record/text must not be longer than 300 graphemes"), for: "com.atproto.repo.createRecord")
        let agent = try await pds.server.makeAgent()
        await #expect(throws: BskyAgentError.xrpc(
            nsid: "com.atproto.repo.createRecord",
            status: 400,
            error: "InvalidRecord",
            message: "Record/text must not be longer than 300 graphemes"
        )) {
            try await agent.post(RichText(text: "hi"))
        }
    }

    @Test("deletePost sends deleteRecord for the post's repository, collection and key")
    func deletePost() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let ref = try await agent.post(RichText(text: "ephemeral"))
        try await agent.deletePost(ref.uri)

        let request = try #require(pds.server.requests(to: "com.atproto.repo.deleteRecord").first)
        #expect(request.json == [
            "repo": .string(alice),
            "collection": "app.bsky.feed.post",
            "rkey": .string(ref.uri.recordKey ?? ""),
        ])
        #expect(pds.recordURIs.isEmpty)

        // A URI of another collection is refused rather than deleted.
        await #expect(throws: BskyAgentError.self) {
            try await agent.deletePost(ATProtocolURI(uriString: "at://\(alice)/app.bsky.feed.like/3kabc"))
        }
        #expect(pds.server.requests(to: "com.atproto.repo.deleteRecord").count == 1)
    }
}

@Suite("BskyAgent embeds")
struct BskyAgentEmbedTests {
    private func blob(_ mimeType: String = "image/png", size: Int = 1234) throws -> Blob {
        try BskyJSON.object([
            "$type": "blob",
            "ref": ["$link": .string(CID.fromDAGCBOR(Data("blob".utf8)).string)],
            "mimeType": .string(mimeType),
            "size": .integer(size),
        ]).decoded(as: Blob.self)
    }

    private func blobJSON(_ blob: Blob) throws -> BskyJSON {
        try BskyJSON.encoding(blob)
    }

    @Test("uploadBlob sends the bytes untouched with their media type")
    func uploadBlob() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0xFF])

        let blob = try await agent.uploadBlob(png, mimeType: "image/png")

        let request = try #require(pds.server.requests.last)
        #expect(request.method == "POST")
        #expect(request.nsid == "com.atproto.repo.uploadBlob")
        #expect(request.header("Content-Type") == "image/png")
        #expect(request.body == png)
        #expect(blob.mimeType == "image/png")
        #expect(blob.size == png.count)
        #expect(blob.ref != nil)
    }

    @Test("an image post carries alt text and aspect ratio")
    func imagesEmbed() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let image = try blob()

        try await agent.post(RichText(text: "Seen today"), embed: .images([
            .init(image: image, alt: "A petrel over the sea", width: 1600, height: 900),
            .init(image: image, alt: ""),
        ]))

        try expectRecord(createdRecord(pds)["embed"], [
            "$type": "app.bsky.embed.images",
            "images": [
                [
                    "image": blobJSON(image),
                    "alt": "A petrel over the sea",
                    "aspectRatio": ["width": 1600, "height": 900],
                ],
                ["image": blobJSON(image), "alt": ""],
            ],
        ])
    }

    @Test("images embed accepts one to four images")
    func imageCount() throws {
        let image = try AppBskyEmbedImages.Image(image: blob(), alt: "")
        #expect(throws: BskyAgentError.self) { try PostEmbed.images([]) }
        #expect(throws: BskyAgentError.self) { try PostEmbed.images(Array(repeating: image, count: 5)) }
        #expect(try PostEmbed.images(Array(repeating: image, count: 4)).media != nil)
    }

    @Test("an external embed is a link card with an optional thumbnail")
    func externalEmbed() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let thumb = try blob("image/jpeg")

        try await agent.post(RichText(text: "Worth reading"), embed: .external(
            uri: URI(uriString: "https://atproto.com/specs/label"),
            title: "Labels",
            description: "How labels work",
            thumb: thumb
        ))

        try expectRecord(createdRecord(pds)["embed"], [
            "$type": "app.bsky.embed.external",
            "external": [
                "uri": "https://atproto.com/specs/label",
                "title": "Labels",
                "description": "How labels work",
                "thumb": blobJSON(thumb),
            ],
        ])
    }

    @Test("a video embed references the uploaded video blob")
    func videoEmbed() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let video = try blob("video/mp4", size: 9_000_000)

        try await agent.post(RichText(text: "Landing"), embed: .video(
            video,
            alt: "A petrel landing",
            aspectRatio: .init(width: 1920, height: 1080)
        ))

        try expectRecord(createdRecord(pds)["embed"], [
            "$type": "app.bsky.embed.video",
            "video": blobJSON(video),
            "alt": "A petrel landing",
            "aspectRatio": ["width": 1920, "height": 1080],
        ])
    }

    @Test("quote embeds the quoted record, alone or with media")
    func quoteEmbeds() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let quoted = try strongRef("at://did:plc:bob/app.bsky.feed.post/3kquoted")
        let quotedJSON: BskyJSON = ["uri": .string(quoted.uri.uriString()), "cid": .string(quoted.cid.string)]
        let image = try blob()

        try await agent.quote(quoted, "Agreed")
        try expectRecord(createdRecord(pds, index: 0), [
            "$type": "app.bsky.feed.post",
            "text": "Agreed",
            "embed": ["$type": "app.bsky.embed.record", "record": quotedJSON],
        ])

        try await agent.quote(quoted, "With a picture", media: .images([.init(image: image, alt: "chart")]))
        try expectRecord(createdRecord(pds, index: 1)["embed"], [
            "$type": "app.bsky.embed.recordWithMedia",
            "record": ["record": quotedJSON],
            "media": ["$type": "app.bsky.embed.images", "images": [["image": blobJSON(image), "alt": "chart"]]],
        ])
    }

    @Test("threadgate and postgate are written at the post's record key")
    func gates() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let post = try await agent.post(RichText(text: "limited"))
        let rkey = try #require(post.uri.recordKey)

        try await agent.setThreadgate(for: post.uri, allow: [
            .appBskyFeedThreadgateMentionRule(.init()), .appBskyFeedThreadgateFollowingRule(.init()),
        ])
        try await agent.setPostgate(for: post.uri, embeddingRules: [.appBskyFeedPostgateDisableRule(.init())])

        let puts = pds.server.requests(to: "com.atproto.repo.putRecord")
        #expect(puts.map { $0.json?["collection"]?.stringValue } == ["app.bsky.feed.threadgate", "app.bsky.feed.postgate"])
        #expect(puts.allSatisfy { $0.json?["rkey"]?.stringValue == rkey && $0.json?["repo"]?.stringValue == alice })
        #expect(puts[0].json?["record"]?["post"] == .string(post.uri.uriString()))
        expectRecord(puts[0].json?["record"]?["allow"], [
            ["$type": "app.bsky.feed.threadgate#mentionRule"], ["$type": "app.bsky.feed.threadgate#followingRule"],
        ])
        expectRecord(puts[1].json?["record"]?["embeddingRules"], [["$type": "app.bsky.feed.postgate#disableRule"]])
        #expect(puts.allSatisfy { $0.json?["swapRecord"] == .null })
    }

    @Test("changing a threadgate's rules keeps its hidden replies and other fields")
    func threadgateKeepsHiddenReplies() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let post = try await agent.post(RichText(text: "gated"))
        let rkey = try #require(post.uri.recordKey)
        let hidden: BskyJSON = [.string("at://did:plc:bob/app.bsky.feed.post/3khidden")]
        let cid = pds.seed("at://\(alice)/app.bsky.feed.threadgate/\(rkey)", [
            "$type": "app.bsky.feed.threadgate",
            "post": .string(post.uri.uriString()),
            "allow": [["$type": "app.bsky.feed.threadgate#mentionRule"]],
            "hiddenReplies": hidden,
            "createdAt": "2026-01-01T00:00:00.000Z",
            "futureField": ["kept": true],
        ])

        try await agent.setThreadgate(for: post.uri, allow: [.appBskyFeedThreadgateFollowerRule(.init())])

        let put = try #require(pds.server.requests(to: "com.atproto.repo.putRecord").last)
        #expect(put.json?["swapRecord"] == .string(cid))
        expectRecord(put.json?["record"], [
            "$type": "app.bsky.feed.threadgate",
            "post": .string(post.uri.uriString()),
            "allow": [["$type": "app.bsky.feed.threadgate#followerRule"]],
            "hiddenReplies": hidden,
            "createdAt": "2026-01-01T00:00:00.000Z",
            "futureField": ["kept": true],
        ])

        // Opening replies to everyone drops `allow` and still keeps the hidden replies.
        try await agent.setThreadgate(for: post.uri, allow: nil)
        let reopened = try #require(pds.server.requests(to: "com.atproto.repo.putRecord").last)
        #expect(reopened.json?["record"]?["allow"] == nil)
        #expect(reopened.json?["record"]?["hiddenReplies"] == hidden)
    }

    @Test("changing a postgate's rules keeps its detached quotes")
    func postgateKeepsDetachedQuotes() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let post = try await agent.post(RichText(text: "gated"))
        let rkey = try #require(post.uri.recordKey)
        let detached: BskyJSON = [.string("at://did:plc:bob/app.bsky.feed.post/3kquote")]
        let cid = pds.seed("at://\(alice)/app.bsky.feed.postgate/\(rkey)", [
            "$type": "app.bsky.feed.postgate",
            "post": .string(post.uri.uriString()),
            "detachedEmbeddingUris": detached,
            "createdAt": "2026-01-01T00:00:00.000Z",
        ])

        try await agent.setPostgate(for: post.uri, embeddingRules: [.appBskyFeedPostgateDisableRule(.init())])

        let put = try #require(pds.server.requests(to: "com.atproto.repo.putRecord").last)
        #expect(put.json?["swapRecord"] == .string(cid))
        expectRecord(put.json?["record"], [
            "$type": "app.bsky.feed.postgate",
            "post": .string(post.uri.uriString()),
            "embeddingRules": [["$type": "app.bsky.feed.postgate#disableRule"]],
            "detachedEmbeddingUris": detached,
            "createdAt": "2026-01-01T00:00:00.000Z",
        ])
    }
}

@Suite("BskyAgent replies")
struct BskyAgentReplyTests {
    @Test("replying to a top-level post names it as both root and parent")
    func replyToRoot() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let root = try await agent.post(RichText(text: "root"))

        let reply = try await agent.reply(to: root, "first reply")

        let lookup = try #require(pds.server.requests(to: "com.atproto.repo.getRecord").first)
        #expect(lookup.query("repo") == [alice])
        #expect(lookup.query("collection") == [postCollection])
        #expect(lookup.query("rkey") == [root.uri.recordKey ?? ""])
        let rootJSON: BskyJSON = ["uri": .string(root.uri.uriString()), "cid": .string(root.cid.string)]
        expectRecord(pds.record(at: reply.uri.uriString())?.value["reply"], ["root": rootJSON, "parent": rootJSON])
    }

    @Test("replying to a reply carries the thread root over")
    func replyToReply() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let root = try await agent.post(RichText(text: "root"))
        let first = try await agent.reply(to: root, "first")

        let second = try await agent.reply(to: first, "second")

        expectRecord(pds.record(at: second.uri.uriString())?.value["reply"], [
            "root": ["uri": .string(root.uri.uriString()), "cid": .string(root.cid.string)],
            "parent": ["uri": .string(first.uri.uriString()), "cid": .string(first.cid.string)],
        ])
    }

    @Test("replying to a post that does not exist fails without posting")
    func replyToMissing() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let missing = try strongRef("at://did:plc:bob/app.bsky.feed.post/3kmissing")
        await #expect(throws: BskyAgentError.self) {
            try await agent.reply(to: missing, "anyone there?")
        }
        #expect(pds.server.requests(to: "com.atproto.repo.createRecord").isEmpty)
    }

    @Test("replyRef(to: PostView) finds the root without a network call")
    func replyRefFromPostView() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let root = try strongRef("at://did:plc:bob/app.bsky.feed.post/3kroot", seed: "root")
        let parent = try strongRef("at://did:plc:carol/app.bsky.feed.post/3kparent", seed: "parent")

        func postView(_ ref: ComAtprotoRepoStrongRef, reply: BskyJSON?) throws -> AppBskyFeedDefs.PostView {
            var record: BskyJSON = ["$type": "app.bsky.feed.post", "text": "x", "createdAt": "2024-01-01T00:00:00.000Z"]
            record["reply"] = reply
            return try BskyJSON.object([
                "uri": .string(ref.uri.uriString()),
                "cid": .string(ref.cid.string),
                "author": ["did": "did:plc:carol", "handle": "carol.test"],
                "record": record,
                "indexedAt": "2024-01-01T00:00:00.000Z",
            ]).decoded(as: AppBskyFeedDefs.PostView.self)
        }
        let rootJSON: BskyJSON = ["uri": .string(root.uri.uriString()), "cid": .string(root.cid.string)]

        let inThread = try agent.replyRef(to: postView(parent, reply: ["root": rootJSON, "parent": rootJSON]))
        #expect(inThread == AppBskyFeedPost.ReplyRef(root: root, parent: parent))

        let topLevel = try agent.replyRef(to: postView(parent, reply: nil))
        #expect(topLevel == AppBskyFeedPost.ReplyRef(root: parent, parent: parent))
        #expect(pds.server.requests.isEmpty)
    }
}

@Suite("BskyAgent social graph")
struct BskyAgentGraphTests {
    @Test("like, repost, follow and block create their records; the delete forms remove them")
    func createAndDelete() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let post = try strongRef("at://did:plc:bob/app.bsky.feed.post/3kpost")
        let via = try strongRef("at://did:plc:carol/app.bsky.feed.repost/3kvia", seed: "via")
        let bob = try DID(didString: "did:plc:bob")
        let postJSON: BskyJSON = ["uri": .string(post.uri.uriString()), "cid": .string(post.cid.string)]
        let viaJSON: BskyJSON = ["uri": .string(via.uri.uriString()), "cid": .string(via.cid.string)]

        let like = try await agent.like(post, via: via)
        let repost = try await agent.repost(post)
        let follow = try await agent.follow(bob)
        let block = try await agent.block(bob)

        try expectRecord(createdRecord(pds, index: 0), ["$type": "app.bsky.feed.like", "subject": postJSON, "via": viaJSON])
        try expectRecord(createdRecord(pds, index: 1), ["$type": "app.bsky.feed.repost", "subject": postJSON])
        try expectRecord(createdRecord(pds, index: 2), ["$type": "app.bsky.graph.follow", "subject": "did:plc:bob"])
        try expectRecord(createdRecord(pds, index: 3), ["$type": "app.bsky.graph.block", "subject": "did:plc:bob"])
        let creates = pds.server.requests(to: "com.atproto.repo.createRecord")
        #expect(creates.map { $0.json?["collection"]?.stringValue } == [
            "app.bsky.feed.like", "app.bsky.feed.repost", "app.bsky.graph.follow", "app.bsky.graph.block",
        ])
        #expect(creates.allSatisfy { $0.json?["repo"]?.stringValue == alice })
        #expect(pds.recordURIs.count == 4)

        try await agent.deleteLike(like.uri)
        try await agent.deleteRepost(repost.uri)
        try await agent.deleteFollow(follow.uri)
        try await agent.deleteBlock(block.uri)

        let deletes = pds.server.requests(to: "com.atproto.repo.deleteRecord")
        #expect(deletes.map { $0.json?["collection"]?.stringValue } == [
            "app.bsky.feed.like", "app.bsky.feed.repost", "app.bsky.graph.follow", "app.bsky.graph.block",
        ])
        #expect(deletes.map { $0.json?["rkey"]?.stringValue } == [like, repost, follow, block].map(\.uri.recordKey))
        #expect(pds.recordURIs.isEmpty)
    }

    @Test("a delete form refuses a URI of the wrong collection")
    func deleteWrongCollection() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let follow = try ATProtocolURI(uriString: "at://\(alice)/app.bsky.graph.follow/3kfollow")
        await #expect(throws: BskyAgentError.self) { try await agent.deleteLike(follow) }
        await #expect(throws: BskyAgentError.self) { try await agent.deleteRepost(follow) }
        await #expect(throws: BskyAgentError.self) { try await agent.deleteBlock(follow) }
        await #expect(throws: BskyAgentError.self) {
            try await agent.deleteFollow(ATProtocolURI(uriString: "at://\(alice)"))
        }
        #expect(pds.server.requests.isEmpty)
    }

    @Test("mute and unmute call the AppView procedures through the PDS proxy")
    func mutes() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let list = try ATProtocolURI(uriString: "at://did:plc:mod/app.bsky.graph.list/3klist")
        let root = try ATProtocolURI(uriString: "at://did:plc:bob/app.bsky.feed.post/3kroot")

        try await agent.mute(ATIdentifier(string: "did:plc:bob"))
        try await agent.unmute(ATIdentifier(string: "bob.test"))
        try await agent.muteModList(list)
        try await agent.unmuteModList(list)
        try await agent.muteThread(root)
        try await agent.unmuteThread(root)

        let requests = pds.server.requests
        #expect(requests.map(\.nsid) == [
            "app.bsky.graph.muteActor", "app.bsky.graph.unmuteActor",
            "app.bsky.graph.muteActorList", "app.bsky.graph.unmuteActorList",
            "app.bsky.graph.muteThread", "app.bsky.graph.unmuteThread",
        ])
        #expect(requests.map(\.json) == [
            ["actor": "did:plc:bob"], ["actor": "bob.test"],
            ["list": .string(list.uriString())], ["list": .string(list.uriString())],
            ["root": .string(root.uriString())], ["root": .string(root.uriString())],
        ])
        #expect(requests.allSatisfy { $0.method == "POST" })
        #expect(requests.allSatisfy { $0.header("atproto-proxy") == "did:web:api.bsky.app#bsky_appview" })
    }

    @Test("blockModList creates a listblock; unblockModList finds and deletes it")
    func listBlocks() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let list = try ATProtocolURI(uriString: "at://did:plc:mod/app.bsky.graph.list/3klist")

        let block = try await agent.blockModList(list)
        try expectRecord(createdRecord(pds), ["$type": "app.bsky.graph.listblock", "subject": .string(list.uriString())])

        func listResponse(blocked: String?) -> BskyStubResponse {
            var viewer: BskyJSON = [:]
            viewer["blocked"] = blocked.map(BskyJSON.string)
            return .json(["list": ["uri": .string(list.uriString()), "viewer": viewer], "items": []])
        }

        pds.setResponse(listResponse(blocked: block.uri.uriString()), for: "app.bsky.graph.getList")
        #expect(try await agent.unblockModList(list) == true)
        let lookup = try #require(pds.server.requests(to: "app.bsky.graph.getList").first)
        #expect(lookup.query("list") == [list.uriString()])
        #expect(lookup.query("limit") == ["1"])
        #expect(lookup.header("atproto-proxy") == "did:web:api.bsky.app#bsky_appview")
        #expect(pds.recordURIs.isEmpty)

        pds.setResponse(listResponse(blocked: nil), for: "app.bsky.graph.getList")
        #expect(try await agent.unblockModList(list) == false)
        #expect(pds.server.requests(to: "com.atproto.repo.deleteRecord").count == 1)

        // Not a list: refused locally.
        await #expect(throws: BskyAgentError.self) {
            try await agent.blockModList(ATProtocolURI(uriString: "at://did:plc:mod/app.bsky.feed.post/3kpost"))
        }
    }

    @Test("updateSeenNotifications sends the cut-off time")
    func updateSeen() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        try await agent.updateSeenNotifications(seenAt: Date(timeIntervalSince1970: 1_700_000_000))
        let request = try #require(pds.server.requests.last)
        #expect(request.nsid == "app.bsky.notification.updateSeen")
        #expect(request.json?["seenAt"]?.stringValue?.hasPrefix("2023-11-14T22:13:20") == true)
    }
}

@Suite("BskyAgent generic records")
struct BskyAgentGenericRecordTests {
    @Test("createRecord takes the collection from $type and validates an explicit record key")
    func createRecord() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let bob = try DID(didString: "did:plc:bob")
        let follow = AppBskyGraphFollow(subject: bob, createdAt: ATProtocolDate(date: Date()))

        let ref = try await agent.createRecord(follow, rkey: "3kcustomkey", validate: false)
        #expect(ref.uri.uriString() == "at://\(alice)/app.bsky.graph.follow/3kcustomkey")
        let request = try #require(pds.server.requests.last)
        #expect(request.json?["rkey"] == "3kcustomkey")
        #expect(request.json?["validate"] == false)

        await #expect(throws: BskyAgentError.self) {
            try await agent.createRecord(follow, rkey: "not a/key")
        }
        await #expect(throws: BskyAgentError.self) {
            try await agent.createRecord(follow, collection: "not-an-nsid")
        }
        // A value without $type needs an explicit collection.
        await #expect(throws: BskyAgentError.self) {
            try await agent.createRecord(["note": "hello"])
        }
        try await agent.createRecord(["note": "hello"], collection: "com.example.note")
        #expect(pds.server.requests.last?.json?["record"] == ["$type": "com.example.note", "note": "hello"])
    }

    @Test("getRecord decodes a record and returns nil when it does not exist")
    func getRecord() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let ref = try await agent.post(RichText(text: "find me"))

        let found = try #require(try await agent.getRecord(AppBskyFeedPost.self, at: ref.uri))
        #expect(found.value.text == "find me")
        #expect(found.ref == ref)

        let missing = try ATProtocolURI(uriString: "at://\(alice)/app.bsky.feed.post/3knothere")
        #expect(try await agent.getRecord(AppBskyFeedPost.self, at: missing) == nil)
    }

    @Test("putRecord expresses its compare-and-swap condition on the wire")
    func putRecordSwap() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let note: [String: String] = ["note": "v1"]

        let first = try await agent.putRecord(note, collection: "com.example.note", rkey: "self", swapRecord: .mustNotExist)
        #expect(pds.server.requests.last?.json?["swapRecord"] == .null)

        await #expect(throws: BskyAgentError.self) {
            try await agent.putRecord(note, collection: "com.example.note", rkey: "self", swapRecord: .mustNotExist)
        }

        try await agent.putRecord(["note": "v2"], collection: "com.example.note", rkey: "self", swapRecord: .matches(#require(first.cid.cid)))
        #expect(pds.server.requests.last?.json?["swapRecord"] == .string(first.cid.string))

        try await agent.putRecord(["note": "v3"], collection: "com.example.note", rkey: "self")
        #expect(pds.server.requests.last?.json?.objectValue?.keys.contains("swapRecord") == false)
    }
}

@Suite("BskyAgent upsertProfile")
struct BskyAgentProfileTests {
    private let profileURI = "at://\(alice)/app.bsky.actor.profile/self"

    @Test("creates the profile when there is none, guarded against a concurrent create")
    func createsProfile() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()

        try await agent.upsertProfile { existing in
            #expect(existing == nil)
            var profile = ProfileUpdate(existing)
            profile.displayName = "Storm Petrel"
            return profile.record
        }

        let put = try #require(pds.server.requests(to: "com.atproto.repo.putRecord").first)
        expectRecord(put.json, [
            "repo": .string(alice),
            "collection": "app.bsky.actor.profile",
            "rkey": "self",
            "record": ["$type": "app.bsky.actor.profile", "displayName": "Storm Petrel"],
            "swapRecord": nil,
        ])
    }

    @Test("updates the stored profile on the condition that it has not changed")
    func updatesProfile() async throws {
        let pds = BskyFakePDS()
        let cid = pds.seed(profileURI, [
            "$type": "app.bsky.actor.profile",
            "displayName": "Old name",
            "description": "Sea bird",
            "futureField": ["kept": true],
        ])
        let agent = try await pds.server.makeAgent()

        try await agent.upsertProfile { existing in
            #expect(existing?.displayName == "Old name")
            var profile = ProfileUpdate(existing)
            profile.displayName = "New name"
            profile.description = nil
            return profile.record
        }

        let put = try #require(pds.server.requests(to: "com.atproto.repo.putRecord").first)
        #expect(put.json?["swapRecord"] == .string(cid))
        // The changed field is written, the removed one is gone, and the field
        // this SDK does not model is carried over.
        expectRecord(put.json?["record"], [
            "$type": "app.bsky.actor.profile",
            "displayName": "New name",
            "futureField": ["kept": true],
        ])
    }

    @Test("retries with the fresh record when another writer got there first")
    func retriesOnInvalidSwap() async throws {
        let pds = BskyFakePDS()
        pds.seed(profileURI, ["$type": "app.bsky.actor.profile", "displayName": "v1", "description": "bio"])
        let agent = try await pds.server.makeAgent()
        let uri = profileURI
        let interference = BskyTestCounter()
        pds.onBeforePut { pds in
            // Another client rewrites the profile just before our first two writes land.
            if interference.increment() <= 2 {
                pds.seed(uri, ["$type": "app.bsky.actor.profile", "displayName": "v1", "description": "bio edited elsewhere"])
            }
        }
        let seen = BskyTestRecorder()

        try await agent.upsertProfile { existing in
            seen.append(existing?.description ?? "nil")
            var profile = ProfileUpdate(existing)
            profile.displayName = "v2"
            return profile.record
        }

        #expect(seen.values == ["bio", "bio edited elsewhere", "bio edited elsewhere"])
        #expect(pds.server.requests(to: "com.atproto.repo.putRecord").count == 3)
        // The other writer's change survived; ours was applied on top of it.
        expectRecord(pds.record(at: profileURI)?.value, [
            "$type": "app.bsky.actor.profile", "displayName": "v2", "description": "bio edited elsewhere",
        ])
    }

    @Test("gives up with swapRetriesExhausted after six lost races")
    func exhaustsRetries() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let uri = profileURI
        let interference = BskyTestCounter()
        pds.onBeforePut { pds in
            pds.seed(uri, ["$type": "app.bsky.actor.profile", "displayName": .string("other \(interference.increment())")])
        }

        await #expect(throws: BskyAgentError.swapRetriesExhausted(attempts: 6)) {
            try await agent.upsertProfile { ProfileUpdate($0).record }
        }
        #expect(pds.server.requests(to: "com.atproto.repo.putRecord").count == 6)
    }

    @Test("does not treat a failed read as an absent profile")
    func readFailureIsNotAbsence() async throws {
        let pds = BskyFakePDS()
        pds.setResponse(.error(500, "InternalServerError"), for: "com.atproto.repo.getRecord")
        let agent = try await pds.server.makeAgent()
        await #expect(throws: (any Error).self) {
            try await agent.upsertProfile { ProfileUpdate($0).record }
        }
        #expect(pds.server.requests(to: "com.atproto.repo.putRecord").isEmpty)
    }

    @Test("an error thrown by the update closure is propagated and nothing is written")
    func updateThrows() async throws {
        struct Cancelled: Error {}
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        await #expect(throws: Cancelled.self) {
            try await agent.upsertProfile { _ in throw Cancelled() }
        }
        #expect(pds.server.requests(to: "com.atproto.repo.putRecord").isEmpty)
    }
}

final class BskyTestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}

final class BskyTestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    func append(_ value: String) {
        lock.withLock { stored.append(value) }
    }

    var values: [String] {
        lock.withLock { stored }
    }
}
