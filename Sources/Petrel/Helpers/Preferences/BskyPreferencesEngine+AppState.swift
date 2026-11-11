import Foundation

/// Display preferences (feed and thread view, interests, personal details),
/// official-app state (nudges, progress guide, NUXs), default post interaction
/// settings, verification display and live-event feeds.
extension BskyPreferencesEngine {
    // MARK: Personal details

    /// Declares (or, with `nil`, withdraws) the user's birth date.
    func setPersonalDetails(birthDate: Date?) async throws {
        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.PersonalDetailsPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.PersonalDetailsPref.self)
            let value = birthDate.map { BskyJSON.string(ATProtocolDate(date: $0).iso8601String) }
            return prefs.replacing(
                AppBskyActorDefs.PersonalDetailsPref.self,
                with: pref.setting("birthDate", value)
            )
        }
    }

    // MARK: Feed and thread view

    /// Changes view preferences of one feed. Fields not named in `update` keep
    /// their stored value.
    func setFeedViewPrefs(feed: String, _ update: BskyFeedViewPreferenceUpdate) async throws {
        try await updatePreferences { prefs in
            let existing = prefs.lastValid(AppBskyActorDefs.FeedViewPref.self) { $0.feed == feed }?.json
            var fields: [String: BskyJSON] = ["feed": .string(feed)]
            fields["hideReplies"] = update.hideReplies.map(BskyJSON.bool)
            fields["hideRepliesByUnfollowed"] = update.hideRepliesByUnfollowed.map(BskyJSON.bool)
            fields["hideRepliesByLikeCount"] = update.hideRepliesByLikeCount.map(BskyJSON.integer)
            fields["hideReposts"] = update.hideReposts.map(BskyJSON.bool)
            fields["hideQuotePosts"] = update.hideQuotePosts.map(BskyJSON.bool)
            let pref = (existing ?? .object([:]))
                .merging(BskyJSON.preference(AppBskyActorDefs.FeedViewPref.self, fields))

            return prefs.filter {
                !($0.isPreference(AppBskyActorDefs.FeedViewPref.self) && $0["feed"]?.stringValue == feed)
            } + [pref]
        }
    }

    /// Sets the reply sort order used in threads.
    func setThreadViewPrefs(sort: String) async throws {
        try await updatePreferences { prefs in
            let existing = prefs.lastValid(AppBskyActorDefs.ThreadViewPref.self)?.json ?? .object([:])
            let pref = existing.merging(
                BskyJSON.preference(AppBskyActorDefs.ThreadViewPref.self, ["sort": .string(sort)])
            )
            return prefs.replacing(AppBskyActorDefs.ThreadViewPref.self, with: pref)
        }
    }

    // MARK: Interests

    /// Replaces the user's interest tags.
    func setInterestsPref(tags: [String]) async throws {
        try await updatePreferences { prefs in
            let existing = prefs.lastValid(AppBskyActorDefs.InterestsPref.self)?.json ?? .object([:])
            let pref = existing.merging(
                BskyJSON.preference(AppBskyActorDefs.InterestsPref.self, ["tags": .array(tags.map(BskyJSON.string))])
            )
            return prefs.replacing(AppBskyActorDefs.InterestsPref.self, with: pref)
        }
    }

    // MARK: Official-app state

    /// Rewrites the `bskyAppStatePref` entry through `transform`, creating it
    /// when the account has none.
    private func updateAppState(
        _ transform: @Sendable (BskyJSON) throws -> BskyJSON
    ) async throws {
        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.BskyAppStatePref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.BskyAppStatePref.self)
            return try prefs.replacing(AppBskyActorDefs.BskyAppStatePref.self, with: transform(pref))
        }
    }

    /// Appends nudges to the queue.
    func bskyAppQueueNudges(_ nudges: [String]) async throws {
        try await updateAppState { pref in
            let queued = Self.strings(pref["queuedNudges"]) + nudges
            return pref.setting("queuedNudges", .array(queued.map(BskyJSON.string)))
        }
    }

    /// Removes nudges from the queue.
    func bskyAppDismissNudges(_ nudges: [String]) async throws {
        try await updateAppState { pref in
            let queued = Self.strings(pref["queuedNudges"]).filter { !nudges.contains($0) }
            return pref.setting("queuedNudges", .array(queued.map(BskyJSON.string)))
        }
    }

    /// Sets (or, with `nil`, clears) the onboarding guide in progress.
    func bskyAppSetActiveProgressGuide(_ guide: BskyAppProgressGuide?) async throws {
        var stored: BskyJSON?
        if let guide {
            guard guide.guide.utf8.count <= 100 else {
                throw BskyAgentError.invalidInput("Progress guide name must be at most 100 bytes")
            }
            var object: [String: BskyJSON]
            do {
                object = try BskyJSON.encoding(guide.additionalFields).objectValue ?? [:]
            } catch {
                throw BskyAgentError.invalidInput("Progress guide fields are not representable as JSON")
            }
            object["guide"] = .string(guide.guide)
            stored = .object(object)
        }
        let value = stored
        try await updateAppState { pref in
            pref.setting("activeProgressGuide", value)
        }
    }

    /// Records whether the user takes part in the beta program.
    func setIsBetaUser(_ isBetaUser: Bool) async throws {
        try await updateAppState { pref in
            pref.setting("isBetaUser", .bool(isBetaUser))
        }
    }

    /// Inserts a NUX, or replaces the stored one with the same identifier.
    func bskyAppUpsertNux(_ nux: AppBskyActorDefs.Nux) async throws {
        guard nux.id.utf16.count <= 64 else {
            throw BskyAgentError.invalidInput("NUX id must be at most 64 characters")
        }
        if let data = nux.data, data.utf16.count > 300 {
            throw BskyAgentError.invalidInput("NUX data must be at most 300 characters")
        }

        var next: [String: BskyJSON] = [
            "id": .string(nux.id),
            "completed": .bool(nux.completed),
        ]
        if let data = nux.data {
            next["data"] = .string(data)
        }
        if let expiresAt = nux.expiresAt {
            next["expiresAt"] = .string(expiresAt.iso8601String)
        }
        let stored = BskyJSON.object(next)
        let id = nux.id

        try await updateAppState { pref in
            // Remove any NUX with this identifier, then append.
            let nuxs = (pref["nuxs"]?.arrayValue ?? []).filter { $0["id"]?.stringValue != id } + [stored]
            return pref.setting("nuxs", .array(nuxs))
        }
    }

    /// Removes NUXs by identifier.
    func bskyAppRemoveNuxs(ids: [String]) async throws {
        try await updateAppState { pref in
            let nuxs = (pref["nuxs"]?.arrayValue ?? []).filter { nux in
                guard let id = nux["id"]?.stringValue else { return true }
                return !ids.contains(id)
            }
            return pref.setting("nuxs", .array(nuxs))
        }
    }

    // MARK: Post interaction settings

    /// Sets the default reply and quote restrictions applied to new posts.
    ///
    /// A `nil` rule list is stored as "absent", which for replies means
    /// "anyone can reply"; an empty reply rule list means "no one can reply".
    func setPostInteractionSettings(_ settings: AppBskyActorDefs.PostInteractionSettingsPref) async throws {
        let threadgate = try Self.ruleList(settings.threadgateAllowRules, name: "threadgateAllowRules")
        let postgate = try Self.ruleList(settings.postgateEmbeddingRules, name: "postgateEmbeddingRules")

        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.PostInteractionSettingsPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.PostInteractionSettingsPref.self)
            return prefs.replacing(
                AppBskyActorDefs.PostInteractionSettingsPref.self,
                with: pref
                    .setting("threadgateAllowRules", threadgate)
                    .setting("postgateEmbeddingRules", postgate)
            )
        }
    }

    /// Encodes a rule list and checks it against the lexicon: at most five
    /// rules, each an object that names its `$type`.
    private static func ruleList<Rule: Encodable>(_ rules: [Rule]?, name: String) throws -> BskyJSON? {
        guard let rules else { return nil }
        guard rules.count <= 5 else {
            throw BskyAgentError.invalidInput("\(name) accepts at most 5 rules")
        }
        return try .array(rules.map { rule in
            guard let json = try? BskyJSON.encoding(rule), json.objectValue != nil, json.typeIdentifier != nil else {
                throw BskyAgentError.invalidInput("Every entry of \(name) must be an object with a $type")
            }
            return json
        })
    }

    // MARK: Verification

    /// Sets whether verification badges are hidden.
    func setVerificationPrefs(hideBadges: Bool) async throws {
        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.VerificationPrefs.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.VerificationPrefs.self)
            return prefs.replacing(
                AppBskyActorDefs.VerificationPrefs.self,
                with: pref.setting("hideBadges", .bool(hideBadges))
            )
        }
    }

    // MARK: Live events

    /// Applies one change to the live-event feed preferences.
    ///
    /// - Returns: The preferences as stored after the change.
    @discardableResult
    func updateLiveEventPreferences(_ action: BskyLiveEventPreferencesAction) async throws -> BskyLiveEventPreferences {
        try await updatePreferencesReturning { prefs -> (preferences: [BskyJSON], result: BskyLiveEventPreferences) in
            let pref = prefs.lastValid(AppBskyActorDefs.LiveEventPreferences.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.LiveEventPreferences.self)

            var hiddenFeedIds = Self.unique(Self.strings(pref["hiddenFeedIds"]))
            var hideAllFeeds = pref["hideAllFeeds"]?.boolValue ?? false
            var updated = pref

            switch action {
            case let .hideFeed(id):
                if !hiddenFeedIds.contains(id) {
                    hiddenFeedIds.append(id)
                }
            case let .unhideFeed(id):
                hiddenFeedIds.removeAll { $0 == id }
            case .toggleHideAllFeeds:
                hideAllFeeds.toggle()
                updated = updated.setting("hideAllFeeds", .bool(hideAllFeeds))
            }
            updated = updated.setting("hiddenFeedIds", .array(hiddenFeedIds.map(BskyJSON.string)))

            return (
                prefs.replacing(AppBskyActorDefs.LiveEventPreferences.self, with: updated),
                BskyLiveEventPreferences(hiddenFeedIds: hiddenFeedIds, hideAllFeeds: hideAllFeeds)
            )
        }.result
    }
}
