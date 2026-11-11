import Foundation

/// Saved feeds: the second-generation list (`savedFeedsPrefV2`) and the
/// first-generation pair of URI arrays (`savedFeedsPref`) kept in sync with it.
extension BskyPreferencesEngine {
    // MARK: Second generation

    /// Replaces the whole saved-feed list.
    ///
    /// Entries sharing an identifier collapse to the last one, which also takes
    /// the later position.
    @discardableResult
    func overwriteSavedFeeds(_ savedFeeds: [AppBskyActorDefs.SavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try savedFeeds.forEach(BskyPreferencesUtilities.validateSavedFeed)
        var order: [String] = []
        var byID: [String: BskyJSON] = [:]
        for feed in savedFeeds {
            // Remove and re-insert so the last occurrence decides the position.
            if byID[feed.id] != nil {
                order.removeAll { $0 == feed.id }
            }
            order.append(feed.id)
            byID[feed.id] = Self.json(for: feed)
        }
        let unique = order.compactMap { byID[$0] }
        return try await updateSavedFeedsV2 { _ in unique }
    }

    /// Changes the pinned state of saved feeds, matched by identifier. No
    /// other field of a stored feed is changed, and unknown identifiers are ignored.
    @discardableResult
    func updateSavedFeeds(_ savedFeedsToUpdate: [AppBskyActorDefs.SavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try savedFeedsToUpdate.forEach(BskyPreferencesUtilities.validateSavedFeed)
        return try await updateSavedFeedsV2 { savedFeeds in
            savedFeeds.map { savedFeed in
                guard let id = savedFeed["id"]?.stringValue,
                      let updated = savedFeedsToUpdate.first(where: { $0.id == id })
                else {
                    return savedFeed
                }
                return savedFeed.setting("pinned", .bool(updated.pinned))
            }
        }
    }

    /// Appends feeds, giving each a new identifier. Duplicates are allowed.
    @discardableResult
    func addSavedFeeds(_ savedFeeds: [BskyNewSavedFeed]) async throws -> [AppBskyActorDefs.SavedFeed] {
        var toSave: [AppBskyActorDefs.SavedFeed] = []
        for feed in savedFeeds {
            let id = await TIDGenerator.next()
            toSave.append(AppBskyActorDefs.SavedFeed(id: id, type: feed.type, value: feed.value, pinned: feed.pinned))
        }
        try toSave.forEach(BskyPreferencesUtilities.validateSavedFeed)
        let added = toSave.map(Self.json(for:))
        return try await updateSavedFeedsV2 { $0 + added }
    }

    /// Removes saved feeds by identifier.
    @discardableResult
    func removeSavedFeeds(ids: [String]) async throws -> [AppBskyActorDefs.SavedFeed] {
        try await updateSavedFeedsV2 { savedFeeds in
            savedFeeds.filter { feed in
                guard let id = feed["id"]?.stringValue else { return true }
                return !ids.contains(id)
            }
        }
    }

    /// The JSON stored for one saved feed. Written without `$type`, as the
    /// reference client does for array items.
    private static func json(for feed: AppBskyActorDefs.SavedFeed) -> BskyJSON {
        .object([
            "id": .string(feed.id),
            "type": .string(feed.type),
            "value": .string(feed.value),
            "pinned": .bool(feed.pinned),
        ])
    }

    /// Rewrites the second-generation list through `transform`, stores it
    /// pinned-first, and mirrors feeds and lists into the first-generation
    /// entry when the account still has one.
    ///
    /// - Returns: The list as stored, pinned feeds first.
    private func updateSavedFeedsV2(
        _ transform: @Sendable ([BskyJSON]) throws -> [BskyJSON]
    ) async throws -> [AppBskyActorDefs.SavedFeed] {
        let outcome = try await updatePreferencesReturning { prefs in
            try Self.rewritingSavedFeedsV2(in: prefs, transform)
        }
        return try Self.savedFeeds(from: outcome.result)
    }

    /// The pure part of a second-generation saved-feeds write.
    ///
    /// - Returns: The rewritten preference array and the stored feed items.
    private static func rewritingSavedFeedsV2(
        in prefs: [BskyJSON],
        _ transform: ([BskyJSON]) throws -> [BskyJSON]
    ) throws -> (preferences: [BskyJSON], result: [BskyJSON]) {
        let existingV2 = prefs.lastValid(AppBskyActorDefs.SavedFeedsPrefV2.self)?.json
            ?? BskyJSON.preference(AppBskyActorDefs.SavedFeedsPrefV2.self, ["items": .array([])])

        let newSavedFeeds = try transform(existingV2["items"]?.arrayValue ?? [])

        // Pinned first, then saved; order within each group is kept.
        let ordered = newSavedFeeds.filter { $0["pinned"]?.boolValue == true }
            + newSavedFeeds.filter { $0["pinned"]?.boolValue != true }
        let updatedV2 = existingV2.setting("items", .array(ordered))

        var updated = prefs.replacing(AppBskyActorDefs.SavedFeedsPrefV2.self, with: updatedV2)

        // An account that still has a first-generation entry was migrated
        // from it. Second-generation writes are copied back to it, never
        // the other way round.
        if let existingV1 = prefs.lastValid(AppBskyActorDefs.SavedFeedsPref.self)?.json {
            let compatible = ordered.compactMap { item -> (value: String, pinned: Bool)? in
                guard let type = item["type"]?.stringValue, type == "feed" || type == "list",
                      let value = item["value"]?.stringValue
                else {
                    return nil
                }
                return (value, item["pinned"]?.boolValue == true)
            }
            let mirrored = BskyPreferencesUtilities.savedFeedsToURIArrays(compatible)
            let saved = strings(existingV1["saved"]) + mirrored.saved
            let pinned = strings(existingV1["pinned"]) + mirrored.pinned
            let updatedV1 = existingV1
                .setting("saved", .array(unique(saved).map(BskyJSON.string)))
                .setting("pinned", .array(unique(pinned).map(BskyJSON.string)))
            updated = updated.replacing(AppBskyActorDefs.SavedFeedsPref.self, with: updatedV1)
        }

        return (updated, ordered)
    }

    private static func savedFeeds(from items: [BskyJSON]) throws -> [AppBskyActorDefs.SavedFeed] {
        try items.map { item in
            do {
                return try item.decoded(as: AppBskyActorDefs.SavedFeed.self)
            } catch {
                throw BskyAgentError.invalidResponse(
                    nsid: "app.bsky.actor.getPreferences",
                    reason: "A stored saved feed does not match the lexicon"
                )
            }
        }
    }

    // MARK: Migration

    /// Creates the second-generation list for an account that has none: its
    /// first-generation feeds if it has any, otherwise the Following timeline.
    ///
    /// The check and the write happen under the lock, so a list created by a
    /// concurrent call in the meantime is returned as is instead of being
    /// overwritten.
    func migrateSavedFeedsIfNeeded() async throws -> [AppBskyActorDefs.SavedFeed] {
        let items = try await lock.withLock { () -> [BskyJSON] in
            let current = try await backend.loadPreferences()
            if let existing = current.lastValid(AppBskyActorDefs.SavedFeedsPrefV2.self) {
                return existing.json["items"]?.arrayValue ?? []
            }
            let legacy = current.lastValid(AppBskyActorDefs.SavedFeedsPref.self)?.value
            let migrated = try await Self.migratedSavedFeeds(saved: legacy?.saved, pinned: legacy?.pinned)
                .map(Self.json(for:))
            let next = try Self.rewritingSavedFeedsV2(in: current) { _ in migrated }
            try await backend.savePreferences(next.preferences)
            return next.result
        }
        return try Self.savedFeeds(from: items)
    }

    /// Builds the second-generation saved feeds from first-generation arrays.
    private static func migratedSavedFeeds(
        saved: [ATProtocolURI]?,
        pinned: [ATProtocolURI]?
    ) async throws -> [AppBskyActorDefs.SavedFeed] {
        // The Following timeline always comes first.
        var order = ["timeline"]
        var feeds: [String: AppBskyActorDefs.SavedFeed] = [:]
        feeds["timeline"] = await AppBskyActorDefs.SavedFeed(
            id: TIDGenerator.next(),
            type: "timeline",
            value: "following",
            pinned: true
        )

        if let saved, let pinned {
            // Pinned feeds decide the order.
            for uri in pinned.map({ $0.uriString() }) {
                let type = try BskyPreferencesUtilities.savedFeedType(of: uri)
                // Only feeds and lists can be carried over.
                guard type != "unknown" else { continue }
                if feeds[uri] == nil {
                    order.append(uri)
                }
                feeds[uri] = await AppBskyActorDefs.SavedFeed(
                    id: TIDGenerator.next(),
                    type: type,
                    value: uri,
                    pinned: true
                )
            }
            for uri in saved.map({ $0.uriString() }) where feeds[uri] == nil {
                let type = try BskyPreferencesUtilities.savedFeedType(of: uri)
                guard type != "unknown" else { continue }
                order.append(uri)
                feeds[uri] = await AppBskyActorDefs.SavedFeed(
                    id: TIDGenerator.next(),
                    type: type,
                    value: uri,
                    pinned: false
                )
            }
        }

        return order.compactMap { feeds[$0] }
    }

    // MARK: First generation (legacy)

    /// Replaces the first-generation saved and pinned feed arrays.
    @discardableResult
    func setSavedFeeds(saved: [ATProtocolURI], pinned: [ATProtocolURI]) async throws -> BskyPreferences.LegacyFeeds {
        let saved = saved.map { $0.uriString() }
        let pinned = pinned.map { $0.uriString() }
        return try await updateLegacyFeeds { _, _ in (saved, pinned) }
    }

    /// Saves a feed in the first-generation entry, moving it to the end if present.
    @discardableResult
    func addSavedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        let value = uri.uriString()
        return try await updateLegacyFeeds { saved, pinned in
            (saved.filter { $0 != value } + [value], pinned)
        }
    }

    /// Removes a feed from both first-generation arrays.
    @discardableResult
    func removeSavedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        let value = uri.uriString()
        return try await updateLegacyFeeds { saved, pinned in
            (saved.filter { $0 != value }, pinned.filter { $0 != value })
        }
    }

