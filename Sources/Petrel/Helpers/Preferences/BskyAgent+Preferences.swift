import Foundation

extension BskyAgent {
    /// The preference logic bound to this agent's store, lock and app labelers.
    var preferencesEngine: BskyPreferencesEngine {
        BskyPreferencesEngine(backend: preferencesBackend, lock: preferencesLock, appLabelers: appLabelers)
    }
}

// MARK: - Reading

public extension BskyAgent {
    /// Fetches the account's preferences and parses them into one value.
    ///
    /// Duplicated entries resolve to the last valid one, missing entries take
    /// the defaults of the official client, and legacy entries are mapped onto
    /// their current form (`show` becomes `ignore`; settings stored under
    /// `gore`, `nsfw` and `suggestive` are copied to `graphic-media`, `porn`
    /// and `sexual`).
    ///
    /// Two side effects mirror the official client:
    ///
    /// - An account without second-generation saved feeds is migrated: its
    ///   first-generation feeds (or a lone Following timeline) are written
    ///   back as `savedFeedsPrefV2`.
    /// - The labelers the user subscribes to are applied to subsequent
    ///   requests through the `atproto-accept-labelers` header, after the
    ///   agent's ``appLabelers``.
    ///
    /// ```swift
    /// let prefs = try await client.bsky.getPreferences()
    /// let pinned = prefs.savedFeeds.filter(\.pinned)
    /// ```
    func getPreferences() async throws -> BskyPreferences {
        try await preferencesEngine.getPreferences()
    }
}

// MARK: - Saved feeds

public extension BskyAgent {
    /// Replaces the whole saved-feed list.
    ///
    /// Entries sharing an identifier collapse to the last one. Feeds are
    /// stored pinned-first. If the account still has a first-generation saved
    /// feeds entry, feeds and lists are mirrored into it.
    ///
    /// - Returns: The list as stored.
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when a feed has no
    ///   identifier, or a `feed`/`list` entry does not point at a record of
    ///   that kind.
    @discardableResult
    func overwriteSavedFeeds(_ savedFeeds: [AppBskyActorDefs.SavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try await preferencesEngine.overwriteSavedFeeds(savedFeeds)
    }

    /// Pins or unpins saved feeds, matched by identifier.
    ///
    /// Only the pinned state is taken from `savedFeeds`; identifiers that are
    /// not stored are ignored.
    ///
    /// - Returns: The list as stored.
    @discardableResult
    func updateSavedFeeds(_ savedFeeds: [AppBskyActorDefs.SavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try await preferencesEngine.updateSavedFeeds(savedFeeds)
    }

    /// Saves feeds, giving each a new identifier. Saving the same feed twice
    /// stores it twice.
    ///
    /// ```swift
    /// try await client.bsky.addSavedFeeds([.feed(feedURI, pinned: true)])
    /// ```
    ///
    /// - Returns: The list as stored.
    @discardableResult
    func addSavedFeeds(_ savedFeeds: [BskyNewSavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try await preferencesEngine.addSavedFeeds(savedFeeds)
    }

    /// Removes saved feeds by identifier.
    ///
    /// - Returns: The list as stored.
    @discardableResult
    func removeSavedFeeds(ids: [String]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try await preferencesEngine.removeSavedFeeds(ids: ids)
    }

    /// Legacy: replaces the first-generation saved and pinned feed arrays
    /// (`savedFeedsPref`). Current clients read `savedFeedsPrefV2`; use
    /// ``overwriteSavedFeeds(_:)`` unless you maintain an older client.
    @discardableResult
    func setSavedFeeds(saved: [ATProtocolURI], pinned: [ATProtocolURI]) async throws -> BskyPreferences.LegacyFeeds {
        try await preferencesEngine.setSavedFeeds(saved: saved, pinned: pinned)
    }

    /// Legacy: saves a feed in the first-generation entry. Use ``addSavedFeeds(_:)``.
    @discardableResult
    func addSavedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        try await preferencesEngine.addSavedFeed(uri)
    }

    /// Legacy: removes a feed from the first-generation entry. Use ``removeSavedFeeds(ids:)``.
    @discardableResult
    func removeSavedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        try await preferencesEngine.removeSavedFeed(uri)
    }

    /// Legacy: saves and pins a feed in the first-generation entry. Use
    /// ``addSavedFeeds(_:)`` or ``updateSavedFeeds(_:)``.
    @discardableResult
    func addPinnedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        try await preferencesEngine.addPinnedFeed(uri)
    }

