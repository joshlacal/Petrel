import Foundation
@testable import Petrel
import Testing

// Wire-level tests of everything that travels in headers: the labelers a
// client asks for, per-call service proxying, and the preference and labeler
// calls that configure them.

private let bskyLabeler = "did:plc:ar7c4by46qjdydhdevvrndac"
private let appView = "did:web:api.bsky.app#bsky_appview"

@Suite("AcceptedLabeler header syntax")
struct AcceptedLabelerTests {
    private func labeler(_ did: String, redact: Bool = false) throws -> AcceptedLabeler {
        try AcceptedLabeler(did: DID(didString: did), redact: redact)
    }

    @Test("formats the header as in the label specification")
    func format() throws {
        let value = try AcceptedLabeler.headerValue(for: [
            labeler("did:web:mod.example.com", redact: true), labeler("did:plc:abc123"), labeler("did:plc:xyz789"),
        ])
        #expect(value == "did:web:mod.example.com;redact, did:plc:abc123, did:plc:xyz789")
        #expect(AcceptedLabeler.headerValue(for: []) == "")
    }

    @Test("a repeated DID is sent once, with redact if any occurrence had it")
    func deduplicates() throws {
        let value = try AcceptedLabeler.headerValue(for: [
            labeler("did:plc:abc123"), labeler("did:plc:xyz789"), labeler("did:plc:abc123", redact: true),
            labeler("did:plc:xyz789"),
        ])
        #expect(value == "did:plc:abc123;redact, did:plc:xyz789")
    }

    @Test("parses request and response header values")
    func parse() throws {
        let parsed = AcceptedLabeler.parseHeader(
            " did:web:mod.example.com;redact,did:plc:abc123 , did:plc:xyz789;unknown=1, not-a-did, did:plc:abc123;redact,"
        )
        #expect(try parsed == [
            labeler("did:web:mod.example.com", redact: true),
            labeler("did:plc:abc123", redact: true),
            labeler("did:plc:xyz789"),
        ])
        #expect(AcceptedLabeler.parseHeader("").isEmpty)
        #expect(AcceptedLabeler.parseHeader(AcceptedLabeler.headerValue(for: parsed)) == parsed)
    }

    @Test("a DID cannot smuggle header syntax")
    func noInjection() {
        // The typed API only accepts values that parse as DIDs, and DID syntax
        // has no comma, semicolon or whitespace.
        for hostile in ["did:plc:a, did:plc:evil;redact", "did:plc:a;redact", "did:plc:a b", "did:plc:a\r\nx: y"] {
            #expect(throws: (any Error).self) { try DID(didString: hostile) }
        }
    }
}

@Suite("Labeler configuration on the wire")
struct BskyLabelerHeaderTests {
    private func ping(_ client: ATProtoClient) async throws {
        _ = try await client.bsky.query("com.example.ping", as: BskyJSON.self)
    }

    @Test("configureLabelers sends the header on every request; clearLabelers removes it")
    func configureAndClear() async throws {
        let server = BskyStubServer { _ in .json([:]) }
        let client = await server.makeClient()
        let mod = try AcceptedLabeler(did: DID(didString: "did:web:mod.example.com"), redact: true)
        let other = try AcceptedLabeler(did: DID(didString: "did:plc:abc123"))

        try await ping(client)
        #expect(server.requests[0].header("atproto-accept-labelers") == nil)
        #expect(await client.configuredLabelers() == nil)

        await client.configureLabelers([mod, other, other])
        try await ping(client)
        #expect(server.requests[1].header("atproto-accept-labelers") == "did:web:mod.example.com;redact, did:plc:abc123")
        #expect(await client.configuredLabelers() == [mod, other])

        await client.clearLabelers()
        try await ping(client)
        #expect(server.requests[2].header("atproto-accept-labelers") == nil)
    }

    @Test("an empty labeler list is sent as an empty header, not as no header")
    func emptyListIsSent() async throws {
        let server = BskyStubServer { _ in .json([:]) }
        let client = await server.makeClient()

        await client.configureLabelers([])
        try await ping(client)

        // Present and empty means "apply no labels"; absent means "use your defaults".
        #expect(server.requests[0].header("atproto-accept-labelers") == "")
        #expect(await client.configuredLabelers() == [])
    }

