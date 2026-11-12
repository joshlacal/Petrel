import Foundation
@testable import Petrel
import Testing

/// Ports of `saved feeds v2` and `saved feeds v2: migration scenarios` in
/// `packages/api/tests/atp-agent.test.ts`.
@Suite("BskyPreferences saved feeds")
struct BskyPreferencesSavedFeedsTests {
    private typealias SavedFeed = AppBskyActorDefs.SavedFeed

    private func feedURI(_ n: Int) -> String {
        "at://bob.com/app.bsky.feed.generator/\(n)"
    }

    private func listURI(_ n: Int) -> String {
        "at://bob.com/app.bsky.graph.list/\(n)"
    }

    private func newFeed(_ n: Int, pinned: Bool) -> BskyNewSavedFeed {
        BskyNewSavedFeed(type: "feed", value: feedURI(n), pinned: pinned)
    }

    private func saved(_ n: Int, pinned: Bool) async -> SavedFeed {
        await SavedFeed(id: TIDGenerator.next(), type: "feed", value: feedURI(n), pinned: pinned)
    }

    private func savedFeeds(_ engine: BskyPreferencesEngine) async throws -> [SavedFeed] {
        try await engine.getPreferences().savedFeeds
    }

    private let timeline = "timeline|following|true"

    // MARK: addSavedFeeds