    /// Legacy: unpins a feed in the first-generation entry. Use ``updateSavedFeeds(_:)``.
    @discardableResult
    func removePinnedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        try await preferencesEngine.removePinnedFeed(uri)
    }
}

// MARK: - Moderation

public extension BskyAgent {
    /// Turns adult content on or off.
    func setAdultContentEnabled(_ enabled: Bool) async throws {
        try await preferencesEngine.setAdultContentEnabled(enabled)
    }

    /// Sets how content carrying a label is treated.
    ///
    /// Without `labelerDid` the setting applies to the built-in label of that
    /// name; with it, to that labeler's label only. Global settings for
    /// `graphic-media`, `porn` and `sexual` are also written under their
    /// retired names so older clients stay in sync.
    ///
    /// ```swift
    /// try await client.bsky.setContentLabelPref("graphic-media", .hide)
    /// ```
    func setContentLabelPref(_ label: String, _ value: LabelPreference, labelerDid: DID? = nil) async throws {
        try await preferencesEngine.setContentLabelPref(label, value, labelerDid: labelerDid)
    }

    /// Subscribes to a labeler, then applies the user's labelers to subsequent
    /// requests through the `atproto-accept-labelers` header.
    func addLabeler(_ did: DID) async throws {
        try await preferencesEngine.addLabeler(did)
    }

    /// Unsubscribes from a labeler, then applies the user's remaining labelers
    /// to subsequent requests.
    func removeLabeler(_ did: DID) async throws {
        try await preferencesEngine.removeLabeler(did)
    }

    /// Mutes a word, phrase or tag.
    ///
    /// The value is trimmed, loses one leading `#`, and has line breaks and
    /// zero-width characters removed. If nothing is left the call does
    /// nothing. Words stored by older clients without an identifier are given
    /// one on the same write.
    ///
    /// ```swift
    /// try await client.bsky.addMutedWord("spoilers", targets: [.content, .tag])
    /// ```
    ///
    /// - Parameters:
    ///   - value: The word, phrase or tag to mute.
    ///   - targets: Where it applies: post text (`content`), tags (`tag`), or both.
    ///   - actorTarget: `all`, or `exclude-following` to keep seeing matches
    ///     from accounts the user follows.
    ///   - expiresAt: When the mute lapses. `nil` mutes indefinitely.
    func addMutedWord(
        _ value: String,
        targets: [AppBskyActorDefs.MutedWordTarget],
        actorTarget: String = "all",
        expiresAt: Date? = nil
    ) async throws {
        try await preferencesEngine.addMutedWord(
            value: value,
            targets: targets,
            actorTarget: actorTarget,
            expiresAt: expiresAt.map(ATProtocolDate.init(date:))
        )
    }

    /// Mutes several words in order. Identifiers on the given words are
    /// ignored; each stored word gets a new one.
    func addMutedWords(_ words: [AppBskyActorDefs.MutedWord]) async throws {
        try await preferencesEngine.addMutedWords(words)
    }

    /// Replaces a stored muted word with `word`.
    ///
    /// The stored word is found by `word.id`; a word stored by an older
    /// client without an identifier is found by `word.value`. The stored
    /// identifier is kept. A `nil` `expiresAt` removes the expiry, a `nil`
    /// `actorTarget` keeps the stored one, and a value that sanitizes to
    /// nothing keeps the stored value. Does nothing when no word matches.
    func updateMutedWord(_ word: AppBskyActorDefs.MutedWord) async throws {
        try await preferencesEngine.updateMutedWord(word)
    }

    /// Unmutes a word, found the same way as in ``updateMutedWord(_:)``.
    /// Does nothing when no word matches.
    func removeMutedWord(_ word: AppBskyActorDefs.MutedWord) async throws {
        try await preferencesEngine.removeMutedWord(word)
    }