    @Test("per-call acceptLabelers overrides the configured labelers for that call only")
    func perCallLabelers() async throws {
        let server = BskyStubServer { _ in .json([:]) }
        let client = await server.makeClient()
        let configured = try AcceptedLabeler(did: DID(didString: "did:plc:configured"))
        let oneOff = try AcceptedLabeler(did: DID(didString: "did:plc:oneoff"), redact: true)
        await client.configureLabelers([configured])

        _ = try await client.bsky.query(
            "com.example.ping", as: BskyJSON.self, options: BskyCallOptions(acceptLabelers: [oneOff])
        )
        _ = try await client.bsky.query(
            "com.example.ping", as: BskyJSON.self, options: BskyCallOptions(acceptLabelers: [])
        )
        try await ping(client)

        #expect(server.requests.map { $0.header("atproto-accept-labelers") } == [
            "did:plc:oneoff;redact", "", "did:plc:configured",
        ])
    }

    @Test("the labelers a response reports are parsed from atproto-content-labelers")
    func contentLabelers() async throws {
        let server = BskyStubServer { _ in
            .json([:], headers: ["atproto-content-labelers": "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:abc123"])
        }
        let agent = try await server.makeAgent()
        let response = try await agent.xrpcQuery("app.bsky.feed.getTimeline")
        #expect(try response.contentLabelers == [
            AcceptedLabeler(did: DID(didString: bskyLabeler), redact: true),
            AcceptedLabeler(did: DID(didString: "did:plc:abc123")),
        ])
    }

    @Test("BskyAgent.configureLabelers puts the app labelers first, with redact")
    func agentConfigureLabelers() async throws {
        let server = BskyStubServer { _ in .json([:]) }
        var agent = try await server.makeAgent()
        let custom = try DID(didString: "did:plc:custom")

        await agent.configureLabelers([custom, BskyAgent.bskyLabelerDID])
        _ = try await agent.xrpcQuery("com.example.ping")
        #expect(server.requests[0].header("atproto-accept-labelers") == "\(bskyLabeler);redact, did:plc:custom")

        agent.appLabelers = []
        await agent.configureLabelers([custom])
        _ = try await agent.xrpcQuery("com.example.ping")
        #expect(server.requests[1].header("atproto-accept-labelers") == "did:plc:custom")
    }
}

@Suite("Per-call service proxy")
struct BskyServiceProxyTests {
    @Test("ServiceProxy formats atproto-proxy values and validates the service id")
    func headerValues() throws {
        let labeler = try DID(didString: "did:plc:labeler")
        #expect(ServiceProxy.bskyChat.headerValue == "did:web:api.bsky.chat#bsky_chat")
        #expect(ServiceProxy.bskyAppView.headerValue == "did:web:api.bsky.app#bsky_appview")
        #expect(ServiceProxy.labeler(labeler).headerValue == "did:plc:labeler#atproto_labeler")
        #expect(ServiceProxy.chat(labeler).headerValue == "did:plc:labeler#bsky_chat")
        #expect(try ServiceProxy(did: labeler, serviceID: "atproto_pds").headerValue == "did:plc:labeler#atproto_pds")
        for invalid in ["", "#frag", "a b", "a,b", "x\r\n"] {
            #expect(throws: BskyAgentError.self) { try ServiceProxy(did: labeler, serviceID: invalid) }
        }
    }

    @Test("a proxy option applies to one call and leaves the client's headers alone")
    func perCallProxy() async throws {
        let server = BskyStubServer { request in
            request.nsid == "chat.bsky.convo.listConvos" ? .json(["convos": []]) : .json([:])
        }
        let agent = try await server.makeAgent()

        let convos = try await agent.query(
            "chat.bsky.convo.listConvos",
            parameters: ChatBskyConvoListConvos.Parameters(limit: 20),
            as: ChatBskyConvoListConvos.Output.self,
            options: BskyCallOptions(proxy: .chat(DID(didString: "did:web:chat.example.com")))
        )
        #expect(convos.convos.isEmpty)
        _ = try await agent.xrpcQuery("chat.bsky.convo.listConvos")
        _ = try await agent.xrpcQuery("com.atproto.server.describeServer")

        let requests = server.requests
        #expect(requests[0].method == "GET")
        #expect(requests[0].query("limit") == ["20"])
        // The explicit target wins for that call…
        #expect(requests[0].header("atproto-proxy") == "did:web:chat.example.com#bsky_chat")
        // …the next call falls back to the namespace default…
        #expect(requests[1].header("atproto-proxy") == "did:web:api.bsky.chat#bsky_chat")
        // …and calls outside a proxied namespace carry no proxy at all.
        #expect(requests[2].header("atproto-proxy") == nil)
        #expect(await agent.networkService.getHeader(name: "atproto-proxy") == nil)
    }