    @Test("addSavedFeeds works")
    func addWorks() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])

        let feeds = try await savedFeeds(engine)
        #expect(feeds.map(\.signature) == ["feed|\(feedURI(0))|false"])
        #expect(feeds.first?.id.isEmpty == false)
    }

    @Test("addSavedFeeds throws if feed is specified and list provided")
    func addThrowsForListAsFeed() async throws {
        let (engine, backend) = PrefsFixture.make()
        await #expect(throws: BskyAgentError.self) {
            try await engine.addSavedFeeds([BskyNewSavedFeed(type: "feed", value: listURI(0), pinned: true)])
        }
        #expect(backend.saveCount == 0)
    }

    @Test("addSavedFeeds throws if list is specified and feed provided")
    func addThrowsForFeedAsList() async throws {
        let (engine, backend) = PrefsFixture.make()
        await #expect(throws: BskyAgentError.self) {
            try await engine.addSavedFeeds([BskyNewSavedFeed(type: "list", value: feedURI(0), pinned: true)])
        }
        #expect(backend.saveCount == 0)
    }

    @Test("addSavedFeeds: timeline")
    func addTimeline() async throws {
        let (engine, _) = PrefsFixture.make()
        let returned = try await engine.addSavedFeeds([.timeline(pinned: true)])

        let feeds = try await savedFeeds(engine)
        #expect(feeds.filter { $0.type == "timeline" } == returned)
        #expect(returned.map(\.signature) == [timeline])
    }

    @Test("addSavedFeeds allows duplicates")
    func addAllowsDuplicates() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])

        let feeds = try await savedFeeds(engine)
        #expect(feeds.map(\.signature) == ["feed|\(feedURI(0))|false", "feed|\(feedURI(0))|false"])
        #expect(Set(feeds.map(\.id)).count == 2)
    }

    @Test("addSavedFeeds adds multiple")
    func addMultiple() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addSavedFeeds([newFeed(0, pinned: true), newFeed(1, pinned: false)])

        #expect(try await savedFeeds(engine).map(\.signature) == [
            "feed|\(feedURI(0))|true",
            "feed|\(feedURI(1))|false",
        ])
    }

    @Test("addSavedFeeds appends multiple, pinned first")
    func appendMultiple() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addSavedFeeds([newFeed(0, pinned: true), newFeed(1, pinned: false)])
        try await engine.addSavedFeeds([newFeed(2, pinned: true), newFeed(3, pinned: false)])

        #expect(try await savedFeeds(engine).map(\.signature) == [
            "feed|\(feedURI(0))|true",
            "feed|\(feedURI(2))|true",
            "feed|\(feedURI(1))|false",
            "feed|\(feedURI(3))|false",
        ])
    }

    @Test("BskyNewSavedFeed factories produce the lexicon's type names")
    func newSavedFeedFactories() throws {
        let feed = try PrefsFixture.uri(feedURI(0))
        let list = try PrefsFixture.uri(listURI(1))
        #expect(BskyNewSavedFeed.feed(feed, pinned: true) == BskyNewSavedFeed(type: "feed", value: feedURI(0), pinned: true))
        #expect(BskyNewSavedFeed.list(list, pinned: false) == BskyNewSavedFeed(type: "list", value: listURI(1), pinned: false))
        #expect(BskyNewSavedFeed.timeline(pinned: true) == BskyNewSavedFeed(type: "timeline", value: "following", pinned: true))
    }

    // MARK: removeSavedFeeds

    @Test("removeSavedFeeds works")
    func removeWorks() async throws {
        let (engine, _) = PrefsFixture.make()
        let added = try await engine.addSavedFeeds([newFeed(0, pinned: true)])
        try await engine.removeSavedFeeds(ids: [#require(added.first).id])

        #expect(try await savedFeeds(engine).isEmpty)
    }

    // MARK: overwriteSavedFeeds

    @Test("overwriteSavedFeeds dedupes by id, takes last, preserves order based on last found")
    func overwriteDedupes() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await saved(0, pinned: true)
        let b = await saved(1, pinned: true)
        try await engine.overwriteSavedFeeds([a, b, a])

        #expect(try await savedFeeds(engine) == [b, a])
    }

    @Test("overwriteSavedFeeds preserves order")
    func overwritePreservesOrder() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await SavedFeed(id: TIDGenerator.next(), type: "timeline", value: feedURI(0), pinned: true)
        let b = await saved(1, pinned: false)
        let c = await saved(2, pinned: true)
        let d = await saved(3, pinned: false)

        try await engine.overwriteSavedFeeds([a, b, c, d])

        let feeds = try await savedFeeds(engine)
        #expect(feeds.filter(\.pinned) == [a, c])
        #expect(feeds.filter { !$0.pinned } == [b, d])
        #expect(feeds == [a, c, b, d])
    }

    @Test("overwriteSavedFeeds rejects a feed without an id and writes nothing")
    func overwriteValidates() async throws {
        let (engine, backend) = PrefsFixture.make()
        await #expect(throws: BskyAgentError.self) {
            try await engine.overwriteSavedFeeds([SavedFeed(id: "", type: "feed", value: feedURI(0), pinned: true)])
        }
        #expect(backend.saveCount == 0)
    }

    // MARK: updateSavedFeeds

    @Test("updateSavedFeeds: updates affect order, saved last, new pins last")
    func updateAffectsOrder() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await saved(0, pinned: true)
        let b = await saved(1, pinned: true)
        let c = await saved(2, pinned: true)
        let unpinnedB = SavedFeed(id: b.id, type: b.type, value: b.value, pinned: false)

        try await engine.overwriteSavedFeeds([a, b, c])
        try await engine.updateSavedFeeds([unpinnedB])
        #expect(try await savedFeeds(engine) == [a, c, unpinnedB])

        try await engine.updateSavedFeeds([b])
        #expect(try await savedFeeds(engine) == [a, c, b])
    }

    @Test("updateSavedFeeds cannot override original id")
    func updateCannotOverrideID() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await saved(0, pinned: true)
        try await engine.overwriteSavedFeeds([a])
        try await engine.updateSavedFeeds([
            SavedFeed(id: TIDGenerator.next(), type: a.type, value: a.value, pinned: false),
        ])

        #expect(try await savedFeeds(engine) == [a])
    }

    @Test("updateSavedFeeds updates multiple")
    func updateMultiple() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await saved(0, pinned: false)
        let b = await saved(1, pinned: false)
        let c = await saved(2, pinned: false)
        let pinnedB = SavedFeed(id: b.id, type: b.type, value: b.value, pinned: true)
        let pinnedC = SavedFeed(id: c.id, type: c.type, value: c.value, pinned: true)

        try await engine.overwriteSavedFeeds([a, b, c])
        try await engine.updateSavedFeeds([pinnedB, pinnedC])

        #expect(try await savedFeeds(engine) == [pinnedB, pinnedC, a])
    }

    @Test("updateSavedFeeds only changes the pinned state")
    func updateOnlyPins() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = await saved(0, pinned: false)
        try await engine.overwriteSavedFeeds([a])
        try await engine.updateSavedFeeds([SavedFeed(id: a.id, type: "list", value: listURI(9), pinned: true)])

        #expect(try await savedFeeds(engine) == [SavedFeed(id: a.id, type: "feed", value: feedURI(0), pinned: true)])
    }

    // MARK: migration scenarios

    @Test("CRUD action before migration, no timeline inserted")
    func crudBeforeMigration() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])

        #expect(try await savedFeeds(engine).map(\.signature) == ["feed|\(feedURI(0))|false"])
    }

    @Test("CRUD action AFTER migration, timeline was inserted")
    func crudAfterMigration() async throws {
        let (engine, _) = PrefsFixture.make()
        _ = try await engine.getPreferences()
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])

        #expect(try await savedFeeds(engine).map(\.signature) == [timeline, "feed|\(feedURI(0))|false"])
    }

    @Test("brand new user, v1 remains undefined")
    func brandNewUser() async throws {
        let (engine, backend) = PrefsFixture.make()
        let prefs = try await engine.getPreferences()

        #expect(prefs.savedFeeds.map(\.signature) == [timeline])
        // no v1 prefs to populate from
        #expect(prefs.feeds == BskyPreferences.LegacyFeeds(saved: nil, pinned: nil))
        #expect(backend.entries(ofType: "app.bsky.actor.defs#savedFeedsPref").isEmpty)
    }

    @Test("the migration is written once; a second read reuses it")
    func migrationHappensOnce() async throws {
        let (engine, backend) = PrefsFixture.make()
        let first = try await engine.getPreferences()
        let second = try await engine.getPreferences()

        #expect(backend.saveCount == 1)
        #expect(first.savedFeeds == second.savedFeeds)
    }

    @Test("brand new user, v2 does not write to v1")
    func v2DoesNotCreateV1() async throws {
        let (engine, backend) = PrefsFixture.make()
        // migration happens
        _ = try await engine.getPreferences()
        try await engine.addSavedFeeds([newFeed(0, pinned: false)])

        let prefs = try await engine.getPreferences()
        #expect(prefs.savedFeeds.map(\.signature) == [timeline, "feed|\(feedURI(0))|false"])
        // no v1 prefs to populate from
        #expect(prefs.feeds == BskyPreferences.LegacyFeeds(saved: nil, pinned: nil))
        #expect(backend.entries(ofType: "app.bsky.actor.defs#savedFeedsPref").isEmpty)
    }

    @Test("existing user with v1 prefs, migrates")
    func migratesV1() async throws {
        let one = feedURI(0)
        let two = feedURI(1)
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries("""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": ["\(one)"], "saved": ["\(one)", "\(two)"]}]
        """))

        let prefs = try await engine.getPreferences()

        // deprecated interface receives what it normally would
        #expect(try prefs.feeds == BskyPreferences.LegacyFeeds(
            saved: [PrefsFixture.uri(one), PrefsFixture.uri(two)],
            pinned: [PrefsFixture.uri(one)]
        ))
        // new interface gets new timeline + old pinned feed
        #expect(prefs.savedFeeds.map(\.signature) == [timeline, "feed|\(one)|true", "feed|\(two)|false"])
        #expect(Set(prefs.savedFeeds.map(\.id)).count == 3)
    }

    @Test("migrates lists as lists")
    func migratesLists() async throws {
        let list = listURI(0)
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries("""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": ["\(list)"]}]
        """))

        #expect(try await savedFeeds(engine).map(\.signature) == [timeline, "list|\(list)|false"])
    }

    @Test("squashes duplicates during migration")
    func squashesDuplicates() async throws {
        let one = feedURI(0)
        let two = feedURI(1)
        let (engine, backend) = try PrefsFixture.make(PrefsFixture.entries("""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": ["\(one)", "\(two)"], "saved": ["\(one)", "\(two)"]},
         {"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": []}]
        """))

        // performs migration
        let prefs = try await engine.getPreferences()
        #expect(prefs.feeds == BskyPreferences.LegacyFeeds(saved: [], pinned: []))
        #expect(prefs.savedFeeds.map(\.signature) == [timeline])

        let raw = backend.preferences
        #expect(raw.count == 2)
        #expect(raw.first?.typeIdentifier == "app.bsky.actor.defs#savedFeedsPrefV2")
        #expect(raw.first?["items"]?.arrayValue?.count == 1)
        #expect(try raw.last == PrefsFixture.json(
            #"{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": []}"#
        ))
    }

    @Test("v2 writes persist to v1, not the inverse")
    func v2WritesMirrorToV1() async throws {
        let (a, b, c, d, e) = (feedURI(0), feedURI(1), feedURI(2), feedURI(3), feedURI(4))
        let (engine, backend) = try PrefsFixture.make(PrefsFixture.entries("""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": ["\(a)", "\(b)"], "saved": ["\(a)", "\(b)"]}]
        """))
        func v1() throws -> BskyJSON {
            try #require(backend.entries(ofType: "app.bsky.actor.defs#savedFeedsPref").first)
        }
        func strings(_ json: BskyJSON?) -> [String] {
            (json?.arrayValue ?? []).compactMap(\.stringValue)
        }

        // client updates, migrates to v2
        // a and b are both pinned
        _ = try await engine.getPreferences()

        // new write to v2, c is saved
        try await engine.addSavedFeeds([BskyNewSavedFeed(type: "feed", value: c, pinned: false)])

        // v2 write wrote to v1 also
        #expect(try strings(v1()["pinned"]) == [a, b])
        #expect(try strings(v1()["saved"]) == [a, b, c])

        // v1 write occurs, d is added but not to v2
        try await engine.addSavedFeed(PrefsFixture.uri(d))
        #expect(try strings(v1()["pinned"]) == [a, b])
        #expect(try strings(v1()["saved"]) == [a, b, c, d])

        // another new write to v2, pins e
        try await engine.addSavedFeeds([BskyNewSavedFeed(type: "feed", value: e, pinned: true)])

        // v1 pref got v2 write
        #expect(try strings(v1()["pinned"]) == [a, b, e])
        #expect(try strings(v1()["saved"]) == [a, b, c, d, e])
        #expect(backend.entries(ofType: "app.bsky.actor.defs#savedFeedsPref").count == 1)

        // d not here bc it was written with v1
        #expect(try await savedFeeds(engine).map(\.signature) == [
            timeline,
            "feed|\(a)|true",
            "feed|\(b)|true",
            "feed|\(e)|true",
            "feed|\(c)|false",
        ])
    }

    @Test("timelines are not mirrored into v1")
    func timelinesAreNotMirrored() async throws {
        let (engine, backend) = try PrefsFixture.make(PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": []}]"#
        ))
        try await engine.addSavedFeeds([.timeline(pinned: true)])

        #expect(try backend.entries(ofType: "app.bsky.actor.defs#savedFeedsPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": []}]"#
        ))
    }

    @Test("filters out invalid values in v1 prefs")
    func filtersUnsupportedV1Values() async throws {
        // v1 prefs must be valid AtUris, but they could be any type in theory
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref",
          "pinned": ["at://did:plc:fake/app.bsky.graph.follow/fake"],
          "saved": ["at://did:plc:fake/app.bsky.graph.follow/fake"]}]
        """#))

        #expect(try await savedFeeds(engine).map(\.signature) == [timeline])
    }

    @Test("a v1 entry holding something that is not an AT URI is not a valid entry and is ignored")
    func invalidV1EntryIsIgnored() async throws {
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": ["https://example.com"], "saved": []}]
        """#))

        let prefs = try await engine.getPreferences()
        #expect(prefs.feeds == BskyPreferences.LegacyFeeds(saved: nil, pinned: nil))
        #expect(prefs.savedFeeds.map(\.signature) == [timeline])
    }
}
