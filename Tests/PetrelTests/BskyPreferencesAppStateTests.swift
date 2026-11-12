import Foundation
@testable import Petrel
import Testing

/// Ports of `queued nudges`, `guided tours`, `beta user`, `nuxs`,
/// `setPostInteractionSettings`, `setVerificationPrefs` and
/// `updateLiveEventPreferences` in `packages/api/tests/atp-agent.test.ts`.
@Suite("BskyPreferences app state and display")
struct BskyPreferencesAppStateTests {
    private let appState = "app.bsky.actor.defs#bskyAppStatePref"

    // MARK: queued nudges

    @Test("queueNudges & dismissNudges")
    func nudges() async throws {
        let (engine, _) = PrefsFixture.make()

        try await engine.bskyAppQueueNudges(["first"])
        #expect(try await engine.getPreferences().bskyAppState.queuedNudges == ["first"])

        try await engine.bskyAppQueueNudges(["second", "third"])
        #expect(try await engine.getPreferences().bskyAppState.queuedNudges == ["first", "second", "third"])

        try await engine.bskyAppDismissNudges(["second"])
        #expect(try await engine.getPreferences().bskyAppState.queuedNudges == ["first", "third"])

        try await engine.bskyAppDismissNudges(["first", "third"])
        #expect(try await engine.getPreferences().bskyAppState.queuedNudges == [])
    }

    // MARK: guided tours

