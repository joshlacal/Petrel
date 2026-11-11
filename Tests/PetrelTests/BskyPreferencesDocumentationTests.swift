import Foundation
@testable import Petrel
import Testing

/// Keeps the preferences usage example honest.
///
/// `publicAPIExample` is the snippet as a caller writes it against
/// ``BskyAgent``; it is type-checked on every build. The test below runs the
/// same steps through the engine those public methods forward to, against the
/// in-memory store, and checks what they leave behind.
@Suite("BskyPreferences documentation example")
struct BskyPreferencesDocumentationTests {
    /// The example shown in the documentation. Compiled, not executed: the
    /// public methods need a signed-in client.
    func publicAPIExample(client: ATProtoClient) async throws {
        // Read everything at once.
        let prefs = try await client.bsky.getPreferences()
        let pinnedFeeds = prefs.savedFeeds.filter(\.pinned)
        let hidesReposts = prefs.feedViewPrefs["home"]?.hideReposts ?? false
        _ = (pinnedFeeds, hidesReposts)

        // Mute a word in post text and tags for a week.
        try await client.bsky.addMutedWord(
            "spoilers",
            targets: [.content, .tag],
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60)
        )

        // Hide graphic media instead of warning about it.
        try await client.bsky.setContentLabelPref("graphic-media", .hide)

        // Subscribe to a labeler and tune one of its labels.
        let labeler = try DID(didString: "did:plc:labelerexample")
        try await client.bsky.addLabeler(labeler)
        try await client.bsky.setContentLabelPref("spam", .warn, labelerDid: labeler)

        // The updated settings feed straight into moderation decisions.
        let moderationPrefs = try await client.bsky.getPreferences().moderationPrefs
        _ = moderationPrefs
    }

    @Test("read preferences, mute a word, set content label preferences")
    func example() async throws {
        let (engine, backend) = PrefsFixture.make()

        let prefs = try await engine.getPreferences()
        #expect(prefs.savedFeeds.filter(\.pinned).map(\.signature) == ["timeline|following|true"])
        #expect(prefs.feedViewPrefs["home"]?.hideReposts == false)

        let expiry = Date(timeIntervalSince1970: 1_900_000_000)
        try await engine.addMutedWord(
            value: "spoilers",
            targets: [.content, .tag],
            actorTarget: "all",
            expiresAt: ATProtocolDate(date: expiry)
        )
        try await engine.setContentLabelPref("graphic-media", .hide)

        let labeler = try DID(didString: "did:plc:labelerexample")
        try await engine.addLabeler(labeler)
        try await engine.setContentLabelPref("spam", .warn, labelerDid: labeler)

        let moderationPrefs = try await engine.getPreferences().moderationPrefs
        #expect(moderationPrefs.mutedWords.map(\.value) == ["spoilers"])
        #expect(moderationPrefs.mutedWords.first?.targets == [.content, .tag])
        #expect(moderationPrefs.mutedWords.first?.expiresAt?.date == expiry)
        #expect(moderationPrefs.labels["graphic-media"] == .hide)
        #expect(moderationPrefs.labelers == [
            ModerationPrefsLabeler(did: BskyAgent.bskyLabelerDID),
            ModerationPrefsLabeler(did: labeler, labels: ["spam": .warn]),
        ])

        // Subsequent requests ask for the app labeler (with redact) and the user's labeler.
        #expect(backend.configuredLabelers.last.map(AcceptedLabeler.headerValue(for:))
            == "did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:labelerexample")
    }

    /// Every public preference method, called once, so a signature change in
    /// the forwarding layer fails the build here. Compiled, not executed.
    func publicAPISurface(bsky: BskyAgent, uri: ATProtocolURI, did: DID, word: AppBskyActorDefs.MutedWord) async throws {
        let feeds: [AppBskyActorDefs.SavedFeed] = try await bsky.addSavedFeeds([
            .feed(uri, pinned: true), .list(uri, pinned: false), .timeline(pinned: true),
        ])
        _ = try await bsky.overwriteSavedFeeds(feeds)
        _ = try await bsky.updateSavedFeeds(feeds)
        _ = try await bsky.removeSavedFeeds(ids: feeds.map(\.id))
        let legacy: BskyPreferences.LegacyFeeds = try await bsky.setSavedFeeds(saved: [uri], pinned: [uri])
        _ = legacy
        _ = try await bsky.addSavedFeed(uri)
        _ = try await bsky.removeSavedFeed(uri)
        _ = try await bsky.addPinnedFeed(uri)
        _ = try await bsky.removePinnedFeed(uri)
        try await bsky.setAdultContentEnabled(true)
        try await bsky.setContentLabelPref("porn", .hide)
        try await bsky.setContentLabelPref("porn", .warn, labelerDid: did)
        try await bsky.addLabeler(did)
        try await bsky.removeLabeler(did)
        try await bsky.addMutedWord("word", targets: [.content])
        try await bsky.addMutedWord("word", targets: [.tag], actorTarget: "exclude-following", expiresAt: Date())
        try await bsky.addMutedWords([word])
        try await bsky.updateMutedWord(word)
        try await bsky.removeMutedWord(word)
        try await bsky.removeMutedWords([word])
        try await bsky.hidePost(uri)
        try await bsky.unhidePost(uri)
        try await bsky.setPersonalDetails(birthDate: Date())
        try await bsky.setPersonalDetails(birthDate: nil)
        try await bsky.setFeedViewPrefs(feed: "home", BskyFeedViewPreferenceUpdate(hideReposts: true))
        try await bsky.setThreadViewPrefs(sort: "newest")
        try await bsky.setInterestsPref(tags: ["swift"])
        try await bsky.setPostInteractionSettings(AppBskyActorDefs.PostInteractionSettingsPref(
            threadgateAllowRules: [.appBskyFeedThreadgateFollowingRule(AppBskyFeedThreadgate.FollowingRule())],
            postgateEmbeddingRules: [.appBskyFeedPostgateDisableRule(AppBskyFeedPostgate.DisableRule())]
        ))
        try await bsky.setVerificationPrefs(hideBadges: true)
        let live: BskyLiveEventPreferences = try await bsky.updateLiveEventPreferences(.hideFeed(id: "feed"))
        _ = live
        try await bsky.bskyAppQueueNudges(["nudge"])
        try await bsky.bskyAppDismissNudges(["nudge"])
        try await bsky.bskyAppSetActiveProgressGuide(BskyAppProgressGuide(guide: "follow-10"))
        try await bsky.bskyAppSetActiveProgressGuide(nil)
        try await bsky.setIsBetaUser(true)
        try await bsky.bskyAppUpsertNux(AppBskyActorDefs.Nux(id: "nux", completed: true))
        try await bsky.bskyAppRemoveNuxs(ids: ["nux"])
    }
}
