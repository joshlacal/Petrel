import Foundation

/// The preference logic behind ``BskyAgent``'s preference methods.
///
/// A port of the preference half of the TypeScript `Agent`. It works on the
/// raw preference array rather than on decoded structs: every setter reads the
/// array, rewrites only the entries it owns, and writes the array back, so
/// entry kinds and fields this SDK does not know about are returned to the
/// server untouched.
struct BskyPreferencesEngine: Sendable {
    /// Where the raw preference array is read from and written to.
    let backend: any BskyPreferencesBackend
    /// Serializes read-modify-write cycles.
    let lock: BskyAsyncLock
    /// Labelers that are always applied, ahead of the user's own.
    let appLabelers: [DID]

    // MARK: Read-modify-write

    /// Reads the preference array, applies `transform`, and writes the result,
    /// all under the lock.
    ///
    /// - Returns: The array that was written and whatever `transform` reported.
    func updatePreferencesReturning<R: Sendable>(
        _ transform: @Sendable ([BskyJSON]) async throws -> (preferences: [BskyJSON], result: R)
    ) async throws -> (preferences: [BskyJSON], result: R) {
        try await lock.withLock {
            let current = try await backend.loadPreferences()
            let next = try await transform(current)
            try await backend.savePreferences(next.preferences)
            return next
        }
    }

    /// Reads the preference array, applies `transform`, and writes the result,
    /// all under the lock.
    ///
    /// - Returns: The array that was written.
    @discardableResult
    func updatePreferences(
        _ transform: @Sendable ([BskyJSON]) async throws -> [BskyJSON]
    ) async throws -> [BskyJSON] {
        try await updatePreferencesReturning { current in
            try await (preferences: transform(current), result: true)
        }.preferences
    }

    /// Like ``updatePreferences(_:)``, and additionally points subsequent
    /// requests at the labelers of the array that was written, before the
    /// lock is released.
    ///
    /// Saving and reconfiguring are one serialized step. If the header were
    /// updated after the lock is released, a setter that saved first could
    /// update the header last and leave requests asking for a labeler set the
    /// account no longer has.
    @discardableResult
    func updatePreferencesApplyingLabelers(
        _ transform: @Sendable ([BskyJSON]) async throws -> [BskyJSON]
    ) async throws -> [BskyJSON] {
        try await lock.withLock {
            let next = try await transform(backend.loadPreferences())
            try await backend.savePreferences(next)
            await applyLabelers(from: next)
            return next
        }
    }

    // MARK: Labeler wiring

    /// The labeler DIDs of the last valid `labelersPref`, in stored order.
    static func labelerDIDs(in preferences: [BskyJSON]) -> [DID] {
        guard let pref = preferences.lastValid(AppBskyActorDefs.LabelersPref.self) else {
            return []
        }
        return pref.value.labelers.map(\.did)
    }

    /// Points subsequent requests at the app labelers (with `redact`) followed
    /// by the user's labelers.
    func applyLabelers(from preferences: [BskyJSON]) async {
        let labelers = appLabelers.map { AcceptedLabeler(did: $0, redact: true) }
            + Self.labelerDIDs(in: preferences).map { AcceptedLabeler(did: $0) }
        await backend.configureLabelers(labelers)
    }

    // MARK: Read

