import Foundation
import Petrel
import SwiftCBOR
import Testing

// The code examples of the Bluesky documentation articles
// (Sources/Petrel/Petrel.docc/Bluesky*.md), compiled and run.
//
// Each `example…` function body is the snippet shown in the article. This file
// imports Petrel without `@testable`, so the examples can only use what an app
// can. They run against an in-memory PDS; `bsky` stands for `client.bsky`.

@Suite("Bluesky documentation examples")
struct BskyDocumentationExampleTests {
    // MARK: BlueskyPosting.md

    func examplePost(bsky: BskyAgent) async throws -> ComAtprotoRepoStrongRef {
        // Links, mentions and hashtags in the text become facets automatically.
        let post = try await bsky.post("Reading https://atproto.com with @alice.bsky.social #atproto")
        return post
    }

    @Test("Posting: text with detected facets")
    func post() async throws {
        let pds = BskyFakePDS()
        pds.setHandle("alice.bsky.social", did: "did:plc:alice")
        let post = try await examplePost(bsky: pds.server.makeAgent(did: "did:plc:me"))

        #expect(post.uri.collection == "app.bsky.feed.post")
        let stored = try #require(try await pds.server.makeAgent().getRecord(AppBskyFeedPost.self, at: post.uri))
        #expect(stored.value.text == "Reading https://atproto.com with @alice.bsky.social #atproto")
        let richText = RichText(post: stored.value)
        #expect(richText.segments().compactMap { $0.link?.uri.uriString() } == ["https://atproto.com"])
        #expect(richText.segments().compactMap { $0.mention?.did.didString() } == ["did:plc:alice"])
        #expect(richText.segments().compactMap { $0.tag?.tag } == ["atproto"])
    }

    func exampleRichText(bsky: BskyAgent) async throws -> [String] {
        var text = RichText(text: "The label spec: https://atproto.com/specs/label #moderation")
        text.detectFacetsWithoutResolution()

        // Check the length the way the network does: graphemes, not characters or bytes.
        guard !text.exceedsPostLimits else { return [] }
        try await bsky.post(text, langs: ["en"])

        // Render it: one run per segment, links shortened for display only.
        var rendered: [String] = []
        for segment in text.shorteningLinks().segments() {
            if let link = segment.link {
                rendered.append("[\(segment.text)](\(link.uri.uriString()))")
            } else if let tag = segment.tag {
                rendered.append("<tag \(tag.tag)>")
            } else {
                rendered.append(segment.text)
            }
        }
        return rendered
    }

