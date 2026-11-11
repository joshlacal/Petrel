import Foundation
@testable import Petrel

/// An in-memory stand-in for the account's PDS preference store.
///
/// It keeps the raw array exactly as written, counts calls, records every
/// labeler configuration, and mimics the one server behavior the reference
/// tests depend on: `declaredAgePref` is read-only and derived from the stored
/// birth date.
final class FakePreferencesBackend: BskyPreferencesBackend, @unchecked Sendable {
    struct SaveFailure: Error {}

    private let lock = NSLock()
    private var stored: [BskyJSON]
    private var loads = 0
    private var saves = 0
    private var pendingSaveFailures = 0
    private var labelerCalls: [[AcceptedLabeler]] = []
    private let emulatesDeclaredAge: Bool

    init(_ seed: [BskyJSON] = [], emulatesDeclaredAge: Bool = true) {
        stored = seed
        self.emulatesDeclaredAge = emulatesDeclaredAge
    }

    // MARK: BskyPreferencesBackend

    func loadPreferences() async throws -> [BskyJSON] {
        // Suspend so unsynchronized read-modify-write cycles would interleave.
        await Task.yield()
        return lock.withLock {
            loads += 1
            return served(stored)
        }
    }

    func savePreferences(_ preferences: [BskyJSON]) async throws {
        await Task.yield()
        try lock.withLock {
            if pendingSaveFailures > 0 {
                pendingSaveFailures -= 1
                throw SaveFailure()
            }
            saves += 1
            stored = emulatesDeclaredAge
                ? preferences.filter { $0.typeIdentifier != AppBskyActorDefs.DeclaredAgePref.typeIdentifier }
                : preferences
        }
    }

    func configureLabelers(_ labelers: [AcceptedLabeler]) async {
        // Suspend, as the real header update does (an actor hop), so a caller
        // that configures labelers outside the preferences lock can be overtaken.
        await Task.yield()
        lock.withLock { labelerCalls.append(labelers) }
    }

    // MARK: Inspection

    /// What `app.bsky.actor.getPreferences` would return right now.
    var preferences: [BskyJSON] {
        lock.withLock { served(stored) }
    }

    /// Replaces the stored array, as a direct `putPreferences` call would.
    func put(_ preferences: [BskyJSON]) {
        lock.withLock {
            stored = emulatesDeclaredAge
                ? preferences.filter { $0.typeIdentifier != AppBskyActorDefs.DeclaredAgePref.typeIdentifier }
                : preferences
        }
    }

    var loadCount: Int {
        lock.withLock { loads }
    }

    var saveCount: Int {
        lock.withLock { saves }
    }

    var configuredLabelers: [[AcceptedLabeler]] {
        lock.withLock { labelerCalls }
    }

    /// Makes the next `count` writes fail.
    func failNextSaves(_ count: Int) {
        lock.withLock { pendingSaveFailures = count }
    }

    /// Entries of one `$type`, in stored order.
    func entries(ofType type: String) -> [BskyJSON] {
        preferences.filter { $0.typeIdentifier == type }
    }

    private func served(_ preferences: [BskyJSON]) -> [BskyJSON] {
        guard emulatesDeclaredAge,
              let details = preferences.first(where: {
                  $0.typeIdentifier == AppBskyActorDefs.PersonalDetailsPref.typeIdentifier
              }),
              let birthDateString = details["birthDate"]?.stringValue,
              let birthDate = ATProtocolDate(iso8601String: birthDateString)?.date
        else {
            return preferences
        }
        let age = Calendar(identifier: .gregorian)
            .dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return preferences + [.object([
            "$type": .string(AppBskyActorDefs.DeclaredAgePref.typeIdentifier),
            "isOverAge13": .bool(age >= 13),
            "isOverAge16": .bool(age >= 16),
            "isOverAge18": .bool(age >= 18),
        ])]
    }
}

enum PrefsFixture {
    static let appLabelers = [BskyAgent.bskyLabelerDID]

    /// An engine over a fresh in-memory store.
    static func make(
        _ seed: [BskyJSON] = [],
        emulatesDeclaredAge: Bool = true
    ) -> (engine: BskyPreferencesEngine, backend: FakePreferencesBackend) {
        let backend = FakePreferencesBackend(seed, emulatesDeclaredAge: emulatesDeclaredAge)
        let engine = BskyPreferencesEngine(backend: backend, lock: BskyAsyncLock(), appLabelers: appLabelers)
        return (engine, backend)
    }

    /// Parses a JSON literal.
    static func json(_ text: String) throws -> BskyJSON {
        try BskyJSON.parse(Data(text.utf8))
    }

    /// Parses a JSON array literal into preference entries.
    static func entries(_ text: String) throws -> [BskyJSON] {
        try json(text).arrayValue ?? []
    }

    static func did(_ string: String) throws -> DID {
        try DID(didString: string)
    }

    static func uri(_ string: String) throws -> ATProtocolURI {
        try ATProtocolURI(uriString: string)
    }

    static func date(_ iso: String) throws -> Date {
        guard let date = ATProtocolDate(iso8601String: iso)?.date else {
            throw BskyAgentError.invalidInput("bad test date \(iso)")
        }
        return date
    }

    /// The preferences of an account that has stored nothing (after the
    /// saved-feeds migration has inserted the Following timeline).
    static func defaults() -> BskyPreferences {
        var prefs = BskyPreferences()
        prefs.savedFeeds = [AppBskyActorDefs.SavedFeed(id: "", type: "timeline", value: "following", pinned: true)]
        prefs.moderationPrefs = ModerationPrefs(
            adultContentEnabled: false,
            labels: KnownLabels.defaultSettings,
            labelers: appLabelers.map { ModerationPrefsLabeler(did: $0) },
            mutedWords: [],
            hiddenPosts: []
        )
        return prefs
    }
}

extension BskyPreferences {
    /// A copy with saved-feed identifiers blanked, for comparisons where the
    /// reference tests use `expect.any(String)`.
    var ignoringSavedFeedIDs: BskyPreferences {
        var copy = self
        copy.savedFeeds = savedFeeds.map {
            AppBskyActorDefs.SavedFeed(id: "", type: $0.type, value: $0.value, pinned: $0.pinned)
        }
        return copy
    }
}

extension AppBskyActorDefs.SavedFeed {
    /// `type|value|pinned`, for order-sensitive comparisons that ignore identifiers.
    var signature: String {
        "\(type)|\(value)|\(pinned)"
    }
}
