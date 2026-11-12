import Foundation
@testable import Petrel
import Testing

/// Ports of `muted words`, `legacy muted words` and `hidden posts` in
/// `packages/api/tests/atp-agent.test.ts`.
@Suite("BskyPreferences muted words and hidden posts")
struct BskyPreferencesMutedWordsTests {
    private typealias MutedWord = AppBskyActorDefs.MutedWord

    private func mutedWords(_ engine: BskyPreferencesEngine) async throws -> [MutedWord] {
        try await engine.getPreferences().moderationPrefs.mutedWords
    }

    /// Appends a word the way clients did before words had identifiers.
    private func addLegacyMutedWord(
        _ backend: FakePreferencesBackend,
        value: String,
        targets: [String]
    ) {
        let type = AppBskyActorDefs.MutedWordsPref.typeIdentifier
        var prefs = backend.preferences
        var pref = prefs.last { $0.typeIdentifier == type }
            ?? .object(["$type": .string(type), "items": .array([])])
        let item = BskyJSON.object([
            "value": .string(value),
            "targets": .array(targets.map(BskyJSON.string)),
            "actorTarget": .string("all"),
        ])
        pref["items"] = .array((pref["items"]?.arrayValue ?? []) + [item])
        prefs = prefs.filter { $0.typeIdentifier != type } + [pref]
        backend.put(prefs)
    }

    // MARK: addMutedWord

    @Test("addMutedWord inserts")
    func inserts() async throws {
        let (engine, _) = PrefsFixture.make()
        let expiresAt = ATProtocolDate(date: Date(timeIntervalSince1970: 1_900_000_000))
        try await engine.addMutedWord(value: "word", targets: [.content], actorTarget: "all", expiresAt: expiresAt)

        let word = try #require(try await mutedWords(engine).first { $0.value == "word" })
        #expect(word.id?.isEmpty == false)
        #expect(word.targets == [.content])
        #expect(word.actorTarget == "all")
        #expect(word.expiresAt == expiresAt)
    }

    @Test("addMutedWord stores items without a $type, as the reference client does")
    func storedShape() async throws {
        let (engine, backend) = PrefsFixture.make()
        try await engine.addMutedWord(value: "word", targets: [.content, .tag])

        let pref = try #require(backend.entries(ofType: "app.bsky.actor.defs#mutedWordsPref").first)
        let item = try #require(pref["items"]?.arrayValue?.first)
        #expect(item.objectValue?.keys.sorted() == ["actorTarget", "id", "targets", "value"])
        #expect(item["targets"] == .array([.string("content"), .string("tag")]))
        #expect(item["actorTarget"] == .string("all"))
    }

    @Test(
        "addMutedWord sanitizes the value; nothing is stored when nothing is left",
        arguments: [
            ("#", nil),
            ("##", "#"),
            ("##hashtag", "#hashtag"),
            ("#\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
            ("##\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
            ("###\u{FE0F}\u{20E3}", "##\u{FE0F}\u{20E3}"),
            ("Bluesky's", "Bluesky's"),
            ("#\u{200B}", nil),
            ("#\u{200B}ab", "ab"),
            ("test value\n with newline", "test value with newline"),
            ("test value\n\r with newline", "test value with newline"),
            (" ", nil),
            (" trim ", "trim"),
        ] as [(String, String?)]
    )
    func sanitizesOnInsert(input: String, stored: String?) async throws {
        let (engine, backend) = PrefsFixture.make()
        try await engine.addMutedWord(value: input, targets: [], actorTarget: "all")

        let words = try await mutedWords(engine)
        if let stored {
            #expect(words.map(\.value) == [stored])
        } else {
            #expect(words.isEmpty)
            #expect(backend.saveCount == 1, "only the saved-feeds migration wrote")
        }
    }

    // MARK: addMutedWords

    @Test("addMutedWords: inserts happen sequentially, no clobbering")
    func addsSequentially() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWords([
            MutedWord(value: "a", targets: [.content], actorTarget: "all"),
            MutedWord(value: "b", targets: [.content], actorTarget: "all"),
            MutedWord(value: "c", targets: [.content], actorTarget: "all"),
        ])

        let words = try await mutedWords(engine)
        #expect(words.map(\.value) == ["a", "b", "c"])
        #expect(Set(words.compactMap(\.id)).count == 3)
    }

    @Test("adding the same value twice stores two words (no upsert)")
    func noUpsert() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWords([MutedWord(value: "both", targets: [.content], actorTarget: "all")])
        try await engine.addMutedWords([MutedWord(value: "both", targets: [.tag], actorTarget: "all")])

        #expect(try await mutedWords(engine).count == 2)
    }