    @Test("Posting: build, check and render rich text")
    func richText() async throws {
        let pds = BskyFakePDS()
        let rendered = try await exampleRichText(bsky: pds.server.makeAgent())
        #expect(rendered == [
            "The label spec: ",
            "[atproto.com/specs/label](https://atproto.com/specs/label)",
            " ",
            "<tag moderation>",
        ])
        #expect(pds.calledMethods == ["com.atproto.repo.createRecord"])
    }

    func exampleReplyAndQuote(bsky: BskyAgent, post: ComAtprotoRepoStrongRef) async throws {
        // A reply names its parent and the root of the thread; reply(to:)
        // reads the parent once to find the root.
        let reply = try await bsky.reply(to: post, "Thanks for sharing")
        try await bsky.reply(to: reply, "And one more thing")

        // A quote post embeds the quoted post.
        try await bsky.quote(post, "Worth a read")
    }

    @Test("Posting: reply and quote")
    func replyAndQuote() async throws {
        let pds = BskyFakePDS()
        let bsky = try await pds.server.makeAgent()
        let root = try await bsky.post(RichText(text: "root"))
        try await exampleReplyAndQuote(bsky: bsky, post: root)

        let posts = pds.recordURIs.sorted()
        #expect(posts.count == 4)
        let second = try #require(try await bsky.getRecord(AppBskyFeedPost.self, at: ATProtocolURI(uriString: posts[2])))
        #expect(second.value.text == "And one more thing")
        #expect(second.value.reply?.root == root)
        #expect(second.value.reply?.parent.uri.uriString() == posts[1])
        let quote = try #require(try await bsky.getRecord(AppBskyFeedPost.self, at: ATProtocolURI(uriString: posts[3])))
        #expect(quote.value.embed == .appBskyEmbedRecord(AppBskyEmbedRecord(record: root)))
    }

    func exampleImages(bsky: BskyAgent, imageData: Data) async throws {
        // Upload and embed in one step. Location and other metadata are
        // removed from the file before it is sent.
        try await bsky.post("Seen today", images: [
            PostImage(
                data: imageData,
                mimeType: "image/jpeg",
                alt: "A storm petrel skimming the waves",
                width: 1600,
                height: 900
            ),
        ])

        // Or upload first and build the embed yourself.
        let blob = try await bsky.uploadImage(imageData, mimeType: "image/jpeg")
        try await bsky.post("Seen today", embed: .images([.init(image: blob, alt: "The same petrel")]))

        // A link card instead of an image:
        try await bsky.post("Background reading", embed: .external(
            uri: URI(uriString: "https://atproto.com/specs/label"),
            title: "Labels",
            description: "How moderation labels work in the AT Protocol"
        ))
    }

    @Test("Posting: images and link cards")
    func images() async throws {
        let pds = BskyFakePDS()
        let bsky = try await pds.server.makeAgent()
        // A small real JPEG with a comment block standing in for camera metadata.
        let jpeg = try #require(Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAAQABADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAABQb/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGbXSXP/8QAFRABAQAAAAAAAAAAAAAAAAAAAwD/2gAIAQEAAQUCMIwjCML/xAAVEQEBAAAAAAAAAAAAAAAAAAAEAP/aAAgBAwEBPwED7//EABURAQEAAAAAAAAAAAAAAAAAAAIA/9oACAECAQE/ASr/xAAUEAEAAAAAAAAAAAAAAAAAAAAg/9oACAEBAAY/Ah//xAAVEAEBAAAAAAAAAAAAAAAAAAAAYf/aAAgBAQABPyGKKKL/2gAMAwEAAgADAAAAEAP/xAAWEQADAAAAAAAAAAAAAAAAAAAAITH/2gAIAQMBAT8Qgz//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAWEAEBAQAAAAAAAAAAAAAAAAAAMcH/2gAIAQEAAT8QmzynlN//2Q=="))
        let comment = Data([0xFF, 0xFE, 0x00, 0x0E]) + Data("shot-at-home".utf8)
        let photo = jpeg.prefix(20) + comment + jpeg.dropFirst(20)

        try await exampleImages(bsky: bsky, imageData: photo)

        #expect(pds.calledMethods == [
            "com.atproto.repo.uploadBlob", "com.atproto.repo.createRecord",
            "com.atproto.repo.uploadBlob", "com.atproto.repo.createRecord",
            "com.atproto.repo.createRecord",
        ])
        let first = try #require(try await bsky.getRecord(AppBskyFeedPost.self, at: ATProtocolURI(uriString: pds.recordURIs[0])))
        guard case let .appBskyEmbedImages(images) = first.value.embed else {
            Issue.record("expected an images embed")
            return
        }
        #expect(images.images.first?.alt == "A storm petrel skimming the waves")
        #expect(images.images.first?.aspectRatio == AppBskyEmbedDefs.AspectRatio(width: 1600, height: 900))
        #expect(images.images.first?.image.mimeType == "image/jpeg")
        // The uploaded file is the clean JPEG: the comment block is gone.
        #expect(images.images.first?.image.size == jpeg.count)
    }

    func exampleSocialGraph(bsky: BskyAgent, post: ComAtprotoRepoStrongRef, author: DID) async throws {
        // Each verb returns the record it created. Keep the URI to undo it.
        let like = try await bsky.like(post)
        let repost = try await bsky.repost(post)
        let follow = try await bsky.follow(author)

        try await bsky.deleteLike(like.uri)
        try await bsky.deleteRepost(repost.uri)
        try await bsky.deleteFollow(follow.uri)

        // Mutes are private and live on the AppView; blocks are public records.
        try await bsky.mute(ATIdentifier(string: "spammer.bsky.social"))
        let block = try await bsky.block(author)
        try await bsky.deleteBlock(block.uri)
    }

    @Test("Social graph: like, repost, follow, mute, block and their undo forms")
    func socialGraph() async throws {
        let pds = BskyFakePDS()
        let bsky = try await pds.server.makeAgent()
        let post = try ComAtprotoRepoStrongRef(
            uri: ATProtocolURI(uriString: "at://did:plc:bob/app.bsky.feed.post/3kpost"),
            cid: CIDString(CID.fromDAGCBOR(Data("post".utf8)))
        )
        try await exampleSocialGraph(bsky: bsky, post: post, author: DID(didString: "did:plc:bob"))

        #expect(pds.calledMethods == [
            "com.atproto.repo.createRecord", "com.atproto.repo.createRecord", "com.atproto.repo.createRecord",
            "com.atproto.repo.deleteRecord", "com.atproto.repo.deleteRecord", "com.atproto.repo.deleteRecord",
            "app.bsky.graph.muteActor",
            "com.atproto.repo.createRecord", "com.atproto.repo.deleteRecord",
        ])
        #expect(pds.recordURIs.isEmpty)
    }

    func exampleProfile(bsky: BskyAgent) async throws {
        // Read-modify-write: the closure receives the stored profile and
        // returns the new one. It runs again if another client wrote first.
        try await bsky.upsertProfile { existing in
            var profile = ProfileUpdate(existing)
            profile.displayName = "Storm Petrel"
            profile.description = "Pelagic. Posts from the open sea."
            return profile.record
        }
    }

    @Test("Profile: upsert keeps the fields it does not change")
    func profile() async throws {
        let pds = BskyFakePDS()
        let uri = "at://did:plc:alice/app.bsky.actor.profile/self"
        try pds.seedJSON(uri, #"{"$type":"app.bsky.actor.profile","displayName":"Old","pronouns":"they/them"}"#)
        try await exampleProfile(bsky: pds.server.makeAgent())

        #expect(pds.recordField("displayName", at: uri) == "Storm Petrel")
        #expect(pds.recordField("description", at: uri) == "Pelagic. Posts from the open sea.")
        #expect(pds.recordField("pronouns", at: uri) == "they/them")
    }

    // MARK: BlueskyModeration.md

    func exampleModerationOptions(bsky: BskyAgent, post: AppBskyFeedDefs.PostView) async throws -> String {
        // The user's DID, moderation preferences and their labelers' label
        // definitions. Fetch once and reuse until preferences change.
        let options = try await bsky.moderationOptions()

        let decision = Moderation.moderatePost(post, options: options)
        let inFeed = decision.ui(.contentList)
        if inFeed.filter {
            return "leave it out of the feed"
        } else if inFeed.blur {
            return inFeed.noOverride ? "cover it for good" : "cover it behind a Show button"
        } else if inFeed.alert || inFeed.inform {
            return "show it with a notice"
        }
        return "show it"
    }

    @Test("Moderation: options from the account, decision for a feed")
    func moderationOptions() async throws {
        let pds = BskyFakePDS()
        try pds.setPreferencesJSON(#"""
        [
          {"$type": "app.bsky.actor.defs#savedFeedsPrefV2", "items": []},
          {"$type": "app.bsky.actor.defs#mutedWordsPref", "items": [
            {"id": "3kmute", "value": "spoilers", "targets": ["content"], "actorTarget": "all"}
          ]}
        ]
        """#)
        try pds.setResponseJSON(#"{"views": []}"#, for: "app.bsky.labeler.getServices")
        let post = try JSONDecoder().decode(AppBskyFeedDefs.PostView.self, from: Data(#"""
        {
          "uri": "at://did:plc:bob/app.bsky.feed.post/3kpost",
          "cid": "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq",
          "author": {"did": "did:plc:bob", "handle": "bob.bsky.social"},
          "record": {"$type": "app.bsky.feed.post", "text": "No spoilers please", "createdAt": "2024-01-01T00:00:00.000Z"},
          "indexedAt": "2024-01-01T00:00:00.000Z"
        }
        """#.utf8))

        let verdict = try await exampleModerationOptions(bsky: pds.server.makeAgent(), post: post)

        #expect(verdict == "leave it out of the feed")
        #expect(pds.calledMethods == ["app.bsky.actor.getPreferences", "app.bsky.labeler.getServices"])
        // Reading preferences also told the client which labelers to ask for.
        #expect(pds.lastRequestHeader("atproto-accept-labelers") == "did:plc:ar7c4by46qjdydhdevvrndac;redact")
    }

    func exampleLabelers(client: ATProtoClient) async throws {
        let ozone = try DID(didString: "did:plc:ar7c4by46qjdydhdevvrndac")
        let community = try DID(didString: "did:web:labeler.example.com")

        // Ask for labels from these services on every request.
        await client.configureLabelers([
            AcceptedLabeler(did: ozone, redact: true),
            AcceptedLabeler(did: community),
        ])

        // An empty list means "apply no labels". To return to the server's
        // defaults, remove the header instead.
        await client.configureLabelers([])
        await client.clearLabelers()
    }

    @Test("Moderation: choosing labelers")
    func labelers() async throws {
        let server = BskyStubServer()
        let client = await server.makeClient()
        try await exampleLabelers(client: client)
        #expect(await client.configuredLabelers() == nil)
    }

    func exampleReport(bsky: BskyAgent, account: DID, labeler: DID) async throws {
        // The report goes to this labeler for this request only.
        try await bsky.createModerationReport(
            ComAtprotoModerationCreateReport.Input(
                reasonType: .comatprotomoderationdefsreasonspam,
                reason: "Repeated unsolicited replies",
                subject: .comAtprotoAdminDefsRepoRef(.init(did: account))
            ),
            labeler: labeler
        )

        // Any lexicon method can be sent to a specific service the same way.
        let convos = try await bsky.query(
            "chat.bsky.convo.listConvos",
            parameters: ChatBskyConvoListConvos.Parameters(limit: 20),
            as: ChatBskyConvoListConvos.Output.self,
            options: BskyCallOptions(proxy: .bskyChat)
        )
        _ = convos
    }

    @Test("Moderation: report to a labeler, per-call service proxy")
    func report() async throws {
        let pds = BskyFakePDS()
        try pds.setResponseJSON(#"""
        {
          "id": 1, "reasonType": "com.atproto.moderation.defs#reasonSpam",
          "subject": {"$type": "com.atproto.admin.defs#repoRef", "did": "did:plc:bob"},
          "reportedBy": "did:plc:alice", "createdAt": "2024-01-01T00:00:00.000Z"
        }
        """#, for: "com.atproto.moderation.createReport")
        try pds.setResponseJSON(#"{"convos": []}"#, for: "chat.bsky.convo.listConvos")
        let bsky = try await pds.server.makeAgent()

        try await exampleReport(
            bsky: bsky,
            account: DID(didString: "did:plc:bob"),
            labeler: DID(didString: "did:plc:labeler")
        )

        #expect(pds.calledMethods == ["com.atproto.moderation.createReport", "chat.bsky.convo.listConvos"])
        #expect(pds.lastRequestHeader("atproto-proxy") == "did:web:api.bsky.chat#bsky_chat")
    }

    func exampleLabelStream(frames: [Data]) throws -> [ComAtprotoLabelDefs.Label] {
        var labels = LabelSet()
        for frame in frames {
            // Frames with a message type this SDK does not know decode to nil
            // and are skipped; the stream goes on.
            try labels.apply(LabelStreamDecoder.decode(frame: frame))
        }
        // Negated and expired labels are not returned. `labels.cursor` is
        // where to resume the subscription.
        return labels.activeLabels()
    }

    @Test("Moderation: consuming a label stream")
    func labelStream() throws {
        func frame(_ type: String, _ payload: CBOR) -> Data {
            Data(CBOR.map(["op": 1, "t": .utf8String(type)]).encode() + payload.encode())
        }
        func label(_ val: String, _ time: String, neg: Bool) -> CBOR {
            [
                "ver": 1, "src": "did:plc:labeler", "uri": "did:plc:bob", "val": .utf8String(val),
                "neg": .boolean(neg), "cts": .utf8String(time),
            ]
        }
        let active = try exampleLabelStream(frames: [
            frame("#labels", ["seq": 1, "labels": [label("spam", "2024-01-01T00:00:00.000Z", neg: false)]]),
            frame("#labels", ["seq": 2, "labels": [label("rude", "2024-01-01T00:00:00.000Z", neg: false)]]),
            frame("#fromTheFuture", ["anything": true]),
            frame("#labels", ["seq": 3, "labels": [label("spam", "2024-01-02T00:00:00.000Z", neg: true)]]),
        ])
        #expect(active.map(\.val) == ["rude"])
    }

    // MARK: Links

    func exampleLinks() throws -> (URL?, ATProtocolURI?) {
        let uri = try ATProtocolURI(uriString: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kabc")
        let shareURL = BskyAppURL.url(for: uri, handle: "bsky.app")
        // https://bsky.app/profile/bsky.app/post/3kabc

        let pasted = URL(string: "https://bsky.app/profile/bsky.app/post/3kabc")
        let parsed = pasted.flatMap { BskyAppURL.atURI(from: $0) }
        // at://bsky.app/app.bsky.feed.post/3kabc — resolve the handle before storing it
        return (shareURL, parsed)
    }

    @Test("Links: at:// URIs and bsky.app addresses")
    func links() throws {
        let (shareURL, parsed) = try exampleLinks()
        #expect(shareURL?.absoluteString == "https://bsky.app/profile/bsky.app/post/3kabc")
        #expect(parsed?.uriString() == "at://bsky.app/app.bsky.feed.post/3kabc")
    }
}

extension BskyDocumentationExampleTests {
    /// The video snippet of BlueskyPosting.md. Compiled only: the default
    /// video service is a real host. The flow itself is run against a stub in
    /// `BskyAgentVideoTests`.
    func exampleVideo(bsky: BskyAgent, data: Data) async throws {
        let video = try await bsky.uploadVideo(data, name: "landing.mp4")
        try await bsky.post("Landing", embed: .video(video, alt: "A petrel landing"))
    }
}