    /// Fetches and parses the account's preferences.
    ///
    /// Accounts without second-generation saved feeds are migrated on the
    /// spot: first-generation saved and pinned feeds are converted (or a lone
    /// Following timeline is created) and written back so the migration
    /// happens once.
    func getPreferences() async throws -> BskyPreferences {
        // Read and reconfigure the labelers as one serialized step, so a read
        // that started before a concurrent labeler change cannot apply its
        // older view of the subscriptions after that change has been applied.
        let raw = try await lock.withLock {
            let raw = try await backend.loadPreferences()
            await applyLabelers(from: raw)
            return raw
        }

        var prefs = BskyPreferences()
        prefs.moderationPrefs = ModerationPrefs(
            adultContentEnabled: false,
            labels: KnownLabels.defaultSettings,
            labelers: appLabelers.map { ModerationPrefsLabeler(did: $0) },
            mutedWords: [],
            hiddenPosts: []
        )

        var savedFeeds: [AppBskyActorDefs.SavedFeed]?
        var labelPrefs: [BskyContentLabelPreference] = []

        for pref in raw {
            guard let type = pref.typeIdentifier else { continue }
            switch type {
            case AppBskyActorDefs.AdultContentPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.AdultContentPref.self) {
                    prefs.moderationPrefs.adultContentEnabled = value.enabled
                }

            case AppBskyActorDefs.ContentLabelPref.typeIdentifier:
                if let value = BskyContentLabelPreference(pref) {
                    labelPrefs.append(value.adjustingLegacyVisibility())
                }

            case AppBskyActorDefs.LabelersPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.LabelersPref.self) {
                    prefs.moderationPrefs.labelers =
                        appLabelers.map { ModerationPrefsLabeler(did: $0) }
                            + value.labelers.map { ModerationPrefsLabeler(did: $0.did) }
                }

            case AppBskyActorDefs.SavedFeedsPrefV2.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.SavedFeedsPrefV2.self) {
                    savedFeeds = value.items
                }