    // MARK: updateMutedWord

    @Test("updateMutedWord: word doesn't exist, no update or insert")
    func updateMissing() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.updateMutedWord(MutedWord(value: "word", targets: [.tag, .content], actorTarget: "all"))
        #expect(try await mutedWords(engine).isEmpty)
    }

    @Test("updateMutedWord updates and sanitizes new value")
    func updateSanitizes() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "value", targets: [.content], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "value" })

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: "#new value", targets: word.targets, actorTarget: word.actorTarget
        ))

        let updated = try #require(try await mutedWords(engine).first { $0.id == word.id })
        #expect(updated.value == "new value")
        #expect(updated.targets == [.content])
    }

    @Test("updateMutedWord updates targets")
    func updateTargets() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "word", targets: [.tag], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "word" })

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: word.value, targets: [.content], actorTarget: word.actorTarget
        ))

        #expect(try await mutedWords(engine).first { $0.id == word.id }?.targets == [.content])
    }

    @Test("updateMutedWord updates actorTarget")
    func updateActorTarget() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "value", targets: [.content], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "value" })

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: word.value, targets: word.targets, actorTarget: "exclude-following"
        ))

        #expect(try await mutedWords(engine).first { $0.id == word.id }?.actorTarget == "exclude-following")
    }

    @Test("updateMutedWord keeps the stored actorTarget when none is given")
    func updateKeepsActorTarget() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "value", targets: [.content], actorTarget: "exclude-following")
        let word = try #require(try await mutedWords(engine).first)

        try await engine.updateMutedWord(MutedWord(id: word.id, value: word.value, targets: [.tag]))

        let updated = try #require(try await mutedWords(engine).first)
        #expect(updated.actorTarget == "exclude-following")
        #expect(updated.targets == [.tag])
    }

    @Test("updateMutedWord updates expiresAt, and clears it when nil")
    func updateExpiresAt() async throws {
        let (engine, _) = PrefsFixture.make()
        let expiresAt = ATProtocolDate(date: Date(timeIntervalSince1970: 1_900_000_000))
        let expiresAt2 = ATProtocolDate(date: Date(timeIntervalSince1970: 1_900_004_000))
        try await engine.addMutedWord(value: "value", targets: [.content], actorTarget: "all", expiresAt: expiresAt)
        let word = try #require(try await mutedWords(engine).first { $0.value == "value" })
        #expect(word.expiresAt == expiresAt)

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: word.value, targets: word.targets, actorTarget: word.actorTarget, expiresAt: expiresAt2
        ))
        #expect(try await mutedWords(engine).first { $0.id == word.id }?.expiresAt == expiresAt2)

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: word.value, targets: word.targets, actorTarget: word.actorTarget
        ))
        let cleared = try #require(try await mutedWords(engine).first { $0.id == word.id })
        #expect(cleared.expiresAt == nil)
    }

    @Test("updateMutedWord doesn't update if value is sanitized to be falsy")
    func updateKeepsValueWhenSanitizedEmpty() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "rug", targets: [.content], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "rug" })

        try await engine.updateMutedWord(MutedWord(
            id: word.id, value: "", targets: word.targets, actorTarget: word.actorTarget
        ))

        #expect(try await mutedWords(engine).first { $0.id == word.id }?.value == "rug")
    }

    // MARK: removeMutedWord

    @Test("removeMutedWord removes word")
    func removes() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "word", targets: [.tag], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "word" })

        try await engine.removeMutedWord(word)

        #expect(try await mutedWords(engine).contains { $0.id == word.id } == false)
    }

    @Test("removeMutedWord: word doesn't exist, no action")
    func removeMissing() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWord(value: "word", targets: [.tag], actorTarget: "all")
        let word = try #require(try await mutedWords(engine).first { $0.value == "word" })

        try await engine.removeMutedWord(MutedWord(value: "another", targets: [], actorTarget: "all"))

        #expect(try await mutedWords(engine).contains { $0.id == word.id })
    }

    @Test("removeMutedWords removes sequentially, no clobbering")
    func removesSequentially() async throws {
        let (engine, _) = PrefsFixture.make()
        try await engine.addMutedWords([
            MutedWord(value: "a", targets: [.content], actorTarget: "all "),
            MutedWord(value: "b", targets: [.content], actorTarget: "all "),
            MutedWord(value: "c", targets: [.content], actorTarget: "all "),
        ])

        let words = try await mutedWords(engine)
        #expect(words.count == 3)
        try await engine.removeMutedWords(words)

        #expect(try await mutedWords(engine).isEmpty)
    }

    // MARK: legacy muted words

    @Test("legacy: adds new word, migrates old words")
    func legacyAddMigrates() async throws {
        let (engine, backend) = PrefsFixture.make()
        addLegacyMutedWord(backend, value: "word", targets: ["content"])

        do {
            let word = try #require(try await mutedWords(engine).first { $0.value == "word" })
            #expect(word.id == nil)
        }

        try await engine.addMutedWords([MutedWord(value: "word2", targets: [.tag], actorTarget: "all")])

        let words = try await mutedWords(engine)
        let word = try #require(words.first { $0.value == "word" })
        let word2 = try #require(words.first { $0.value == "word2" })
        #expect(word.id?.isEmpty == false)
        #expect(word2.id?.isEmpty == false)
        #expect(word.id != word2.id)
    }

    @Test("legacy: updates legacy word, migrates old words")
    func legacyUpdateMigrates() async throws {
        let (engine, backend) = PrefsFixture.make()
        addLegacyMutedWord(backend, value: "word", targets: ["content"])
        addLegacyMutedWord(backend, value: "word2", targets: ["tag"])

        try await engine.updateMutedWord(MutedWord(value: "word", targets: [.tag], actorTarget: "all"))

        let words = try await mutedWords(engine)
        let word = try #require(words.first { $0.value == "word" })
        let word2 = try #require(words.first { $0.value == "word2" })
        #expect(words.count == 2)
        #expect(word.id?.isEmpty == false)
        #expect(word.targets == [.tag])
        #expect(word2.id?.isEmpty == false)
    }

    @Test("legacy: removes legacy word, migrates old words")
    func legacyRemoveMigrates() async throws {
        let (engine, backend) = PrefsFixture.make()
        addLegacyMutedWord(backend, value: "word", targets: ["content"])
        addLegacyMutedWord(backend, value: "word2", targets: ["tag"])

        try await engine.removeMutedWord(MutedWord(value: "word", targets: [.tag], actorTarget: "all"))

        let words = try await mutedWords(engine)
        #expect(words.count == 1)
        #expect(words.contains { $0.value == "word" } == false)
        #expect(words.first { $0.value == "word2" }?.id?.isEmpty == false)
    }

    @Test("a stored word without actorTarget reads as 'all'")
    func actorTargetDefaultsOnRead() async throws {
        let (engine, _) = try PrefsFixture.make(PrefsFixture.entries(#"""
        [{"$type": "app.bsky.actor.defs#mutedWordsPref",
          "items": [{"id": "3jzfcijpj2z2a", "value": "word", "targets": ["content"]}]}]
        """#))
        #expect(try await mutedWords(engine).first?.actorTarget == "all")
    }

    // MARK: hidden posts

    @Test("hidePost dedupes; unhidePost is safe to repeat")
    func hiddenPosts() async throws {
        let (engine, backend) = PrefsFixture.make()
        let postURI = try PrefsFixture.uri("at://did:plc:fake/app.bsky.feed.post/fake")

        try await engine.hidePost(postURI)
        try await engine.hidePost(postURI) // double, should dedupe
        #expect(try await engine.getPreferences().moderationPrefs.hiddenPosts == [postURI])

        try await engine.unhidePost(postURI)
        #expect(try await engine.getPreferences().moderationPrefs.hiddenPosts == [])

        // no issues calling a second time
        try await engine.unhidePost(postURI)
        #expect(try await engine.getPreferences().moderationPrefs.hiddenPosts == [])
        #expect(try backend.entries(ofType: "app.bsky.actor.defs#hiddenPostsPref") == PrefsFixture.entries(
            #"[{"$type": "app.bsky.actor.defs#hiddenPostsPref", "items": []}]"#
        ))
    }

    @Test("hidePost keeps the order posts were hidden in")
    func hiddenPostsOrder() async throws {
        let (engine, _) = PrefsFixture.make()
        let a = try PrefsFixture.uri("at://did:plc:fake/app.bsky.feed.post/a")
        let b = try PrefsFixture.uri("at://did:plc:fake/app.bsky.feed.post/b")
        try await engine.hidePost(a)
        try await engine.hidePost(b)
        try await engine.hidePost(a)
        #expect(try await engine.getPreferences().moderationPrefs.hiddenPosts == [a, b])
    }
}