    @Test("procedure sends a generated input and decodes the generated output")
    func typedProcedure() async throws {
        let server = BskyStubServer { _ in
            .json(["id": "3kmsg", "rev": "3krev", "text": "hi", "sender": ["did": "did:plc:alice"], "sentAt": "2024-01-01T00:00:00.000Z"])
        }
        let agent = try await server.makeAgent()

        let message = try await agent.procedure(
            "chat.bsky.convo.sendMessage",
            input: ChatBskyConvoSendMessage.Input(convoId: "3kconvo", message: .init(text: "hi")),
            as: ChatBskyConvoDefs.MessageView.self,
            options: BskyCallOptions(proxy: .bskyChat, headers: ["X-Example": "1"])
        )

        #expect(message.text == "hi")
        let request = try #require(server.requests.first)
        #expect(request.method == "POST")
        #expect(request.header("atproto-proxy") == "did:web:api.bsky.chat#bsky_chat")
        #expect(request.header("X-Example") == "1")
        #expect(request.json?["convoId"] == "3kconvo")
        #expect(request.json?["message"]?["text"] == "hi")
    }

    @Test("createModerationReport addresses a labeler for that request only")
    func reportToLabeler() async throws {
        let server = BskyStubServer { request in
            request.nsid == "com.atproto.moderation.createReport"
                ? .json([
                    "id": 7,
                    "reasonType": "com.atproto.moderation.defs#reasonSpam",
                    "subject": ["$type": "com.atproto.admin.defs#repoRef", "did": "did:plc:spammer"],
                    "reportedBy": "did:plc:alice",
                    "createdAt": "2024-01-01T00:00:00.000Z",
                ])
                : .json([:])
        }
        let agent = try await server.makeAgent()
        let input = try ComAtprotoModerationCreateReport.Input(
            reasonType: .comatprotomoderationdefsreasonspam,
            reason: "Unsolicited replies",
            subject: .comAtprotoAdminDefsRepoRef(.init(did: DID(didString: "did:plc:spammer")))
        )

        let toLabeler = try await agent.createModerationReport(input, labeler: DID(didString: "did:plc:labeler"))
        try await agent.createModerationReport(input)
        _ = try await agent.xrpcQuery("com.atproto.server.describeServer")

        #expect(toLabeler.id == 7)
        let requests = server.requests
        #expect(requests[0].header("atproto-proxy") == "did:plc:labeler#atproto_labeler")
        #expect(requests[0].json?["reasonType"] == "com.atproto.moderation.defs#reasonSpam")
        #expect(requests[0].json?["reason"] == "Unsolicited replies")
        #expect(requests[0].json?["subject"]?["did"] == "did:plc:spammer")
        // Without a labeler the PDS's own moderation service receives it, and
        // the earlier report left nothing behind on later requests.
        #expect(requests[1].header("atproto-proxy") == nil)
        #expect(requests[2].header("atproto-proxy") == nil)
    }
}