            case AppBskyActorDefs.SavedFeedsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.SavedFeedsPref.self) {
                    prefs.feeds.saved = value.saved
                    prefs.feeds.pinned = value.pinned
                }

            case AppBskyActorDefs.PersonalDetailsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.PersonalDetailsPref.self),
                   let birthDate = value.birthDate
                {
                    prefs.birthDate = birthDate.date
                }

            case AppBskyActorDefs.DeclaredAgePref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.DeclaredAgePref.self) {
                    prefs.declaredAge = value
                }

            case AppBskyActorDefs.FeedViewPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.FeedViewPref.self) {
                    let defaults = BskyFeedViewPreference()
                    prefs.feedViewPrefs[value.feed] = BskyFeedViewPreference(
                        hideReplies: value.hideReplies ?? defaults.hideReplies,
                        hideRepliesByUnfollowed: value.hideRepliesByUnfollowed ?? defaults.hideRepliesByUnfollowed,
                        hideRepliesByLikeCount: value.hideRepliesByLikeCount ?? defaults.hideRepliesByLikeCount,
                        hideReposts: value.hideReposts ?? defaults.hideReposts,
                        hideQuotePosts: value.hideQuotePosts ?? defaults.hideQuotePosts
                    )
                }

            case AppBskyActorDefs.ThreadViewPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.ThreadViewPref.self), let sort = value.sort {
                    prefs.threadViewPrefs.sort = sort
                }

            case AppBskyActorDefs.InterestsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.InterestsPref.self) {
                    prefs.interests.tags = value.tags
                }

            case AppBskyActorDefs.MutedWordsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.MutedWordsPref.self) {
                    prefs.moderationPrefs.mutedWords = value.items.map { word in
                        AppBskyActorDefs.MutedWord(
                            id: word.id,
                            value: word.value,
                            targets: word.targets,
                            actorTarget: (word.actorTarget ?? "").isEmpty ? "all" : word.actorTarget,
                            expiresAt: word.expiresAt
                        )
                    }
                }

            case AppBskyActorDefs.HiddenPostsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.HiddenPostsPref.self) {
                    prefs.moderationPrefs.hiddenPosts = value.items
                }

            case AppBskyActorDefs.BskyAppStatePref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.BskyAppStatePref.self) {
                    prefs.bskyAppState.queuedNudges = value.queuedNudges ?? []
                    prefs.bskyAppState.activeProgressGuide = Self.progressGuide(from: pref["activeProgressGuide"])
                    prefs.bskyAppState.nuxs = value.nuxs ?? []
                    if let isBetaUser = value.isBetaUser {
                        prefs.bskyAppState.isBetaUser = isBetaUser
                    }
                }

            case AppBskyActorDefs.PostInteractionSettingsPref.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.PostInteractionSettingsPref.self) {
                    prefs.postInteractionSettings = value
                }

            case AppBskyActorDefs.VerificationPrefs.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.VerificationPrefs.self) {
                    prefs.verificationPrefs = AppBskyActorDefs.VerificationPrefs(hideBadges: value.hideBadges)
                }

            case AppBskyActorDefs.LiveEventPreferences.typeIdentifier:
                if let value = pref.valid(AppBskyActorDefs.LiveEventPreferences.self) {
                    prefs.liveEventPreferences = BskyLiveEventPreferences(
                        hiddenFeedIds: value.hiddenFeedIds ?? [],
                        hideAllFeeds: value.hideAllFeeds ?? false
                    )
                }

            default:
                continue
            }
        }

        if let savedFeeds {
            prefs.savedFeeds = savedFeeds
        } else {
            // No second-generation entry exists: migrate from the first
            // generation if it is there, otherwise start with Following, and
            // persist the result so the migration does not run again.
            prefs.savedFeeds = try await migrateSavedFeedsIfNeeded()
        }

        for pref in labelPrefs {
            guard let visibility = LabelPreference(rawValue: pref.visibility) else { continue }
            if let labelerDid = pref.labelerDid {
                guard let index = prefs.moderationPrefs.labelers.firstIndex(where: { $0.did == labelerDid }) else {
                    continue
                }
                prefs.moderationPrefs.labelers[index].labels[pref.label] = visibility
            } else {
                prefs.moderationPrefs.labels[pref.label] = visibility
            }
        }
        prefs.moderationPrefs.labels = Self.remapLegacyLabels(prefs.moderationPrefs.labels)


        return prefs
    }

    /// Copies settings stored under retired label names onto their current
    /// names. Applied on read only; nothing is written back.
    static func remapLegacyLabels(_ labels: [String: LabelPreference]) -> [String: LabelPreference] {
        var remapped = labels
        for (legacy, current) in legacyToCurrentLabel {
            if let value = labels[legacy] {
                remapped[current] = value
            }
        }
        return remapped
    }

    /// Retired label names and what replaced them.
    static let legacyToCurrentLabel: [String: String] = [
        "gore": "graphic-media",
        "nsfw": "porn",
        "suggestive": "sexual",
    ]

    /// Current label names and the retired name still written alongside them
    /// for older clients.
    static let currentToLegacyLabel: [String: String] = [
        "graphic-media": "gore",
        "porn": "nsfw",
        "sexual": "suggestive",
    ]

    /// Reads a stored progress guide, keeping fields the lexicon does not describe.
    private static func progressGuide(from json: BskyJSON?) -> BskyAppProgressGuide? {
        guard let object = json?.objectValue, let guide = object["guide"]?.stringValue else {
            return nil
        }
        var extras = object
        extras["guide"] = nil
        extras["$type"] = nil
        let additional = (try? BskyJSON.object(extras).decoded(as: [String: ATProtocolValueContainer].self)) ?? [:]
        return BskyAppProgressGuide(guide: guide, additionalFields: additional)
    }
}

// MARK: - Raw preference helpers

/// A `contentLabelPref` read without the generated decoder, so that a
/// malformed `labelerDid` invalidates the entry instead of turning a
/// per-labeler setting into a global one.
struct BskyContentLabelPreference: Sendable {
    let label: String
    let visibility: String
    let labelerDid: DID?

    init(label: String, visibility: String, labelerDid: DID?) {
        self.label = label
        self.visibility = visibility
        self.labelerDid = labelerDid
    }

    /// Returns `nil` unless `json` is a valid `contentLabelPref`.
    init?(_ json: BskyJSON) {
        guard json.typeIdentifier == AppBskyActorDefs.ContentLabelPref.typeIdentifier,
              let label = json["label"]?.stringValue,
              let visibility = json["visibility"]?.stringValue
        else {
            return nil
        }
        if let rawLabeler = json["labelerDid"] {
            guard let string = rawLabeler.stringValue, let did = try? DID(didString: string) else {
                return nil
            }
            labelerDid = did
        } else {
            labelerDid = nil
        }
        self.label = label
        self.visibility = visibility
    }

