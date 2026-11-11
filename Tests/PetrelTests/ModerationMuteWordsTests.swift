import Foundation
@testable import Petrel
import Testing

/// Port of `tests/moderation-mutewords.test.ts`.
@Suite("Moderation: muted words")
struct ModerationMuteWordsTests {
    // MARK: Helpers

    /// `matchMuteWords` over `text` with the tag facets the reference tests
    /// obtain from `RichText.detectFacetsWithoutResolution()`.
    private func match(
        _ text: String,
        _ words: [AppBskyActorDefs.MutedWord],
        outlineTags: [String] = [],
        languages: [String]? = nil
    ) -> [MuteWordMatch] {
        Moderation.matchMuteWords(
            mutedWords: words,
            text: text,
            facets: ModerationMock.tagFacets(in: text),
            outlineTags: outlineTags,
            languages: languages
        )
    }

    private func options(
        viewer: String = "did:web:alice.test",
        mutedWords: [AppBskyActorDefs.MutedWord]
    ) throws -> ModerationOptions {
        try ModerationOptions(
            userDid: ModerationMock.did(viewer),
            prefs: ModerationPrefs(
                adultContentEnabled: false,
                labels: [:],
                labelers: [],
                mutedWords: mutedWords,
                hiddenPosts: []
            )
        )
    }

    private func post(
        _ text: String,
        author: JSONObject = ModerationMock.profile(handle: "bob.test", displayName: "Bob"),
        facets: [JSONObject]? = nil,
        recordEmbed: JSONObject? = nil,
        embed: JSONObject? = nil
    ) throws -> AppBskyFeedDefs.PostView {
        let view = try ModerationMock.postView(
            record: ModerationMock.post(text: text, facets: facets, embed: recordEmbed),
            author: author,
            embed: embed,
            labels: []
        )
        // The engine only reads the record when it decoded as a post.
        guard case let .knownType(record) = view.record, record is AppBskyFeedPost else {
            Issue.record("Mock post record did not decode as app.bsky.feed.post")
            return view
        }
        return view
    }

    // MARK: tags

    @Test("tags: match: outline tag")
    func outlineTag() {
        let word = ModerationMock.mutedWord("outlineTag", targets: ["tag"])
        let matches = match("This is a post #inlineTag", [word], outlineTags: ["outlineTag"])
        #expect(matches == [MuteWordMatch(word: word, predicate: word.value)])
    }

    @Test("tags: match: inline tag")
    func inlineTag() {
        let word = ModerationMock.mutedWord("inlineTag", targets: ["tag"])
        let matches = match("This is a post #inlineTag", [word], outlineTags: ["outlineTag"])
        #expect(matches == [MuteWordMatch(word: word, predicate: word.value)])
    }

    @Test("tags: match: content target matches inline tag")
    func contentTargetMatchesInlineTag() {
        let matches = match(
            "This is a post #inlineTag",
            [ModerationMock.mutedWord("inlineTag")],
            outlineTags: ["outlineTag"]
        )
        #expect(!matches.isEmpty)
    }

    @Test("tags: no match: only tag targets")
    func onlyTagTargets() {
        let matches = match("This is a post", [ModerationMock.mutedWord("inlineTag", targets: ["tag"])])
        #expect(matches.isEmpty)
    }

    // MARK: early exits / general content with exact results

    @Test("early exits: match: single character 希")
    func singleCharacter() {
        // https://bsky.app/profile/mukuuji.bsky.social/post/3klji4fvsdk2c
        let word = ModerationMock.mutedWord("希")
        #expect(match("改善希望です", [word]) == [MuteWordMatch(word: word, predicate: word.value)])
    }