    @Test("setActiveProgressGuide keeps unspecced fields")
    func progressGuide() async throws {
        let (engine, backend) = PrefsFixture.make()

        try await engine.bskyAppSetActiveProgressGuide(
            BskyAppProgressGuide(guide: "test-guide", additionalFields: ["numThings": .number(0)])
        )
        #expect(try await engine.getPreferences().bskyAppState.activeProgressGuide?.guide == "test-guide")

        try await engine.bskyAppSetActiveProgressGuide(
            BskyAppProgressGuide(guide: "test-guide", additionalFields: ["numThings": .number(1)])
        )
        let guide = try #require(try await engine.getPreferences().bskyAppState.activeProgressGuide)
        #expect(guide.guide == "test-guide")
        #expect(guide.additionalFields == ["numThings": .number(1)])
        #expect(try backend.entries(ofType: appState) == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#bskyAppStatePref",
          "activeProgressGuide": {"guide": "test-guide", "numThings": 1}}]
        """#))

        try await engine.bskyAppSetActiveProgressGuide(nil)
        #expect(try await engine.getPreferences().bskyAppState.activeProgressGuide == nil)
        #expect(try backend.entries(ofType: appState) == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#bskyAppStatePref"}]"#
        ))
    }

    @Test("setActiveProgressGuide validates the guide name")
    func progressGuideValidates() async throws {
        let (engine, backend) = PrefsFixture.make()
        await #expect(throws: BskyAgentError.self) {
            try await engine.bskyAppSetActiveProgressGuide(
                BskyAppProgressGuide(guide: String(repeating: "g", count: 101))
            )
        }
        #expect(backend.saveCount == 0)
    }

    // MARK: beta user

    @Test("setIsBetaUser")
    func betaUser() async throws {
        let (engine, _) = PrefsFixture.make()

        // unset by default
        #expect(try await engine.getPreferences().bskyAppState.isBetaUser == nil)

        try await engine.setIsBetaUser(true)
        #expect(try await engine.getPreferences().bskyAppState.isBetaUser == true)

        try await engine.setIsBetaUser(false)
        #expect(try await engine.getPreferences().bskyAppState.isBetaUser == false)
    }

    @Test("setIsBetaUser preserves other bskyAppState fields")
    func betaUserPreservesOtherFields() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.bskyAppQueueNudges(["keepme"])
        try await engine.setIsBetaUser(true)

        let prefs = try await engine.getPreferences()
        #expect(prefs.bskyAppState.isBetaUser == true)
        #expect(prefs.bskyAppState.queuedNudges == ["keepme"])
    }

    // MARK: nuxs

    @Test("bskyAppUpsertNux never duplicates; completed updates; remove removes")
    func nuxs() async throws {
        let (engine, _) = PrefsFixture.make()
        let expiresAt = ATProtocolDate(date: Date(timeIntervalSince1970: 1_900_000_000))
        let nux = AppBskyActorDefs.Nux(id: "a", completed: false, data: "{}", expiresAt: expiresAt)

        // never duplicates
        try await engine.bskyAppUpsertNux(nux)
        try await engine.bskyAppUpsertNux(nux)
        try await engine.bskyAppUpsertNux(nux)
        #expect(try await engine.getPreferences().bskyAppState.nuxs == [nux])

        try await engine.bskyAppUpsertNux(
            AppBskyActorDefs.Nux(id: "a", completed: true, data: "{}", expiresAt: expiresAt)
        )
        let completed = try await engine.getPreferences().bskyAppState.nuxs
        #expect(completed.count == 1)
        #expect(completed.first?.completed == true)

        try await engine.bskyAppRemoveNuxs(ids: ["a"])
        #expect(try await engine.getPreferences().bskyAppState.nuxs.isEmpty)
    }

    @Test("bskyAppUpsertNux replaces in place of the old entry and appends")
    func nuxOrder() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.bskyAppUpsertNux(AppBskyActorDefs.Nux(id: "a", completed: false))
        try await engine.bskyAppUpsertNux(AppBskyActorDefs.Nux(id: "b", completed: false))
        try await engine.bskyAppUpsertNux(AppBskyActorDefs.Nux(id: "a", completed: true))

        #expect(try await engine.getPreferences().bskyAppState.nuxs.map(\.id) == ["b", "a"])
    }

    @Test("bskyAppUpsertNux validates nux")
    func nuxValidates() async throws {
        let (engine, backend) = PrefsFixture.make()
        await #expect(throws: BskyAgentError.self) {
            try await engine.bskyAppUpsertNux(
                AppBskyActorDefs.Nux(id: String(repeating: "i", count: 65), completed: false)
            )
        }
        await #expect(throws: BskyAgentError.self) {
            try await engine.bskyAppUpsertNux(
                AppBskyActorDefs.Nux(id: "a", completed: false, data: String(repeating: "d", count: 301))
            )
        }
        #expect(backend.saveCount == 0)

        try await engine.bskyAppUpsertNux(AppBskyActorDefs.Nux(
            id: String(repeating: "i", count: 64),
            completed: false,
            data: String(repeating: "d", count: 300)
        ))
        #expect(backend.saveCount == 1)
    }

    // MARK: setPostInteractionSettings

    @Test("setPostInteractionSettings works, clears, and clears using nil")
    func postInteractionSettings() async throws {
        let (engine, backend) = PrefsFixture.make()
        let type = "app.bsky.actor.defs#postInteractionSettingsPref"

        let rules = AppBskyActorDefs.PostInteractionSettingsPref(
            threadgateAllowRules: [.appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule())],
            postgateEmbeddingRules: []
        )
        try await engine.setPostInteractionSettings(rules)
        #expect(try await engine.getPreferences().postInteractionSettings == rules)
        #expect(try backend.entries(ofType: type) == PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#postInteractionSettingsPref",
          "threadgateAllowRules": [{"$type": "app.bsky.feed.threadgate#mentionRule"}],
          "postgateEmbeddingRules": []}]
        """#))

        let empty = AppBskyActorDefs.PostInteractionSettingsPref(threadgateAllowRules: [], postgateEmbeddingRules: [])
        try await engine.setPostInteractionSettings(empty)
        #expect(try await engine.getPreferences().postInteractionSettings == empty)

        // `nil` means "anyone can reply"; it is stored as an absent key.
        let cleared = AppBskyActorDefs.PostInteractionSettingsPref(threadgateAllowRules: nil, postgateEmbeddingRules: nil)
        try await engine.setPostInteractionSettings(cleared)
        #expect(try await engine.getPreferences().postInteractionSettings == cleared)
        #expect(try backend.entries(ofType: type) == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#postInteractionSettingsPref"}]"#
        ))
    }

    @Test("setPostInteractionSettings validates inputs")
    func postInteractionSettingsValidates() async throws {
        let (engine, backend) = PrefsFixture.make()

        // A rule that does not name its $type.
        await #expect(throws: BskyAgentError.self) {
            try await engine.setPostInteractionSettings(AppBskyActorDefs.PostInteractionSettingsPref(
                threadgateAllowRules: [.unexpected(.object(["key": .string("string")]))],
                postgateEmbeddingRules: []
            ))
        }
        // More rules than the lexicon allows.
        await #expect(throws: BskyAgentError.self) {
            try await engine.setPostInteractionSettings(AppBskyActorDefs.PostInteractionSettingsPref(
                threadgateAllowRules: Array(
                    repeating: .appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule()),
                    count: 6
                ),
                postgateEmbeddingRules: nil
            ))
        }
        #expect(backend.saveCount == 0)
    }

    // MARK: setVerificationPrefs

    @Test("setVerificationPrefs: default state, then updates")
    func verificationPrefs() async throws {
        let (engine, _) = PrefsFixture.make()
        #expect(try await engine.getPreferences().verificationPrefs
            == AppBskyActorDefs.VerificationPrefs(hideBadges: false))

        try await engine.setVerificationPrefs(hideBadges: true)
        #expect(try await engine.getPreferences().verificationPrefs
            == AppBskyActorDefs.VerificationPrefs(hideBadges: true))
    }

    // MARK: updateLiveEventPreferences

    @Test("updateLiveEventPreferences: hide, hide another, unhide, toggle, toggle back")
    func liveEventPreferences() async throws {
        let (engine, _) = PrefsFixture.make()
        func current() async throws -> BskyLiveEventPreferences {
            try await engine.getPreferences().liveEventPreferences
        }

        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: [], hideAllFeeds: false))

        let afterFirst = try await engine.updateLiveEventPreferences(.hideFeed(id: "feed1"))
        #expect(afterFirst == BskyLiveEventPreferences(hiddenFeedIds: ["feed1"], hideAllFeeds: false))
        #expect(try await current() == afterFirst)

        try await engine.updateLiveEventPreferences(.hideFeed(id: "feed2"))
        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: ["feed1", "feed2"], hideAllFeeds: false))

        try await engine.updateLiveEventPreferences(.hideFeed(id: "feed2"))
        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: ["feed1", "feed2"], hideAllFeeds: false))

        try await engine.updateLiveEventPreferences(.unhideFeed(id: "feed1"))
        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: ["feed2"], hideAllFeeds: false))

        try await engine.updateLiveEventPreferences(.toggleHideAllFeeds)
        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: ["feed2"], hideAllFeeds: true))

        try await engine.updateLiveEventPreferences(.toggleHideAllFeeds)
        #expect(try await current() == BskyLiveEventPreferences(hiddenFeedIds: ["feed2"], hideAllFeeds: false))
    }

    // MARK: personal details

    @Test("setPersonalDetails stores an ISO 8601 datetime and nil withdraws it")
    func personalDetails() async throws {
        let (engine, backend) = PrefsFixture.make()
        let type = "app.bsky.actor.defs#personalDetailsPref"

        try await engine.setPersonalDetails(birthDate: Date(timeIntervalSince1970: 631_152_000))
        #expect(try backend.entries(ofType: type) == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#personalDetailsPref", "birthDate": "1990-01-01T00:00:00.000Z"}]"#
        ))
        let prefs = try await engine.getPreferences()
        #expect(prefs.birthDate == Date(timeIntervalSince1970: 631_152_000))
        #expect(prefs.declaredAge == AppBskyActorDefs.DeclaredAgePref(
            isOverAge13: true, isOverAge16: true, isOverAge18: true
        ))

        try await engine.setPersonalDetails(birthDate: nil)
        #expect(try backend.entries(ofType: type) == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#personalDetailsPref"}]"#
        ))
        let withdrawn = try await engine.getPreferences()
        #expect(withdrawn.birthDate == nil)
        #expect(withdrawn.declaredAge == nil)
    }
}
