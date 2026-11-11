import Foundation
@testable import Petrel
import Testing

/// Ports of `preferences methods` in `packages/api/tests/atp-agent.test.ts`
/// ("gets and sets preferences correctly", "resolves duplicates correctly")
/// and of `packages/api/tests/moderation-prefs.test.ts`.
@Suite("BskyPreferences get and set")
struct BskyPreferencesGetSetTests {
    private let fake = "at://bob.com/app.bsky.feed.generator/fake"
    private let fake2 = "at://bob.com/app.bsky.feed.generator/fake2"

    private func read(_ engine: BskyPreferencesEngine) async throws -> BskyPreferences {
        try await engine.getPreferences().ignoringSavedFeedIDs
    }

    @Test("gets and sets preferences correctly")
    func getsAndSets() async throws {
        let (engine, _) = PrefsFixture.make()
        var expected = PrefsFixture.defaults()

        #expect(try await read(engine) == expected)

        try await engine.setAdultContentEnabled(true)
        expected.moderationPrefs.adultContentEnabled = true
        #expect(try await read(engine) == expected)

        try await engine.setAdultContentEnabled(false)
        expected.moderationPrefs.adultContentEnabled = false
        #expect(try await read(engine) == expected)

        try await engine.setContentLabelPref("misinfo", .hide)
        expected.moderationPrefs.labels["misinfo"] = .hide
        #expect(try await read(engine) == expected)

        try await engine.setContentLabelPref("spam", .ignore)
        expected.moderationPrefs.labels["spam"] = .ignore
        #expect(try await read(engine) == expected)

        let fakeURI = try PrefsFixture.uri(fake)
        let fake2URI = try PrefsFixture.uri(fake2)

        try await engine.addSavedFeed(fakeURI)
        expected.feeds = .init(saved: [fakeURI], pinned: [])
        #expect(try await read(engine) == expected)

        try await engine.addPinnedFeed(fakeURI)
        expected.feeds = .init(saved: [fakeURI], pinned: [fakeURI])
        #expect(try await read(engine) == expected)

        try await engine.removePinnedFeed(fakeURI)
        expected.feeds = .init(saved: [fakeURI], pinned: [])
        #expect(try await read(engine) == expected)

        try await engine.removeSavedFeed(fakeURI)
        expected.feeds = .init(saved: [], pinned: [])
        #expect(try await read(engine) == expected)

        try await engine.addPinnedFeed(fakeURI)
        expected.feeds = .init(saved: [fakeURI], pinned: [fakeURI])
        #expect(try await read(engine) == expected)

        try await engine.addPinnedFeed(fake2URI)
        expected.feeds = .init(saved: [fakeURI, fake2URI], pinned: [fakeURI, fake2URI])
        #expect(try await read(engine) == expected)

        try await engine.removeSavedFeed(fakeURI)
        expected.feeds = .init(saved: [fake2URI], pinned: [fake2URI])
        #expect(try await read(engine) == expected)

        let birthDate = try PrefsFixture.date("2023-09-11T18:05:42.556Z")
        try await engine.setPersonalDetails(birthDate: birthDate)
        var afterBirthDate = try await read(engine)
        let storedBirthDate = try #require(afterBirthDate.birthDate)
        #expect(abs(storedBirthDate.timeIntervalSince(birthDate)) < 0.002)
        #expect(afterBirthDate.declaredAge == AppBskyActorDefs.DeclaredAgePref(
            isOverAge13: false, isOverAge16: false, isOverAge18: false
        ))
        expected.birthDate = storedBirthDate
        expected.declaredAge = afterBirthDate.declaredAge
        afterBirthDate = try await read(engine)
        #expect(afterBirthDate == expected)

        try await engine.setFeedViewPrefs(feed: "home", .init(hideReplies: true))
        expected.feedViewPrefs["home"]?.hideReplies = true
        #expect(try await read(engine) == expected)

        try await engine.setFeedViewPrefs(feed: "home", .init(hideReplies: false))
        expected.feedViewPrefs["home"]?.hideReplies = false
        #expect(try await read(engine) == expected)

        try await engine.setFeedViewPrefs(feed: "other", .init(hideReplies: true))
        expected.feedViewPrefs["other"] = BskyFeedViewPreference(hideReplies: true)
        #expect(try await read(engine) == expected)

        try await engine.setThreadViewPrefs(sort: "random")
        expected.threadViewPrefs.sort = "random"
        #expect(try await read(engine) == expected)

        try await engine.setThreadViewPrefs(sort: "oldest")
        expected.threadViewPrefs.sort = "oldest"
        #expect(try await read(engine) == expected)

        try await engine.setInterestsPref(tags: ["foo", "bar"])
        expected.interests.tags = ["foo", "bar"]
        #expect(try await read(engine) == expected)
    }

    @Test("resolves duplicates correctly")
    func resolvesDuplicates() async throws {
        let (engine, backend) = PrefsFixture.make()
        try backend.put(PrefsFixture.entries(#"""
        [
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "show"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "hide"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "show"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "warn"},
          {"$type": "app.bsky.actor.defs#labelersPref", "labelers": [{"did": "did:plc:first-labeler"}]},
          {"$type": "app.bsky.actor.defs#labelersPref",
           "labelers": [{"did": "did:plc:first-labeler"}, {"did": "did:plc:other"}]},
          {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": true},
          {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": false},
          {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": true},
          {"$type": "app.bsky.actor.defs#savedFeedsPref",
           "pinned": ["at://bob.com/app.bsky.feed.generator/fake", "at://bob.com/app.bsky.feed.generator/fake2"],
           "saved": ["at://bob.com/app.bsky.feed.generator/fake", "at://bob.com/app.bsky.feed.generator/fake2"]},
          {"$type": "app.bsky.actor.defs#savedFeedsPref", "pinned": [], "saved": []},
          {"$type": "app.bsky.actor.defs#personalDetailsPref", "birthDate": "2023-09-11T18:05:42.556Z"},
          {"$type": "app.bsky.actor.defs#personalDetailsPref", "birthDate": "2021-09-11T18:05:42.556Z"},
          {"$type": "app.bsky.actor.defs#declaredAgePref",
           "isOverAge13": false, "isOverAge16": false, "isOverAge18": false},
          {"$type": "app.bsky.actor.defs#feedViewPref", "feed": "home", "hideReplies": false,
           "hideRepliesByUnfollowed": true, "hideRepliesByLikeCount": 0, "hideReposts": false,
           "hideQuotePosts": false},
          {"$type": "app.bsky.actor.defs#feedViewPref", "feed": "home", "hideReplies": true,
           "hideRepliesByUnfollowed": false, "hideRepliesByLikeCount": 10, "hideReposts": true,
           "hideQuotePosts": true},
          {"$type": "app.bsky.actor.defs#threadViewPref", "sort": "oldest"},
          {"$type": "app.bsky.actor.defs#threadViewPref", "sort": "newest"},
          {"$type": "app.bsky.actor.defs#bskyAppStatePref", "queuedNudges": ["one"]},
          {"$type": "app.bsky.actor.defs#bskyAppStatePref", "queuedNudges": ["two"]}
        ]
        """#))

        let firstLabeler = try PrefsFixture.did("did:plc:first-labeler")
        let other = try PrefsFixture.did("did:plc:other")
        let declaredMinor = AppBskyActorDefs.DeclaredAgePref(
            isOverAge13: false, isOverAge16: false, isOverAge18: false
        )

        var expected = PrefsFixture.defaults()
        expected.feeds = .init(saved: [], pinned: [])
        expected.moderationPrefs.adultContentEnabled = true
        expected.moderationPrefs.labels["porn"] = .warn
        expected.moderationPrefs.labelers += [
            ModerationPrefsLabeler(did: firstLabeler),
            ModerationPrefsLabeler(did: other),
        ]
        expected.birthDate = try PrefsFixture.date("2021-09-11T18:05:42.556Z")
        expected.declaredAge = declaredMinor
        expected.feedViewPrefs["home"] = BskyFeedViewPreference(
            hideReplies: true,
            hideRepliesByUnfollowed: false,
            hideRepliesByLikeCount: 10,
            hideReposts: true,
            hideQuotePosts: true
        )
        expected.threadViewPrefs.sort = "newest"
        expected.bskyAppState.queuedNudges = ["two"]
        #expect(try await read(engine) == expected)

        try await engine.setAdultContentEnabled(false)
        expected.moderationPrefs.adultContentEnabled = false
        #expect(try await read(engine) == expected)

        try await engine.setContentLabelPref("porn", .ignore)
        expected.moderationPrefs.labels["porn"] = .ignore
        expected.moderationPrefs.labels["nsfw"] = .ignore
        #expect(try await read(engine) == expected)

        try await engine.removeLabeler(other)
        expected.moderationPrefs.labelers.removeAll { $0.did == other }
        #expect(try await read(engine) == expected)

        let fakeURI = try PrefsFixture.uri(fake)
        try await engine.addPinnedFeed(fakeURI)
        expected.feeds = .init(saved: [fakeURI], pinned: [fakeURI])
        #expect(try await read(engine) == expected)

        let newBirthDate = try PrefsFixture.date("2023-09-11T18:05:42.556Z")
        try await engine.setPersonalDetails(birthDate: newBirthDate)
        let afterBirthDate = try await read(engine)
        let storedBirthDate = try #require(afterBirthDate.birthDate)
        #expect(abs(storedBirthDate.timeIntervalSince(newBirthDate)) < 0.002)
        expected.birthDate = storedBirthDate
        #expect(afterBirthDate == expected)

        try await engine.setFeedViewPrefs(feed: "home", .init(
            hideReplies: false,
            hideRepliesByUnfollowed: true,
            hideRepliesByLikeCount: 0,
            hideReposts: false,
            hideQuotePosts: false
        ))
        try await engine.setThreadViewPrefs(sort: "oldest")
        try await engine.setPersonalDetails(birthDate: newBirthDate)
        try await engine.bskyAppQueueNudges(["three"])
        expected.feedViewPrefs["home"] = BskyFeedViewPreference()
        expected.threadViewPrefs.sort = "oldest"
        expected.bskyAppState.queuedNudges = ["two", "three"]
        #expect(try await read(engine) == expected)

        // The stored array holds exactly one entry of each kind that was written.
        let raw = backend.preferences
        func entries(_ type: String) -> [BskyJSON] {
            raw.filter { $0.typeIdentifier == type }
        }
        #expect(raw.count == 11)
        #expect(try entries("app.bsky.actor.defs#bskyAppStatePref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#bskyAppStatePref", "queuedNudges": ["two", "three"]}]"#
        ))
        #expect(try entries("app.bsky.actor.defs#adultContentPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#adultContentPref", "enabled": false}]"#
        ))
        #expect(try entries("app.bsky.actor.defs#contentLabelPref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "ignore"},
         {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "nsfw", "visibility": "ignore"}]
        """#))
        #expect(try entries("app.bsky.actor.defs#labelersPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#labelersPref", "labelers": [{"did": "did:plc:first-labeler"}]}]"#
        ))
        #expect(try entries("app.bsky.actor.defs#savedFeedsPref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#savedFeedsPref",
          "pinned": ["at://bob.com/app.bsky.feed.generator/fake"],
          "saved": ["at://bob.com/app.bsky.feed.generator/fake"]}]
        """#))
        let v2 = entries("app.bsky.actor.defs#savedFeedsPrefV2")
        #expect(v2.count == 1)
        let v2Items = try #require(v2.first?["items"]?.arrayValue)
        #expect(v2Items.count == 1)
        #expect(v2Items.first?["type"]?.stringValue == "timeline")
        #expect(v2Items.first?["value"]?.stringValue == "following")
        #expect(v2Items.first?["pinned"]?.boolValue == true)
        #expect(v2Items.first?["id"]?.stringValue?.isEmpty == false)
        let details = entries("app.bsky.actor.defs#personalDetailsPref")
        #expect(details.count == 1)
        #expect(details.first?.objectValue?.keys.sorted() == ["$type", "birthDate"])
        #expect(try entries("app.bsky.actor.defs#declaredAgePref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#declaredAgePref",
          "isOverAge13": false, "isOverAge16": false, "isOverAge18": false}]
        """#))
        #expect(try entries("app.bsky.actor.defs#feedViewPref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#feedViewPref", "feed": "home", "hideReplies": false,
          "hideRepliesByUnfollowed": true, "hideRepliesByLikeCount": 0, "hideReposts": false,
          "hideQuotePosts": false}]
        """#))
        #expect(try entries("app.bsky.actor.defs#threadViewPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#threadViewPref", "sort": "oldest"}]"#
        ))
    }

    // MARK: moderation-prefs.test.ts

    @Test("migrates legacy content-label prefs (no mutations)")
    func migratesLegacyContentLabelPrefs() async throws {
        let seed = try PrefsFixture.entries(#"""
        [
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn", "visibility": "show"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "nudity", "visibility": "show"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "sexual", "visibility": "show"},
          {"$type": "app.bsky.actor.defs#contentLabelPref", "label": "graphic-media", "visibility": "show"}
        ]
        """#)
        let (engine, backend) = PrefsFixture.make(seed)

        var expected = PrefsFixture.defaults()
        expected.moderationPrefs.labels = [
            "porn": .ignore,
            "nudity": .ignore,
            "sexual": .ignore,
            "graphic-media": .ignore,
        ]
        #expect(try await read(engine) == expected)

        // Reading does not rewrite the legacy entries.
        #expect(backend.entries(ofType: "app.bsky.actor.defs#contentLabelPref") == seed)
    }

    @Test("adds/removes moderation services")
    func addsAndRemovesLabelers() async throws {
        let (engine, backend) = PrefsFixture.make()
        let other = try PrefsFixture.did("did:plc:other")
        let app = AcceptedLabeler(did: BskyAgent.bskyLabelerDID, redact: true)

        try await engine.addLabeler(other)
        #expect(backend.configuredLabelers.last == [app, AcceptedLabeler(did: other)])

        var expected = PrefsFixture.defaults()
        expected.moderationPrefs.labelers.append(ModerationPrefsLabeler(did: other))
        #expect(try await read(engine) == expected)
        #expect(backend.configuredLabelers.last == [app, AcceptedLabeler(did: other)])

        try await engine.removeLabeler(other)
        #expect(backend.configuredLabelers.last == [app])

        expected = PrefsFixture.defaults()
        #expect(try await read(engine) == expected)
        #expect(backend.configuredLabelers.last == [app])
    }

    @Test("adding a labeler twice stores it once")
    func addLabelerIsIdempotent() async throws {
        let (engine, backend) = PrefsFixture.make()
        let other = try PrefsFixture.did("did:plc:other")
        try await engine.addLabeler(other)
        try await engine.addLabeler(other)
        #expect(try backend.entries(ofType: "app.bsky.actor.defs#labelersPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#labelersPref", "labelers": [{"did": "did:plc:other"}]}]"#
        ))
    }

    @Test("sets label preferences globally and per-moderator")
    func setsLabelPreferencesGloballyAndPerLabeler() async throws {
        let (engine, _) = PrefsFixture.make()
        let other = try PrefsFixture.did("did:plc:other")

        try await engine.addLabeler(other)
        try await engine.setContentLabelPref("porn", .ignore)
        try await engine.setContentLabelPref("porn", .hide, labelerDid: other)
        try await engine.setContentLabelPref("x-custom", .warn, labelerDid: other)

        var expected = PrefsFixture.defaults()
        expected.moderationPrefs.labels["porn"] = .ignore
        expected.moderationPrefs.labels["nsfw"] = .ignore
        expected.moderationPrefs.labelers.append(
            ModerationPrefsLabeler(did: other, labels: ["porn": .hide, "x-custom": .warn])
        )
        #expect(try await read(engine) == expected)
    }

    @Test("a per-labeler setting for a labeler the user does not subscribe to is not applied")
    func labelPrefForUnsubscribedLabelerIsIgnored() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.setContentLabelPref("porn", .hide, labelerDid: PrefsFixture.did("did:plc:other"))
        #expect(try await read(engine) == PrefsFixture.defaults())
    }

    @Test("updates label pref")
    func updatesLabelPref() async throws {
        let (engine, backend) = PrefsFixture.make()
        let other = try PrefsFixture.did("did:plc:other")

        try await engine.addLabeler(other)
        try await engine.setContentLabelPref("porn", .ignore)
        try await engine.setContentLabelPref("porn", .ignore, labelerDid: other)
        try await engine.setContentLabelPref("porn", .hide)
        try await engine.setContentLabelPref("porn", .hide, labelerDid: other)

        let prefs = try await engine.getPreferences()
        #expect(prefs.moderationPrefs.labels["porn"] == .hide)
        #expect(prefs.moderationPrefs.labelers.first { $0.did == other }?.labels["porn"] == .hide)

        // One global entry, its legacy twin, and one per-labeler entry.
        #expect(backend.entries(ofType: "app.bsky.actor.defs#contentLabelPref").count == 3)
    }

    @Test(
        "double-write for legacy: current label stays in sync with its retired name",
        arguments: [("graphic-media", "gore"), ("porn", "nsfw"), ("sexual", "suggestive")]
    )
    func legacyDoubleWrite(current: String, legacy: String) async throws {
        let (engine, _) = PrefsFixture.make()

        try await engine.setContentLabelPref(current, .hide)
        let a = try await engine.getPreferences()
        #expect(a.moderationPrefs.labels[legacy] == .hide)
        #expect(a.moderationPrefs.labels[current] == .hide)

        try await engine.setContentLabelPref(current, .warn)
        let b = try await engine.getPreferences()
        #expect(b.moderationPrefs.labels[legacy] == .warn)
        #expect(b.moderationPrefs.labels[current] == .warn)
    }

    @Test("double-write for legacy: filters out existing old label pref if double-written")
    func legacyDoubleWriteFiltersExisting() async throws {
        let (engine, backend) = PrefsFixture.make()

        try await engine.setContentLabelPref("nsfw", .hide)
        try await engine.setContentLabelPref("porn", .hide)

        let nsfw = backend.entries(ofType: "app.bsky.actor.defs#contentLabelPref")
            .filter { $0["label"]?.stringValue == "nsfw" }
        #expect(nsfw.count == 1)
    }

    @Test("a per-labeler setting is not double-written under the retired name")
    func perLabelerSettingHasNoLegacyTwin() async throws {
        let (engine, backend) = PrefsFixture.make()
        try await engine.setContentLabelPref("porn", .hide, labelerDid: PrefsFixture.did("did:plc:other"))
        #expect(try backend.entries(ofType: "app.bsky.actor.defs#contentLabelPref") == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#contentLabelPref", "label": "porn",
          "labelerDid": "did:plc:other", "visibility": "hide"}]
        """#))
    }

    @Test("remaps old values to new on read")
    func remapsLegacyLabelsOnRead() async throws {
        let (engine, _) = PrefsFixture.make()

        try await engine.setContentLabelPref("nsfw", .hide)
        try await engine.setContentLabelPref("gore", .hide)
        try await engine.setContentLabelPref("suggestive", .hide)

        let prefs = try await engine.getPreferences()
        #expect(prefs.moderationPrefs.labels["porn"] == .hide)
        #expect(prefs.moderationPrefs.labels["graphic-media"] == .hide)
        #expect(prefs.moderationPrefs.labels["sexual"] == .hide)
    }
}