    @Test("general content: match: word within post")
    func wordWithinPost() {
        let word = ModerationMock.mutedWord("javascript")
        #expect(
            match("This is a post about javascript", [word]) == [MuteWordMatch(word: word, predicate: word.value)]
        )
    }

    @Test("returning MuteWordMatch: matches all")
    func matchesAll() {
        let first = ModerationMock.mutedWord("post")
        let second = ModerationMock.mutedWord("javascript")
        #expect(
            match("This is a post about javascript", [first, second]) == [
                MuteWordMatch(word: first, predicate: first.value),
                MuteWordMatch(word: second, predicate: second.value),
            ]
        )
    }

    // MARK: match / no match table

    struct Case: Sendable, CustomTestStringConvertible {
        var group: String
        var text: String
        var word: String
        var matches: Bool
        var languages: [String]?

        init(_ group: String, _ text: String, _ word: String, _ matches: Bool, languages: [String]? = nil) {
            self.group = group
            self.text = text
            self.word = word
            self.matches = matches
            self.languages = languages
        }

        var testDescription: String {
            "\(group): \(matches ? "match" : "no match"): \(word)"
        }
    }

    static let cases: [Case] = [
        // early exits
        Case("early exits", "Idk why ☠︎ but maybe", "☠︎", true),
        Case("early exits", "hey", "politics", false),
        Case("early exits", "javascript", "javascript", true),
        // general content
        Case("general content", "Use your brain, Eric", "ai", false),
        Case("general content", "Use your\n\tbrain, Eric", "brain", true),
        Case("general content", "So happy :)", ":)", true),
        // punctuation semi-fuzzy
        Case("yay!", "We're federating, yay!", "yay!", true),
        Case("yay!", "We're federating, yay!", "yay", true),
        Case("y!ppee!!", "We're federating, y!ppee!!", "y!ppee", true),
        // single exclamation point, source has double (the reference expects a match)
        Case("y!ppee!!", "We're federating, y!ppee!!", "y!ppee!", true),
        Case("apostrophes: Bluesky's", "Yay, Bluesky's mutewords work", "Bluesky's", true),
        Case("apostrophes: Bluesky's", "Yay, Bluesky's mutewords work", "Bluesky", true),
        Case("apostrophes: Bluesky's", "Yay, Bluesky's mutewords work", "bluesky", true),
        Case("apostrophes: Bluesky's", "Yay, Bluesky's mutewords work", "blueskys", true),
        Case("Why so S@assy?", "Why so S@assy?", "S@assy", true),
        Case("Why so S@assy?", "Why so S@assy?", "s@assy", true),
        // case insensitive
        Case("New York Times", "New York Times", "new york times", true),
        Case("!command", "Idk maybe a bot !command", "!command", true),
        Case("!command", "Idk maybe a bot !command", "command", true),
        Case("!command", "Idk maybe a bot command", "!command", false),
        Case("and/or", "Tomatoes are fruits and/or vegetables", "and/or", true),
        Case("and/or", "Tomatoes are fruits and/or vegetables", "Andor", false),
        Case("super-bad", "I'm super-bad", "super-bad", true),
        Case("super-bad", "I'm super-bad", "super", true),
        Case("super-bad", "I'm super-bad", "bad", true),
        Case("super-bad", "I'm super-bad", "super bad", true),
        Case("super-bad", "I'm super-bad", "superbad", true),
        Case(
            "idk_what_this_would_be", "Weird post with idk_what_this_would_be", "idk what this would be", true
        ),
        // extra word
        Case(
            "idk_what_this_would_be", "Weird post with idk_what_this_would_be", "idk what this would be for", false
        ),
        Case("idk_what_this_would_be", "Weird post with idk_what_this_would_be", "idk", true),
        Case("idk_what_this_would_be", "Weird post with idk_what_this_would_be", "idkwhatthiswouldbe", true),
        Case("parentheses", "Post with context(iykyk)", "context(iykyk)", true),
        Case("parentheses", "Post with context(iykyk)", "context", true),
        Case("parentheses", "Post with context(iykyk)", "iykyk", true),
        Case("parentheses", "Post with context(iykyk)", "(iykyk)", true),
        Case("🦋", "Post with 🦋", "🦋", true),
        // phrases
        Case(
            "phrases",
            "I like turtles, or how I learned to stop worrying and love the internet.",
            "stop worrying",
            true
        ),
        Case(
            "phrases",
            "I like turtles, or how I learned to stop worrying and love the internet.",
            "turtles, or how",
            true
        ),
        // languages without spaces
        // "I love turtles, or how I learned to stop worrying and love the internet"
        Case(
            "languages without spaces",
            "私はカメが好きです、またはどのようにして心配するのをやめてインターネットを愛するようになったのか",
            "インターネット",
            true,
            languages: ["ja"]
        ),
    ]

    @Test("matchMuteWords", arguments: cases)
    func matchTable(_ testCase: Case) {
        let matches = match(testCase.text, [ModerationMock.mutedWord(testCase.word)], languages: testCase.languages)
        #expect(matches.isEmpty != testCase.matches)
        #expect(
            Moderation.hasMutedWord(
                mutedWords: [ModerationMock.mutedWord(testCase.word)],
                text: testCase.text,
                languages: testCase.languages
            ) == testCase.matches
        )
    }

    // MARK: robustness

    /// A small deterministic generator so the fuzz inputs are the same on every run.
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test("Arbitrary text and words never trap, and hasMutedWord agrees with matchMuteWords")
    func fuzz() {
        let alphabet: [String] = [
            "a", "b", "A", "ß", "İ", "é", "e\u{301}", "希", "🦋", "👨‍👩‍👧‍👧", "☠︎", " ", "  ", "\n", "\t", "\u{A0}",
            "\u{200B}", "\u{FEFF}", "-", "_", "/", "!", "'", "’", "(", ")", ".", "#", "@", "$", "\u{0}", "\r\n",
        ]
        var generator = SplitMix64(state: 0x5EED)
        func randomString(maxPieces: Int) -> String {
            let count = Int.random(in: 0 ... maxPieces, using: &generator)
            return (0 ..< count).map { _ in alphabet.randomElement(using: &generator) ?? "" }.joined()
        }

        for _ in 0 ..< 2000 {
            let text = randomString(maxPieces: 24)
            let words = (0 ..< Int.random(in: 0 ... 3, using: &generator)).map { _ in
                ModerationMock.mutedWord(
                    randomString(maxPieces: 6),
                    targets: Bool.random(using: &generator) ? ["content"] : ["tag"]
                )
            }
            let languages = Bool.random(using: &generator) ? ["ja"] : nil
            let tags = [randomString(maxPieces: 3)]

            let matches = Moderation.matchMuteWords(
                mutedWords: words, text: text, outlineTags: tags, languages: languages
            )
            let has = Moderation.hasMutedWord(
                mutedWords: words, text: text, outlineTags: tags, languages: languages
            )
            #expect(has == !matches.isEmpty)
            #expect(matches.count <= words.count)
            #expect(matches.allSatisfy { words.contains($0.word) })
        }
    }

    // MARK: facet with multiple features

    @Test("facet with multiple features: multiple tags")
    func multipleTagsInOneFacet() {
        let facet = AppBskyRichtextFacet(
            index: AppBskyRichtextFacet.ByteSlice(byteStart: 0, byteEnd: 4),
            features: [
                .appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: "good")),
                .appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag(tag: "bad")),
            ]
        )
        let matches = Moderation.matchMuteWords(
            mutedWords: [ModerationMock.mutedWord("bad")],
            text: "tags",
            facets: [facet]
        )
        #expect(!matches.isEmpty)
    }

    @Test("facet with multiple features: other features")
    func unknownFeatureNextToTag() throws {
        let facet = try ModerationMock.decode(
            AppBskyRichtextFacet.self,
            [
                "features": [
                    ["$type": "com.example.richtext.facet#other", "foo": "bar"],
                    ["$type": "app.bsky.richtext.facet#tag", "tag": "bad"],
                ],
                "index": ["byteEnd": 4, "byteStart": 0],
            ] as JSONObject
        )
        #expect(facet.features.count == 2)
        let matches = Moderation.matchMuteWords(
            mutedWords: [ModerationMock.mutedWord("bad")],
            text: "test",
            facets: [facet]
        )
        #expect(!matches.isEmpty)
    }

    // MARK: doesn't mute own post

    @Test("does mute if it isn't own post")
    func mutesOthersPosts() throws {
        let decision = try Moderation.moderatePost(
            post("Mute words!"),
            options: options(mutedWords: [ModerationMock.mutedWord("words")])
        )
        #expect(decision.causes.first?.type == .muteWord)
        #expect(decision.causes.first?.matches.map(\.predicate) == ["words!"])
    }

    @Test("doesn't mute own post when muted word is in text")
    func doesNotMuteOwnPostText() throws {
        let decision = try Moderation.moderatePost(
            post("Mute words!"),
            options: options(viewer: "did:web:bob.test", mutedWords: [ModerationMock.mutedWord("words")])
        )
        #expect(decision.causes.isEmpty)
    }

    @Test("doesn't mute own post when muted word is in tags")
    func doesNotMuteOwnPostTags() throws {
        let decision = try Moderation.moderatePost(
            post("Mute #words!"),
            options: options(
                viewer: "did:web:bob.test",
                mutedWords: [ModerationMock.mutedWord("words", targets: ["tags"])]
            )
        )
        #expect(decision.causes.isEmpty)
    }

    // MARK: timed mute words

    @Test("timed mute words: non-expired word")
    func nonExpiredWord() throws {
        let decision = try Moderation.moderatePost(
            post("Mute words!"),
            options: options(
                mutedWords: [ModerationMock.mutedWord("words", expiresAt: Date().addingTimeInterval(1))]
            )
        )
        #expect(decision.causes.first?.type == .muteWord)
    }

    @Test("timed mute words: expired word")
    func expiredWord() throws {
        let decision = try Moderation.moderatePost(
            post("Mute words!"),
            options: options(
                mutedWords: [ModerationMock.mutedWord("words", expiresAt: Date().addingTimeInterval(-1))]
            )
        )
        #expect(decision.causes.isEmpty)
    }

    @Test("timed mute words: expiry is judged against the supplied clock")
    func expiryUsesInjectedClock() throws {
        let expiry = Date(timeIntervalSince1970: 1_700_000_000)
        let opts = try options(mutedWords: [ModerationMock.mutedWord("words", expiresAt: expiry)])
        let subject = try post("Mute words!")

        let before = Moderation.moderatePost(subject, options: opts, now: expiry.addingTimeInterval(-60))
        #expect(before.causes.first?.type == .muteWord)

        let after = Moderation.moderatePost(subject, options: opts, now: expiry.addingTimeInterval(60))
        #expect(after.causes.isEmpty)
    }

    // MARK: actor-based mute words

    @Test("actor-based mute words: followed actor")
    func followedActor() throws {
        let author = ModerationMock.profile(
            handle: "bob.test",
            displayName: "Bob",
            viewer: ["following": "at://did:web:alice.test/app.bsky.graph.follow/fake"]
        )
        let decision = try Moderation.moderatePost(
            post("Mute words!", author: author),
            options: options(mutedWords: [ModerationMock.mutedWord("words", actorTarget: "exclude-following")])
        )
        #expect(decision.causes.isEmpty)
    }

    @Test("actor-based mute words: non-followed actor")
    func nonFollowedActor() throws {
        let author = ModerationMock.profile(handle: "carla.test", displayName: "Carla", viewer: [:])
        let decision = try Moderation.moderatePost(
            post("Mute words!", author: author),
            options: options(mutedWords: [ModerationMock.mutedWord("words", actorTarget: "exclude-following")])
        )
        #expect(decision.causes.first?.type == .muteWord)
    }

    // MARK: gallery embed alt text

    private func galleryRecord(_ alts: [String]) -> JSONObject {
        [
            "$type": "app.bsky.embed.gallery",
            "items": alts.map { alt -> JSONObject in
                [
                    "$type": "app.bsky.embed.gallery#image",
                    "image": ModerationMock.blob(),
                    "alt": alt,
                    "aspectRatio": ["width": 4, "height": 3],
                ]
            },
        ]
    }

    private func galleryView(_ alts: [String]) -> JSONObject {
        [
            "$type": "app.bsky.embed.gallery#view",
            "items": alts.map { alt -> JSONObject in
                [
                    "$type": "app.bsky.embed.gallery#viewImage",
                    "thumbnail": "https://example.test/thumb.jpg",
                    "fullsize": "https://example.test/full.jpg",
                    "alt": alt,
                    "aspectRatio": ["width": 4, "height": 3],
                ]
            },
        ]
    }

    private func galleryOptions() throws -> ModerationOptions {
        try options(mutedWords: [ModerationMock.mutedWord("badword")])
    }

    private var carol: JSONObject {
        ModerationMock.profile(handle: "carol.test", displayName: "Carol")
    }

    private func hasMuteWordCause(_ decision: ModerationDecision) -> Bool {
        decision.causes.contains { $0.type == .muteWord }
    }

    @Test("gallery: matches alt text on a directly-attached gallery embed")
    func galleryOnPost() throws {
        let decision = try Moderation.moderatePost(
            post("innocent text", recordEmbed: galleryRecord(["fine", "this contains badword here"])),
            options: galleryOptions()
        )
        #expect(hasMuteWordCause(decision))
    }

    @Test("gallery: does not match when no item alt contains a muted word")
    func galleryWithoutMutedWord() throws {
        let decision = try Moderation.moderatePost(
            post("innocent text", recordEmbed: galleryRecord(["nothing here", "still nothing"])),
            options: galleryOptions()
        )
        #expect(!hasMuteWordCause(decision))
    }

    @Test("gallery: matches alt text inside a quoted record's gallery")
    func galleryInQuotedRecord() throws {
        let quoted = ModerationMock.post(
            text: "inside quoted",
            embed: galleryRecord(["contains badword inside"])
        )
        let decision = try Moderation.moderatePost(
            post(
                "outer post",
                embed: ModerationMock.embedRecordView(record: quoted, author: carol, labels: [])
            ),
            options: galleryOptions()
        )
        #expect(hasMuteWordCause(decision))
    }

    @Test("gallery: matches alt text on a quoted record's recordWithMedia gallery")
    func galleryInQuotedRecordWithMedia() throws {
        let quoted = ModerationMock.post(
            text: "inside quoted record-with-media",
            embed: [
                "$type": "app.bsky.embed.recordWithMedia",
                "record": [
                    "$type": "app.bsky.embed.record",
                    "record": [
                        "uri": "at://did:web:dave.test/app.bsky.feed.post/inner",
                        "cid": ModerationMock.fakeCID,
                    ],
                ] as JSONObject,
                "media": galleryRecord(["contains badword in nested gallery"]),
            ]
        )
        let decision = try Moderation.moderatePost(
            post(
                "outer post",
                embed: ModerationMock.embedRecordView(record: quoted, author: carol, labels: [])
            ),
            options: galleryOptions()
        )
        #expect(hasMuteWordCause(decision))
    }

    @Test("gallery: matches alt text on the view-side recordWithMedia gallery")
    func galleryInRecordWithMediaView() throws {
        let recordWithMediaView: JSONObject = [
            "$type": "app.bsky.embed.recordWithMedia#view",
            "record": [
                "$type": "app.bsky.embed.record#view",
                "record": [
                    "$type": "app.bsky.embed.record#viewRecord",
                    "uri": "at://did:web:dave.test/app.bsky.feed.post/inner",
                    "cid": ModerationMock.fakeCID,
                    "author": carol,
                    "value": ModerationMock.post(text: "inner content"),
                    "labels": [Any](),
                    "indexedAt": ModerationMock.timestamp,
                ] as JSONObject,
            ] as JSONObject,
            "media": galleryView(["contains badword on view side"]),
        ]
        let decision = try Moderation.moderatePost(
            post("outer post", embed: recordWithMediaView),
            options: galleryOptions()
        )
        #expect(hasMuteWordCause(decision))
    }
}