    /// Unmutes several words in order.
    func removeMutedWords(_ words: [AppBskyActorDefs.MutedWord]) async throws {
        try await preferencesEngine.removeMutedWords(words)
    }

    /// Hides a post from the user's feeds. Hiding a post twice stores it once.
    func hidePost(_ uri: ATProtocolURI) async throws {
        try await preferencesEngine.hidePost(uri)
    }

    /// Stops hiding a post. Does nothing if the post is not hidden.
    func unhidePost(_ uri: ATProtocolURI) async throws {
        try await preferencesEngine.unhidePost(uri)
    }
}

// MARK: - Display

public extension BskyAgent {
    /// Declares the user's birth date, or withdraws it with `nil`.
    func setPersonalDetails(birthDate: Date?) async throws {
        try await preferencesEngine.setPersonalDetails(birthDate: birthDate)
    }

    /// Changes how one feed filters its content. Fields left `nil` in
    /// `update` keep their stored value.
    ///
    /// ```swift
    /// try await client.bsky.setFeedViewPrefs(feed: "home", .init(hideReposts: true))
    /// ```
    func setFeedViewPrefs(feed: String, _ update: BskyFeedViewPreferenceUpdate) async throws {
        try await preferencesEngine.setFeedViewPrefs(feed: feed, update)
    }

    /// Sets the reply sort order used in threads: `oldest`, `newest`,
    /// `most-likes`, `random` or `hotness`.
    func setThreadViewPrefs(sort: String) async throws {
        try await preferencesEngine.setThreadViewPrefs(sort: sort)
    }

    /// Replaces the user's interest tags.
    func setInterestsPref(tags: [String]) async throws {
        try await preferencesEngine.setInterestsPref(tags: tags)
    }

    /// Sets the reply and quote restrictions applied to new posts by default.
    ///
    /// A `nil` reply rule list means anyone can reply; an empty one means no
    /// one can. For quote rules, `nil` and empty both mean no restriction.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when a list has more than
    ///   five rules or a rule does not name its `$type`.
    func setPostInteractionSettings(_ settings: AppBskyActorDefs.PostInteractionSettingsPref) async throws {
        try await preferencesEngine.setPostInteractionSettings(settings)
    }

    /// Sets whether verification badges are hidden.
    func setVerificationPrefs(hideBadges: Bool) async throws {
        try await preferencesEngine.setVerificationPrefs(hideBadges: hideBadges)
    }

    /// Hides or shows live-event feeds.
    ///
    /// - Returns: The live-event preferences as stored after the change.
    @discardableResult
    func updateLiveEventPreferences(_ action: BskyLiveEventPreferencesAction) async throws -> BskyLiveEventPreferences {
        try await preferencesEngine.updateLiveEventPreferences(action)
    }
}

// MARK: - Official-app state

public extension BskyAgent {
    /// Appends nudges to the official app's queue.
    func bskyAppQueueNudges(_ nudges: [String]) async throws {
        try await preferencesEngine.bskyAppQueueNudges(nudges)
    }

    /// Removes nudges from the official app's queue.
    func bskyAppDismissNudges(_ nudges: [String]) async throws {
        try await preferencesEngine.bskyAppDismissNudges(nudges)
    }

    /// Sets the onboarding guide in progress, or clears it with `nil`.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when the guide name is
    ///   longer than 100 bytes.
    func bskyAppSetActiveProgressGuide(_ guide: BskyAppProgressGuide?) async throws {
        try await preferencesEngine.bskyAppSetActiveProgressGuide(guide)
    }

    /// Records whether the user takes part in the Bluesky beta program.
    func setIsBetaUser(_ isBetaUser: Bool) async throws {
        try await preferencesEngine.setIsBetaUser(isBetaUser)
    }

    /// Stores a new-user-experience item, replacing the one with the same identifier.
    ///
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when the identifier is
    ///   longer than 64 characters or the data longer than 300.
    func bskyAppUpsertNux(_ nux: AppBskyActorDefs.Nux) async throws {
        try await preferencesEngine.bskyAppUpsertNux(nux)
    }

    /// Removes new-user-experience items by identifier.
    func bskyAppRemoveNuxs(ids: [String]) async throws {
        try await preferencesEngine.bskyAppRemoveNuxs(ids: ids)
    }
}
