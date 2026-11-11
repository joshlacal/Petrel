import Foundation

/// Moderation-related preferences: adult content, content label settings,
/// labeler subscriptions, muted words and hidden posts.
extension BskyPreferencesEngine {
    // MARK: Adult content

    /// Turns adult content on or off.
    func setAdultContentEnabled(_ enabled: Bool) async throws {
        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.AdultContentPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.AdultContentPref.self)
            return prefs.replacing(
                AppBskyActorDefs.AdultContentPref.self,
                with: pref.setting("enabled", .bool(enabled))
            )
        }
    }

    // MARK: Content labels

    /// Sets how content carrying `key` is treated, globally or for one labeler.
    ///
    /// Global settings for `graphic-media`, `porn` and `sexual` are also
    /// written under their retired names (`gore`, `nsfw`, `suggestive`) so
    /// older clients stay in sync.
    func setContentLabelPref(_ key: String, _ value: LabelPreference, labelerDid: DID? = nil) async throws {
        let labeler = labelerDid?.didString()
        try await updatePreferences { prefs in
            func concerns(_ pref: BskyJSON, label: String, labeler: String?) -> Bool {
                pref.isPreference(AppBskyActorDefs.ContentLabelPref.self)
                    && pref["label"]?.stringValue == label
                    && pref["labelerDid"]?.stringValue == labeler
            }
            func lastValid(label: String, labeler: String?) -> BskyJSON? {
                prefs.last { BskyContentLabelPreference($0) != nil && concerns($0, label: label, labeler: labeler) }
            }
            func fresh(label: String, labeler: String?) -> BskyJSON {
                var fields: [String: BskyJSON] = ["label": .string(label)]
                if let labeler {
                    fields["labelerDid"] = .string(labeler)
                }
                return BskyJSON.preference(AppBskyActorDefs.ContentLabelPref.self, fields)
            }

            let visibility = BskyJSON.string(value.rawValue)
            let labelPref = (lastValid(label: key, labeler: labeler) ?? fresh(label: key, labeler: labeler))
                .setting("visibility", visibility)

            var updated = prefs.filter { !concerns($0, label: key, labeler: labeler) } + [labelPref]

            // A global setting for a renamed label is double-written under the old name.
            if labeler == nil, let legacyLabel = Self.currentToLegacyLabel[key] {
                let legacyPref = (lastValid(label: legacyLabel, labeler: nil) ?? fresh(label: legacyLabel, labeler: nil))
                    .setting("visibility", visibility)
                updated = updated.filter { !concerns($0, label: legacyLabel, labeler: nil) } + [legacyPref]
            }

            return updated
        }
    }

    // MARK: Labelers

    /// Subscribes to a labeler and applies the resulting labeler set to
    /// subsequent requests. Subscribing twice is a no-op.
    func addLabeler(_ did: DID) async throws {
        let didString = did.didString()
        try await updatePreferencesApplyingLabelers { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.LabelersPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.LabelersPref.self, ["labelers": .array([])])
            var labelers = pref["labelers"]?.arrayValue ?? []
            if !labelers.contains(where: { $0["did"]?.stringValue == didString }) {
                labelers.append(.object(["did": .string(didString)]))
            }
            return prefs.replacing(AppBskyActorDefs.LabelersPref.self, with: pref.setting("labelers", .array(labelers)))
        }
    }

    /// Unsubscribes from a labeler and applies the resulting labeler set to
    /// subsequent requests.
    func removeLabeler(_ did: DID) async throws {
        let didString = did.didString()
        try await updatePreferencesApplyingLabelers { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.LabelersPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.LabelersPref.self, ["labelers": .array([])])
            let labelers = (pref["labelers"]?.arrayValue ?? []).filter { $0["did"]?.stringValue != didString }
            return prefs.replacing(AppBskyActorDefs.LabelersPref.self, with: pref.setting("labelers", .array(labelers)))
        }
    }

    // MARK: Muted words

    /// Mutes a word or tag. Nothing is stored when the value is empty after
    /// ``BskyPreferencesUtilities/sanitizeMutedWordValue(_:)``.
    func addMutedWord(
        value: String,
        targets: [AppBskyActorDefs.MutedWordTarget],
        actorTarget: String? = nil,
        expiresAt: ATProtocolDate? = nil
    ) async throws {
        let sanitized = BskyPreferencesUtilities.sanitizeMutedWordValue(value)
        guard !sanitized.isEmpty else { return }

        try await updatePreferences { prefs in
            let newWord = await Self.mutedWordJSON(
                id: TIDGenerator.next(),
                value: sanitized,
                targets: targets,
                actorTarget: actorTarget,
                expiresAt: expiresAt
            )

            let pref: BskyJSON
            if let existing = prefs.lastValid(AppBskyActorDefs.MutedWordsPref.self)?.json {
                let items = (existing["items"]?.arrayValue ?? []) + [newWord]
                // Give identifiers to words stored before identifiers existed.
                pref = await existing.setting("items", .array(Self.migratingLegacyMutedWords(items)))
            } else {
                pref = BskyJSON.preference(AppBskyActorDefs.MutedWordsPref.self, ["items": .array([newWord])])
            }
            return prefs.replacing(AppBskyActorDefs.MutedWordsPref.self, with: pref)
        }
    }

    /// Mutes several words, one write per word, in order.
    func addMutedWords(_ words: [AppBskyActorDefs.MutedWord]) async throws {
        for word in words {
            try await addMutedWord(
                value: word.value,
                targets: word.targets,
                actorTarget: word.actorTarget,
                expiresAt: word.expiresAt
            )
        }
    }

    /// Replaces a stored muted word with `mutedWord`, matched by identifier
    /// (or by value for words stored before identifiers existed). Does nothing
    /// when there is no match.
    func updateMutedWord(_ mutedWord: AppBskyActorDefs.MutedWord) async throws {
        try await updatePreferences { prefs in
            guard let existing = prefs.lastValid(AppBskyActorDefs.MutedWordsPref.self)?.json else {
                return prefs
            }
            var items: [BskyJSON] = []
            for item in existing["items"]?.arrayValue ?? [] {
                guard Self.mutedWord(item, matches: mutedWord) else {
                    items.append(item)
                    continue
                }
                let sanitized = BskyPreferencesUtilities.sanitizeMutedWordValue(mutedWord.value)
                let existingID = item["id"]?.stringValue ?? ""
                let id = existingID.isEmpty ? await TIDGenerator.next() : existingID
                items.append(Self.mutedWordJSON(
                    id: id,
                    value: sanitized.isEmpty ? (item["value"]?.stringValue ?? "") : sanitized,
                    targets: mutedWord.targets,
                    actorTarget: mutedWord.actorTarget ?? item["actorTarget"]?.stringValue,
                    expiresAt: mutedWord.expiresAt
                ))
            }
            let pref = await existing.setting("items", .array(Self.migratingLegacyMutedWords(items)))
            return prefs.replacing(AppBskyActorDefs.MutedWordsPref.self, with: pref)
        }
    }

    /// Unmutes a word, matched by identifier (or by value for words stored
    /// before identifiers existed). Does nothing when there is no match.
    func removeMutedWord(_ mutedWord: AppBskyActorDefs.MutedWord) async throws {
        try await updatePreferences { prefs in
            guard let existing = prefs.lastValid(AppBskyActorDefs.MutedWordsPref.self)?.json else {
                return prefs
            }
            var items = existing["items"]?.arrayValue ?? []
            if let index = items.firstIndex(where: { Self.mutedWord($0, matches: mutedWord) }) {
                items.remove(at: index)
            }
            let pref = await existing.setting("items", .array(Self.migratingLegacyMutedWords(items)))
            return prefs.replacing(AppBskyActorDefs.MutedWordsPref.self, with: pref)
        }
    }

    /// Unmutes several words, one write per word, in order.
    func removeMutedWords(_ words: [AppBskyActorDefs.MutedWord]) async throws {
        for word in words {
            try await removeMutedWord(word)
        }
    }

    /// The JSON stored for one muted word. Written without `$type`, as the
    /// reference client does for array items.
    private static func mutedWordJSON(
        id: String,
        value: String,
        targets: [AppBskyActorDefs.MutedWordTarget],
        actorTarget: String?,
        expiresAt: ATProtocolDate?
    ) -> BskyJSON {
        var object: [String: BskyJSON] = [
            "id": .string(id),
            "value": .string(value),
            "targets": .array(targets.map { .string($0.rawValue) }),
            "actorTarget": .string((actorTarget ?? "").isEmpty ? "all" : (actorTarget ?? "all")),
        ]
        if let expiresAt {
            object["expiresAt"] = .string(expiresAt.iso8601String)
        }
        return .object(object)
    }

    /// Whether a stored word is the one `candidate` refers to.
    private static func mutedWord(_ stored: BskyJSON, matches candidate: AppBskyActorDefs.MutedWord) -> Bool {
        let storedID = stored["id"]?.stringValue ?? ""
        if !storedID.isEmpty {
            // Prefer matching on the identifier.
            return storedID == candidate.id
        }
        // Words stored before identifiers existed are matched by value.
        return stored["value"]?.stringValue == candidate.value
    }

    /// Gives an identifier to every stored word that lacks one.
    private static func migratingLegacyMutedWords(_ items: [BskyJSON]) async -> [BskyJSON] {
        var migrated: [BskyJSON] = []
        for item in items {
            if (item["id"]?.stringValue ?? "").isEmpty, item.objectValue != nil {
                await migrated.append(item.setting("id", .string(TIDGenerator.next())))
            } else {
                migrated.append(item)
            }
        }
        return migrated
    }

    // MARK: Hidden posts

    /// Hides a post. Hiding a post twice stores it once.
    func hidePost(_ uri: ATProtocolURI) async throws {
        try await updateHiddenPost(uri.uriString(), hide: true)
    }

    /// Stops hiding a post. Unhiding a post that is not hidden is a no-op.
    func unhidePost(_ uri: ATProtocolURI) async throws {
        try await updateHiddenPost(uri.uriString(), hide: false)
    }

    private func updateHiddenPost(_ uri: String, hide: Bool) async throws {
        try await updatePreferences { prefs in
            let pref = prefs.lastValid(AppBskyActorDefs.HiddenPostsPref.self)?.json
                ?? BskyJSON.preference(AppBskyActorDefs.HiddenPostsPref.self, ["items": .array([])])
            var items = Self.unique(Self.strings(pref["items"]))
            if hide {
                if !items.contains(uri) {
                    items.append(uri)
                }
            } else {
                items.removeAll { $0 == uri }
            }
            return prefs.replacing(
                AppBskyActorDefs.HiddenPostsPref.self,
                with: pref.setting("items", .array(items.map(BskyJSON.string)))
            )
        }
    }
}