    /// Saves and pins a feed in the first-generation entry.
    @discardableResult
    func addPinnedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        let value = uri.uriString()
        return try await updateLegacyFeeds { saved, pinned in
            (saved.filter { $0 != value } + [value], pinned.filter { $0 != value } + [value])
        }
    }

    /// Unpins a feed in the first-generation entry; it stays saved.
    @discardableResult
    func removePinnedFeed(_ uri: ATProtocolURI) async throws -> BskyPreferences.LegacyFeeds {
        let value = uri.uriString()
        return try await updateLegacyFeeds { saved, pinned in
            (saved, pinned.filter { $0 != value })
        }
    }

    private func updateLegacyFeeds(
        _ transform: @Sendable (_ saved: [String], _ pinned: [String]) -> (saved: [String], pinned: [String])
    ) async throws -> BskyPreferences.LegacyFeeds {
        let outcome = try await updatePreferencesReturning { prefs -> (preferences: [BskyJSON], result: [[String]]) in
            let feedsPref = prefs.lastValid(AppBskyActorDefs.SavedFeedsPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.SavedFeedsPref.self, ["saved": .array([]), "pinned": .array([])])

            let next = transform(Self.strings(feedsPref["saved"]), Self.strings(feedsPref["pinned"]))
            let updated = feedsPref
                .setting("saved", .array(next.saved.map(BskyJSON.string)))
                .setting("pinned", .array(next.pinned.map(BskyJSON.string)))

            return (prefs.replacing(AppBskyActorDefs.SavedFeedsPref.self, with: updated), [next.saved, next.pinned])
        }
        return try BskyPreferences.LegacyFeeds(
            saved: outcome.result[0].map(Self.atURI),
            pinned: outcome.result[1].map(Self.atURI)
        )
    }

    // MARK: Helpers

    /// The string elements of a JSON array; anything else is skipped.
    static func strings(_ json: BskyJSON?) -> [String] {
        (json?.arrayValue ?? []).compactMap(\.stringValue)
    }

    /// Removes repeats, keeping the first occurrence of each value in place.
    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func atURI(_ string: String) throws -> ATProtocolURI {
        do {
            return try ATProtocolURI(uriString: string)
        } catch {
            throw BskyAgentError.invalidInput("Not an AT URI: \(string)")
        }
    }
}