@Suite("Preferences and label definitions on the wire")
struct BskyPreferencesWireTests {
    @Test("getPreferences reads from the PDS directly and applies the user's labelers to later requests")
    func getPreferences() async throws {
        let pds = BskyFakePDS()
        pds.setPreferences([
            ["$type": "app.bsky.actor.defs#adultContentPref", "enabled": true],
            ["$type": "app.bsky.actor.defs#labelersPref", "labelers": [["did": "did:plc:custom"]]],
            ["$type": "app.bsky.actor.defs#savedFeedsPrefV2", "items": [
                ["id": "3kaaaaaaaaaaa", "type": "timeline", "value": "following", "pinned": true],
            ]],
            ["$type": "com.example.future#pref", "keep": "me"],
        ])
        let agent = try await pds.server.makeAgent()

        let prefs = try await agent.getPreferences()

        #expect(prefs.moderationPrefs.adultContentEnabled)
        #expect(prefs.moderationPrefs.labelers.map { $0.did.didString() } == [bskyLabeler, "did:plc:custom"])
        let read = try #require(pds.server.requests.first)
        #expect(read.method == "GET")
        #expect(read.nsid == "app.bsky.actor.getPreferences")
        // Preferences live on the PDS: no AppView proxy, unlike other app.bsky calls.
        #expect(read.header("atproto-proxy") == nil)
        #expect(pds.server.requests(to: "app.bsky.actor.putPreferences").isEmpty)

        pds.setResponse(.json(["feed": []]), for: "app.bsky.feed.getTimeline")
        _ = try await agent.xrpcQuery("app.bsky.feed.getTimeline")
        let next = try #require(pds.server.requests.last)
        #expect(next.header("atproto-accept-labelers") == "\(bskyLabeler);redact, did:plc:custom")
        #expect(next.header("atproto-proxy") == appView)
    }