    /// The retired `show` setting means what `ignore` means today.
    func adjustingLegacyVisibility() -> BskyContentLabelPreference {
        BskyContentLabelPreference(
            label: label,
            visibility: visibility == "show" ? "ignore" : visibility,
            labelerDid: labelerDid
        )
    }
}

/// A generated preference type that names its own `$type`.
protocol BskyTypedPreference: Decodable {
    static var typeIdentifier: String { get }
}

extension AppBskyActorDefs.AdultContentPref: BskyTypedPreference {}
extension AppBskyActorDefs.ContentLabelPref: BskyTypedPreference {}
extension AppBskyActorDefs.SavedFeedsPref: BskyTypedPreference {}
extension AppBskyActorDefs.SavedFeedsPrefV2: BskyTypedPreference {}
extension AppBskyActorDefs.PersonalDetailsPref: BskyTypedPreference {}
extension AppBskyActorDefs.DeclaredAgePref: BskyTypedPreference {}
extension AppBskyActorDefs.FeedViewPref: BskyTypedPreference {}
extension AppBskyActorDefs.ThreadViewPref: BskyTypedPreference {}
extension AppBskyActorDefs.InterestsPref: BskyTypedPreference {}
extension AppBskyActorDefs.MutedWordsPref: BskyTypedPreference {}
extension AppBskyActorDefs.HiddenPostsPref: BskyTypedPreference {}
extension AppBskyActorDefs.LabelersPref: BskyTypedPreference {}
extension AppBskyActorDefs.BskyAppStatePref: BskyTypedPreference {}
extension AppBskyActorDefs.PostInteractionSettingsPref: BskyTypedPreference {}
extension AppBskyActorDefs.VerificationPrefs: BskyTypedPreference {}
extension AppBskyActorDefs.LiveEventPreferences: BskyTypedPreference {}

extension BskyJSON {
    /// Whether this entry carries the `$type` of `type`. This is the loose
    /// check used when removing entries: malformed entries of the type match too.
    func isPreference<T: BskyTypedPreference>(_ type: T.Type) -> Bool {
        typeIdentifier == T.typeIdentifier
    }

    /// Decodes this entry as `type`, or returns `nil` when the `$type` differs
    /// or the entry does not satisfy the lexicon. This is the strict check
    /// used when reading.
    func valid<T: BskyTypedPreference>(_ type: T.Type) -> T? {
        guard isPreference(type) else { return nil }
        return try? decoded(as: type)
    }

    /// A new, empty entry of the given type.
    static func preference<T: BskyTypedPreference>(_ type: T.Type, _ fields: [String: BskyJSON] = [:]) -> BskyJSON {
        var object = fields
        object["$type"] = .string(T.typeIdentifier)
        return .object(object)
    }

    /// Returns a copy with `key` set, or removed when `value` is `nil`.
    func setting(_ key: String, _ value: BskyJSON?) -> BskyJSON {
        var copy = self
        copy[key] = value
        return copy
    }
}

extension Array where Element == BskyJSON {
    /// The last entry that is a valid `type` (and satisfies `predicate`),
    /// with both its raw and decoded form.
    func lastValid<T: BskyTypedPreference>(
        _ type: T.Type,
        where predicate: (T) -> Bool = { _ in true }
    ) -> (json: BskyJSON, value: T)? {
        for entry in reversed() {
            if let value = entry.valid(type), predicate(value) {
                return (entry, value)
            }
        }
        return nil
    }

    /// Every entry whose `$type` is not that of `type`.
    func removing<T: BskyTypedPreference>(_ type: T.Type) -> [BskyJSON] {
        filter { !$0.isPreference(type) }
    }

    /// Removes every entry of `type` and appends `entry`.
    func replacing<T: BskyTypedPreference>(_ type: T.Type, with entry: BskyJSON) -> [BskyJSON] {
        removing(type) + [entry]
    }
}
