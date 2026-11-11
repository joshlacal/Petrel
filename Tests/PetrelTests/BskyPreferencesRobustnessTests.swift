import Foundation
@testable import Petrel
import Testing

/// Properties the reference implementation relies on its runtime for and this
/// port has to guarantee itself: serialized writes, lossless rewrites, a lock
/// that survives failures, and tolerance of malformed stored entries.
@Suite("BskyPreferences robustness")
struct BskyPreferencesRobustnessTests {
    // MARK: Serialization

    @Test("parallel setters are serialized; no write is lost", .timeLimit(.minutes(1)))
    func parallelSettersDoNotClobber() async throws {
        let (engine, backend) = PrefsFixture.make()
        let count = 40

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< count {
                group.addTask {
                    try await engine.hidePost(PrefsFixture.uri("at://did:plc:fake/app.bsky.feed.post/p\(index)"))
                }
            }
            try await group.waitForAll()
        }

        let hidden = try await engine.getPreferences().moderationPrefs.hiddenPosts
        #expect(hidden.count == count)
        #expect(Set(hidden.map { $0.uriString() }).count == count)
        #expect(backend.entries(ofType: "app.bsky.actor.defs#hiddenPostsPref").count == 1)
    }

    @Test("parallel setters of different kinds all land", .timeLimit(.minutes(1)))
    func parallelMixedSetters() async throws {
        let (engine, _) = PrefsFixture.make()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 10 {
                group.addTask { try await engine.addMutedWord(value: "word\(index)", targets: [.content]) }
                group.addTask { try await engine.bskyAppQueueNudges(["nudge\(index)"]) }
                group.addTask {
                    try await engine.addSavedFeeds([
                        BskyNewSavedFeed(
                            type: "feed",
                            value: "at://bob.com/app.bsky.feed.generator/\(index)",
                            pinned: index.isMultiple(of: 2)
                        ),
                    ])
                }
                group.addTask { _ = try await engine.getPreferences() }
            }
            try await group.waitForAll()
        }

        let prefs = try await engine.getPreferences()
        #expect(Set(prefs.moderationPrefs.mutedWords.map(\.value)) == Set((0 ..< 10).map { "word\($0)" }))
        #expect(Set(prefs.bskyAppState.queuedNudges) == Set((0 ..< 10).map { "nudge\($0)" }))
        #expect(prefs.savedFeeds.filter { $0.type == "feed" }.count == 10)
        #expect(prefs.savedFeeds.filter { $0.type == "timeline" }.count <= 1)
        // Pinned feeds always come first.
        let pinnedFlags = prefs.savedFeeds.map(\.pinned)
        #expect(pinnedFlags == pinnedFlags.sorted { $0 && !$1 })
    }

    @Test("agents of one network service share a lock; different services do not")
    func lockRegistryIsPerNetworkService() throws {
        let url = try #require(URL(string: "https://pds.invalid"))
        let first = NetworkService(baseURL: url)
        let second = NetworkService(baseURL: url)

        let a = BskyAgent(networkService: first, did: nil)
        let b = BskyAgent(networkService: first, did: nil)
        let c = BskyAgent(networkService: second, did: nil)

        #expect(a.preferencesLock === b.preferencesLock)
        #expect(a.preferencesLock !== c.preferencesLock)
        #expect(a.preferencesEngine.lock === b.preferencesEngine.lock)
        #expect(a.preferencesEngine.appLabelers == [BskyAgent.bskyLabelerDID])
    }

    // MARK: Failure handling

    @Test("a failed write releases the lock and leaves the store untouched", .timeLimit(.minutes(1)))
    func lockReleasedOnThrow() async throws {
        let (engine, backend) = PrefsFixture.make()
        try await engine.setAdultContentEnabled(true)
        let before = backend.preferences

        backend.failNextSaves(1)
        await #expect(throws: FakePreferencesBackend.SaveFailure.self) {
            try await engine.setAdultContentEnabled(false)
        }
        #expect(backend.preferences == before)

        // Would hang here if the failed call still held the lock.
        try await engine.setAdultContentEnabled(false)
        #expect(try await engine.getPreferences().moderationPrefs.adultContentEnabled == false)
    }

    @Test("a throwing transform releases the lock and writes nothing", .timeLimit(.minutes(1)))
    func lockReleasedWhenTransformThrows() async throws {
        let (engine, backend) = PrefsFixture.make()
        struct Boom: Error {}

        await #expect(throws: Boom.self) {
            try await engine.updatePreferences { _ in throw Boom() }
        }
        #expect(backend.saveCount == 0)

        try await engine.setIsBetaUser(true)
        #expect(backend.saveCount == 1)
    }

    @Test("a validation failure surfaces as BskyAgentError.invalidInput")
    func validationErrorsAreTyped() async throws {
        let (engine, _) = PrefsFixture.make()
        do {
            try await engine.addSavedFeeds([BskyNewSavedFeed(type: "feed", value: "not a uri", pinned: true)])
            Issue.record("expected a validation error")
        } catch let error as BskyAgentError {
            guard case .invalidInput = error else {
                Issue.record("expected invalidInput, got \(error)")
                return
            }
        }
    }

    // MARK: Lossless read-modify-write

    private static let foreignEntries = #"""
    [
      {"$type": "com.example.prefs#futurePref", "nested": {"list": [1, 2.5, "three", null, true]}, "n": -7},
      {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": true, "futureField": {"a": [1, 2]}},
      {"$type": "app.bsky.actor.defs#feedViewPref", "feed": "home", "hideReplies": true, "lab_mergeFeedEnabled": true},
      {"$type": "app.bsky.actor.defs#threadViewPref", "sort": "newest", "prioritizeFollowedUsers": true},
      {"$type": "app.bsky.actor.defs#bskyAppStatePref", "queuedNudges": ["one"], "futureState": "kept"},
      {"$type": "app.bsky.actor.defs#mutedWordsPref",
       "items": [{"id": "3jzfcijpj2z2a", "value": "kept", "targets": ["content"], "actorTarget": "all", "note": "x"}],
       "futureList": []},
      {"$type": "app.bsky.actor.defs#savedFeedsPrefV2",
       "items": [{"id": "3jzfcijpj2z2b", "type": "feed", "value": "at://bob.com/app.bsky.feed.generator/1",
                  "pinned": false, "note": "y"}],
       "futureCursor": "abc"},
      {"no-type": true},
      "not even an object"
    ]
    """#

    @Test("unknown entries and unknown fields survive every kind of setter")
    func unknownDataSurvives() async throws {
        let seed = try PrefsFixture.entries(Self.foreignEntries)
        let (engine, backend) = PrefsFixture.make(seed)
        let other = try PrefsFixture.did("did:plc:other")

        _ = try await engine.getPreferences()
        try await engine.setAdultContentEnabled(false)
        try await engine.setContentLabelPref("porn", .hide)
        try await engine.addLabeler(other)
        try await engine.removeLabeler(other)
        try await engine.setFeedViewPrefs(feed: "home", .init(hideReposts: true))
        try await engine.setThreadViewPrefs(sort: "oldest")
        try await engine.setInterestsPref(tags: ["a"])
        try await engine.setPersonalDetails(birthDate: Date(timeIntervalSince1970: 0))
        try await engine.addMutedWord(value: "new", targets: [.tag])
        try await engine.hidePost(PrefsFixture.uri("at://did:plc:fake/app.bsky.feed.post/1"))
        try await engine.bskyAppQueueNudges(["two"])
        try await engine.setIsBetaUser(true)
        try await engine.bskyAppUpsertNux(AppBskyActorDefs.Nux(id: "n", completed: true))
        try await engine.setVerificationPrefs(hideBadges: true)
        try await engine.updateLiveEventPreferences(.hideFeed(id: "f"))
        try await engine.setPostInteractionSettings(.init(threadgateAllowRules: [], postgateEmbeddingRules: nil))
        try await engine.addSavedFeeds([.timeline(pinned: true)])
        let savedID = try #require(try await engine.getPreferences().savedFeeds.first { $0.type == "feed" }?.id)
        try await engine.updateSavedFeeds([
            AppBskyActorDefs.SavedFeed(id: savedID, type: "feed", value: "at://bob.com/app.bsky.feed.generator/other", pinned: true),
        ])
        try await engine.addSavedFeed(PrefsFixture.uri("at://bob.com/app.bsky.feed.generator/2"))

        let raw = backend.preferences
        func only(_ type: String) throws -> BskyJSON {
            let matches = raw.filter { $0.typeIdentifier == type }
            #expect(matches.count == 1, "\(type)")
            return try #require(matches.first)
        }

        // Entries this SDK has no model for are returned exactly as stored.
        #expect(raw.contains(seed[0]))
        #expect(raw.contains(seed[7]))
        #expect(raw.contains(seed[8]))

        // Unknown fields inside entries that were rewritten are still there.
        #expect(try only("app.bsky.actor.defs#adultContentPref") == PrefsFixture.json(
            #"{"$type": "app.bsky.actor.defs#adultContentPref", "enabled": false, "futureField": {"a": [1, 2]}}"#
        ))
        #expect(try only("app.bsky.actor.defs#feedViewPref") == PrefsFixture.json(#"""
        {"$type": "app.bsky.actor.defs#feedViewPref", "feed": "home", "hideReplies": true,
         "hideReposts": true, "lab_mergeFeedEnabled": true}
        """#))
        #expect(try only("app.bsky.actor.defs#threadViewPref") == PrefsFixture.json(
            #"{"$type": "app.bsky.actor.defs#threadViewPref", "sort": "oldest", "prioritizeFollowedUsers": true}"#
        ))

        let appState = try only("app.bsky.actor.defs#bskyAppStatePref")
        #expect(appState["futureState"] == .string("kept"))
        #expect(appState["queuedNudges"] == .array([.string("one"), .string("two")]))
        #expect(appState["isBetaUser"] == .bool(true))

        let mutedWords = try only("app.bsky.actor.defs#mutedWordsPref")
        #expect(mutedWords["futureList"] == .array([]))
        #expect(mutedWords["items"]?.arrayValue?.first == seed[5]["items"]?.arrayValue?.first)
        #expect(mutedWords["items"]?.arrayValue?.count == 2)

        let savedFeeds = try only("app.bsky.actor.defs#savedFeedsPrefV2")
        #expect(savedFeeds["futureCursor"] == .string("abc"))
        let storedFeed = try #require(savedFeeds["items"]?.arrayValue?.first { $0["id"]?.stringValue == savedID })
        #expect(storedFeed["note"] == .string("y"))
        #expect(storedFeed["pinned"] == .bool(true))
        #expect(storedFeed["value"] == .string("at://bob.com/app.bsky.feed.generator/1"))
    }

    @Test("a setter leaves every entry it does not own byte-for-value identical")
    func untouchedEntriesAreIdentical() async throws {
        let seed = try PrefsFixture.entries(Self.foreignEntries)
        let (engine, backend) = PrefsFixture.make(seed)

        try await engine.setVerificationPrefs(hideBadges: true)

        let raw = backend.preferences
        #expect(Array(raw.prefix(seed.count)) == seed)
        #expect(raw.count == seed.count + 1)
    }

    @Test("BskyJSON round-trips integers, fractions, null and nesting")
    func jsonRoundTrip() throws {
        let value = try PrefsFixture.json(#"{"a": [1, 2.5, "three", null, true, {"b": -7}], "c": {}}"#)
        #expect(value["a"]?.arrayValue?[0] == .integer(1))
        #expect(value["a"]?.arrayValue?[1] == .double(2.5))
        #expect(value["a"]?.arrayValue?[3] == .null)
        #expect(try BskyJSON.parse(value.serialized()) == value)
    }

    // MARK: Malformed stored entries

    @Test("entries that do not satisfy the lexicon are skipped on read, not fatal")
    func invalidEntriesAreSkipped() async throws {
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [
          {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": true},
          {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": "yes"},
          {"$type": "app.bsky.actor.defs#adultContentPref"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "nudity", "visibility": "hide",
           "labelerDid": "not-a-did"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "sexual", "visibility": "blur"},
          {"$type": "app.bsky.actor.defs#labelersPref", "labelers": [{"did": "nope"}]},
          {"$type": "app.bsky.actor.defs#hiddenPostsPref", "items": ["https://example.com"]},
          {"$type": "app.bsky.actor.defs#mutedWordsPref", "items": [{"targets": ["content"]}]},
          {"$type": "app.bsky.actor.defs#savedFeedsPrefV2", "items": [{"id": "x"}]},
          {"$type": "app.bsky.actor.defs#feedViewPref", "hideReplies": true},
          {"$type": "app.bsky.actor.defs#interestsPref", "tags": "nope"}
        ]
        """#))

        let prefs = try await engine.getPreferences().ignoringSavedFeedIDs
        var expected = PrefsFixture.defaults()
        // The last *valid* adult content entry wins.
        expected.moderationPrefs.adultContentEnabled = true
        #expect(prefs == expected)
    }

    @Test("a setter replaces invalid entries of its kind and starts from the last valid one")
    func settersIgnoreInvalidExisting() async throws {
        let (engine, backend) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [
          {"$type": "app.bsky.actor.defs#bskyAppStatePref", "queuedNudges": ["valid"]},
          {"$type": "app.bsky.actor.defs#labelersPref", "labelers": [{"did": "did:plc:first"}]},
          {"$type": "app.bsky.actor.defs#labelersPref", "labelers": "broken"}
        ]
        """#))

        try await engine.addLabeler(PrefsFixture.did("did:plc:second"))

        #expect(try backend.entries(ofType: "app.bsky.actor.defs#labelersPref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#labelersPref",
          "labelers": [{"did": "did:plc:first"}, {"did": "did:plc:second"}]}]
        """#))
    }

    // MARK: Labeler wiring

    @Test("getPreferences applies app labelers with redact, then the user's labelers")
    func getPreferencesConfiguresLabelers() async throws {
        let first = try PrefsFixture.did("did:plc:first")
        let second = try PrefsFixture.did("did:plc:second")
        let (engine, backend) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#labelersPref",
          "labelers": [{"did": "did:plc:first"}, {"did": "did:plc:second"}]}]
        """#))

        _ = try await engine.getPreferences()

        #expect(backend.configuredLabelers == [[
            AcceptedLabeler(did: BskyAgent.bskyLabelerDID, redact: true),
            AcceptedLabeler(did: first),
            AcceptedLabeler(did: second),
        ]])
        #expect(AcceptedLabeler.headerValue(for: backend.configuredLabelers[0])
            == "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:first, did:plc:second")
    }

    @Test("custom app labelers replace the default one in both prefs and header")
    func customAppLabelers() async throws {
        let custom = try PrefsFixture.did("did:web:labeler.example")
        let backend = FakePreferencesBackend()
        let engine = BskyPreferencesEngine(backend: backend, lock: BskyAsyncLock(), appLabelers: [custom])

        let prefs = try await engine.getPreferences()

        #expect(prefs.moderationPrefs.labelers == [ModerationPrefsLabeler(did: custom)])
        #expect(backend.configuredLabelers == [[AcceptedLabeler(did: custom, redact: true)]])
    }

    @Test("setters other than add/removeLabeler do not touch the labeler configuration")
    func otherSettersDoNotConfigureLabelers() async throws {
        let (engine, backend) = PrefsFixture.make()
        try await engine.setAdultContentEnabled(true)
        try await engine.addMutedWord(value: "word", targets: [.content])
        #expect(backend.configuredLabelers.isEmpty)
    }
}