    @Test("a setter writes the whole array back, keeping entries it does not understand")
    func setterWritesBack() async throws {
        let pds = BskyFakePDS()
        let unknown: BskyJSON = ["$type": "com.example.future#pref", "keep": "me"]
        pds.setPreferences([unknown, ["$type": "app.bsky.actor.defs#adultContentPref", "enabled": false]])
        let agent = try await pds.server.makeAgent()

        try await agent.setAdultContentEnabled(true)
        try await agent.addLabeler(DID(didString: "did:plc:custom"))

        let writes = pds.server.requests(to: "app.bsky.actor.putPreferences")
        #expect(writes.count == 2)
        #expect(writes.allSatisfy { $0.method == "POST" && $0.header("atproto-proxy") == nil })
        #expect(writes[0].json == ["preferences": [
            unknown, ["$type": "app.bsky.actor.defs#adultContentPref", "enabled": true],
        ]])
        #expect(pds.storedPreferences.contains(unknown))
        #expect(pds.storedPreferences.contains(
            ["$type": "app.bsky.actor.defs#labelersPref", "labelers": [["did": "did:plc:custom"]]]
        ))
        // addLabeler also starts asking for that labeler's labels.
        #expect(await agent.networkService.getHeader(name: "atproto-accept-labelers")
            == "\(bskyLabeler);redact, did:plc:custom")
    }

    @Test("concurrent setters on one client do not lose each other's writes")
    func concurrentSetters() async throws {
        let pds = BskyFakePDS()
        let agent = try await pds.server.makeAgent()
        let posts = try (0 ..< 12).map { try ATProtocolURI(uriString: "at://did:plc:bob/app.bsky.feed.post/3k\($0)") }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for post in posts {
                // A fresh agent value per task, as `client.bsky` hands out.
                let handle = BskyAgent(networkService: agent.networkService, did: try DID(didString: BskyStubServer.alice))
                group.addTask { try await handle.hidePost(post) }
            }
            try await group.waitForAll()
        }

        let hidden = pds.storedPreferences
            .first { $0.typeIdentifier == "app.bsky.actor.defs#hiddenPostsPref" }?["items"]?.arrayValue
        #expect(Set(hidden?.compactMap(\.stringValue) ?? []) == Set(posts.map { $0.uriString() }))
    }

    @Test(
        "concurrent labeler changes through agents sharing one network service leave the header matching the saved subscriptions",
        .timeLimit(.minutes(1)),
        arguments: 0 ..< 20
    )
    func concurrentLabelerChanges(_: Int) async throws {
        let pds = BskyFakePDS()
        let seeded = (0 ..< 4).map { "did:plc:seed\($0)" }
        pds.setPreferences([
            ["$type": "app.bsky.actor.defs#labelersPref", "labelers": .array(seeded.map { ["did": .string($0)] })],
            ["$type": "app.bsky.actor.defs#savedFeedsPrefV2", "items": []],
        ])
        let service = await pds.server.makeNetworkService()
        let alice = try DID(didString: BskyStubServer.alice)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 6 {
                // A fresh agent value per call, as `client.bsky` hands out.
                let added = try DID(didString: "did:plc:added\(index)")
                group.addTask { try await BskyAgent(networkService: service, did: alice).addLabeler(added) }
                if index < 3 {
                    let removed = try DID(didString: seeded[index])
                    group.addTask { try await BskyAgent(networkService: service, did: alice).removeLabeler(removed) }
                }
                if index.isMultiple(of: 3) {
                    group.addTask { _ = try await BskyAgent(networkService: service, did: alice).getPreferences() }
                }
            }
            try await group.waitForAll()
        }

        let stored = pds.storedPreferences
            .last { $0.typeIdentifier == "app.bsky.actor.defs#labelersPref" }?["labelers"]?.arrayValue?
            .compactMap { $0["did"]?.stringValue } ?? []
        #expect(Set(stored) == Set(["did:plc:seed3"] + (0 ..< 6).map { "did:plc:added\($0)" }))
        // What the next request will ask for is exactly what is saved, in saved order.
        #expect(await service.getHeader(name: "atproto-accept-labelers")
            == (["\(bskyLabeler);redact"] + stored).joined(separator: ", "))
    }

    @Test("getLabelDefinitions asks the AppView for detailed services and interprets their definitions")
    func labelDefinitions() async throws {
        let pds = BskyFakePDS()
        pds.setResponse(.json(["views": [
            [
                "$type": "app.bsky.labeler.defs#labelerViewDetailed",
                "uri": "at://did:plc:custom/app.bsky.labeler.service/self",
                "cid": .string(CID.fromDAGCBOR(Data("svc".utf8)).string),
                "creator": ["did": "did:plc:custom", "handle": "labeler.test"],
                "policies": [
                    "labelValues": ["spoiler", "porn"],
                    "labelValueDefinitions": [[
                        "identifier": "spoiler",
                        "severity": "inform",
                        "blurs": "content",
                        "defaultSetting": "warn",
                        "locales": [["lang": "en", "name": "Spoiler", "description": "Discusses plot details"]],
                    ]],
                ],
                "indexedAt": "2024-01-01T00:00:00.000Z",
            ],
            ["$type": "app.bsky.labeler.defs#somethingNew", "ignored": true],
        ]]), for: "app.bsky.labeler.getServices")
        let agent = try await pds.server.makeAgent()
        let custom = try DID(didString: "did:plc:custom")

        let definitions = try await agent.getLabelDefinitions(for: [custom, custom])

        let request = try #require(pds.server.requests.first)
        #expect(request.query("dids") == [bskyLabeler, "did:plc:custom"])
        #expect(request.query("detailed") == ["true"])
        #expect(request.header("atproto-proxy") == appView)
        #expect(Array(definitions.keys) == [custom])
        let spoiler = try #require(definitions[custom]?.first)
        #expect(spoiler.identifier == "spoiler")
        #expect(spoiler.definedBy == custom)
        #expect(spoiler.defaultSetting == .warn)
        #expect(spoiler.behaviors.content.contentList == .blur)
        #expect(spoiler.behaviors.content.contentView == .inform)
    }

    @Test("moderationOptions gathers the user's DID, preferences and label definitions")
    func moderationOptions() async throws {
        let pds = BskyFakePDS()
        pds.setPreferences([
            ["$type": "app.bsky.actor.defs#contentLabelPref", "label": "nudity", "visibility": "hide"],
            ["$type": "app.bsky.actor.defs#savedFeedsPrefV2", "items": []],
        ])
        pds.setResponse(.json(["views": []]), for: "app.bsky.labeler.getServices")
        let agent = try await pds.server.makeAgent()

        let options = try await agent.moderationOptions()

        #expect(options.userDid?.didString() == BskyStubServer.alice)
        #expect(options.prefs.labels["nudity"] == .hide)
        #expect(options.prefs.labelers.map { $0.did.didString() } == [bskyLabeler])
        #expect(options.labelDefs.isEmpty)
    }
}
