import Foundation
@testable import Petrel
import Testing

/// Coverage for the subjects and decision mechanics the reference suites do not
/// exercise directly: notifications, feed generators, user lists, statuses,
/// blocked and hidden quotes, alt text and link cards, and tolerance of data
/// this SDK version does not know.
@Suite("Moderation: subjects and decision mechanics")
struct ModerationSubjectsTests {
    private let labeler = "did:web:labeler.test"
    private let alice = "did:web:alice.test"

    private func options(
        viewer: String? = "did:web:alice.test",
        adultContentEnabled: Bool = false,
        labels: [String: LabelPreference] = [:],
        mutedWords: [AppBskyActorDefs.MutedWord] = [],
        hiddenPosts: [String] = []
    ) throws -> ModerationOptions {
        try ModerationOptions(
            userDid: viewer.map { try ModerationMock.did($0) },
            prefs: ModerationPrefs(
                adultContentEnabled: adultContentEnabled,
                labels: labels,
                labelers: [ModerationPrefsLabeler(did: ModerationMock.did(labeler))],
                mutedWords: mutedWords,
                hiddenPosts: hiddenPosts.map { try ATProtocolURI(uriString: $0) }
            )
        )
    }

    private func label(_ value: String, on uri: String, from source: String? = nil) -> JSONObject {
        ModerationMock.label(val: value, uri: uri, src: source ?? labeler)
    }

    private var bob: JSONObject {
        ModerationMock.profile(handle: "bob.test", displayName: "Bob")
    }

    // MARK: Notifications

    private func notification(author: JSONObject, labels: [JSONObject]) throws -> AppBskyNotificationListNotifications.Notification {
        let did = author["did"] as? String ?? ""
        return try ModerationMock.decode([
            "uri": "at://\(did)/app.bsky.feed.post/fake",
            "cid": ModerationMock.fakeCID,
            "author": author,
            "reason": "reply",
            "reasonSubject": "at://\(did)/app.bsky.feed.post/fake-parent",
            "record": ModerationMock.post(text: "Reply"),
            "isRead": false,
            "indexedAt": ModerationMock.timestamp,
            "labels": labels,
        ] as JSONObject)
    }

    @Test("Notification: content labels and the author's account are both evaluated")
    func notificationLabelsAndAuthor() throws {
        let author = ModerationMock.profile(handle: "bob.test", viewer: ["muted": true])
        let decision = try Moderation.moderateNotification(
            notification(
                author: author,
                labels: [label("!hide", on: "at://did:web:bob.test/app.bsky.feed.post/fake")]
            ),
            options: options()
        )
        #expect(decision.did?.didString() == "did:web:bob.test")
        #expect(decision.isMe == false)
        #expect(decision.causes.map(\.type) == [.label, .muted])
        #expect(decision.muted)
        expectModerationResult(decision.ui(.contentList), ["filter", "blur", "noOverride"], "contentList")
        expectModerationResult(decision.ui(.contentView), ["blur", "inform", "noOverride"], "contentView")
    }

    @Test("Notification: an unlabeled notification from an ordinary account is untouched")
    func notificationClean() throws {
        let decision = try Moderation.moderateNotification(notification(author: bob, labels: []), options: options())
        #expect(decision.causes.isEmpty)
        expectModerationResults(decision, ExpectedBehaviors())
    }

    // MARK: Feed generators

    private func feedGenerator(creator: JSONObject, labels: [JSONObject]) throws -> AppBskyFeedDefs.GeneratorView {
        let did = creator["did"] as? String ?? ""
        return try ModerationMock.decode([
            "uri": "at://\(did)/app.bsky.feed.generator/fake",
            "cid": ModerationMock.fakeCID,
            "did": "did:web:feed.test",
            "creator": creator,
            "displayName": "Fake feed",
            "indexedAt": ModerationMock.timestamp,
            "labels": labels,
        ] as JSONObject)
    }

    @Test("Feed generator: labels on the feed are content labels; the creator's blocks apply")
    func feedGeneratorLabelsAndCreator() throws {
        let creator = ModerationMock.profile(
            handle: "bob.test",
            viewer: ["blocking": "at://did:web:alice.test/app.bsky.graph.block/fake"]
        )
        let decision = try Moderation.moderateFeedGenerator(
            feedGenerator(
                creator: creator,
                labels: [label("porn", on: "at://did:web:bob.test/app.bsky.feed.generator/fake")]
            ),
            options: options()
        )
        #expect(decision.causes.map(\.type) == [.label, .blocking])
        #expect(decision.blocked)
        // Adult content is disabled, so porn hides and cannot be overridden.
        expectModerationResult(decision.ui(.contentMedia), ["blur", "noOverride"], "contentMedia")
        let list = decision.ui(.contentList)
        #expect(list.filters.map(\.type) == [.label, .blocking])
        #expect(list.blurs.map(\.type) == [.blocking])
    }

    @Test("Feed generator: the viewer's own feed is never filtered or locked")
    func ownFeedGenerator() throws {
        let decision = try Moderation.moderateFeedGenerator(
            feedGenerator(
                creator: ModerationMock.profile(handle: "alice.test"),
                labels: [label("!hide", on: "at://did:web:alice.test/app.bsky.feed.generator/fake")]
            ),
            options: options()
        )
        #expect(decision.isMe)
        expectModerationResult(decision.ui(.contentList), ["blur"], "contentList")
    }

    // MARK: User lists

    private func listJSON(creator: JSONObject?, uri: String, labels: [JSONObject]) -> JSONObject {
        var list = ModerationMock.listViewBasic(name: "Fake list")
        list["uri"] = uri
        list["labels"] = labels
        if let creator { list["creator"] = creator }
        return list
    }

    @Test("User list with a creator view: list labels plus the creator's account")
    func userListWithCreator() throws {
        let creator = ModerationMock.profile(handle: "bob.test", viewer: ["blockedBy": true])
        let list: AppBskyGraphDefs.ListView = try ModerationMock.decode(
            listJSON(
                creator: creator,
                uri: "at://did:web:bob.test/app.bsky.graph.list/fake",
                labels: [label("!warn", on: "at://did:web:bob.test/app.bsky.graph.list/fake")]
            )
        )
        let decision = try Moderation.moderateUserList(list, options: options())
        #expect(decision.did?.didString() == "did:web:bob.test")
        #expect(decision.causes.map(\.type) == [.label, .blockedBy])
        expectModerationResult(decision.ui(.contentView), ["blur", "noOverride"], "contentView")
    }

    @Test("Basic user list: the creator is taken from the list URI")
    func basicUserListUsesURIAuthority() throws {
        let theirs: AppBskyGraphDefs.ListViewBasic = try ModerationMock.decode(
            listJSON(
                creator: nil,
                uri: "at://did:web:bob.test/app.bsky.graph.list/fake",
                labels: [label("!hide", on: "at://did:web:bob.test/app.bsky.graph.list/fake")]
            )
        )
        let theirDecision = try Moderation.moderateUserList(theirs, options: options())
        #expect(theirDecision.did?.didString() == "did:web:bob.test")
        #expect(!theirDecision.isMe)
        expectModerationResult(theirDecision.ui(.contentList), ["filter", "blur", "noOverride"], "theirs")

        let mine: AppBskyGraphDefs.ListViewBasic = try ModerationMock.decode(
            listJSON(
                creator: nil,
                uri: "at://did:web:alice.test/app.bsky.graph.list/fake",
                labels: [label("!hide", on: "at://did:web:alice.test/app.bsky.graph.list/fake")]
            )
        )
        let myDecision = try Moderation.moderateUserList(mine, options: options())
        #expect(myDecision.isMe)
        expectModerationResult(myDecision.ui(.contentList), ["blur"], "mine")
    }

    @Test("Basic user list addressed by handle has no creator DID and is not the viewer's")
    func basicUserListWithHandleAuthority() throws {
        let list: AppBskyGraphDefs.ListViewBasic = try ModerationMock.decode(
            listJSON(creator: nil, uri: "at://bob.test/app.bsky.graph.list/fake", labels: [])
        )
        let decision = try Moderation.moderateUserList(list, options: options())
        #expect(decision.did == nil)
        #expect(!decision.isMe)
        #expect(decision.causes.isEmpty)
    }

    // MARK: Status

    @Test("Status: labels on the status are content labels on top of the account's own")
    func statusLabels() throws {
        var profile = ModerationMock.profile(handle: "bob.test")
        profile["status"] = [
            "status": "app.bsky.actor.status#live",
            "record": ["$type": "app.bsky.actor.status", "status": "app.bsky.actor.status#live", "createdAt": ModerationMock.timestamp],
            "labels": [label("!warn", on: "at://did:web:bob.test/app.bsky.actor.status/self")],
        ] as JSONObject
        let subject: AppBskyActorDefs.ProfileViewBasic = try ModerationMock.decode(profile)
        #expect(subject.status != nil)

        let decision = try Moderation.moderateStatus(subject, options: options())
        #expect(decision.causes.map(\.type) == [.label])
        #expect(decision.causes.first?.labelCause?.target == .content)
        expectModerationResult(decision.ui(.contentView), ["blur"], "contentView")

        // The profile itself is not affected by a label on the status.
        let profileDecision = try Moderation.moderateProfile(subject, options: options())
        #expect(profileDecision.causes.isEmpty)
    }

    @Test("Status: a chat profile has no status and is evaluated as an account")
    func chatProfile() throws {
        let subject: ChatBskyActorDefs.ProfileViewBasic = try ModerationMock.decode([
            "did": "did:web:bob.test",
            "handle": "bob.test",
            "viewer": ["muted": true, "mutedByList": ModerationMock.listViewBasic(name: "Fake List")],
            "labels": [label("!hide", on: "did:web:bob.test")],
        ] as JSONObject)

        let decision = try Moderation.moderateProfile(subject, options: options())
        #expect(decision.causes.map(\.type) == [.muted, .label])
        if case let .list(list) = decision.muteCause?.source {
            #expect(list.name == "Fake List")
        } else {
            Issue.record("Expected the mute to be attributed to the list")
        }
        #expect(try Moderation.moderateStatus(subject, options: options()).causes.map(\.type) == [.muted, .label])
    }

    // MARK: Quoted posts

    private func blockedQuote(viewer: JSONObject) -> JSONObject {
        [
            "$type": "app.bsky.embed.record#view",
            "record": [
                "$type": "app.bsky.embed.record#viewBlocked",
                "uri": "at://did:web:carla.test/app.bsky.feed.post/fake",
                "blocked": true,
                "author": ["did": "did:web:carla.test", "viewer": viewer] as JSONObject,
            ] as JSONObject,
        ]
    }

    @Test("Blocked quote: the block is downgraded, so it filters but does not blur")
    func blockedQuotedPost() throws {
        let post = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello"),
            author: bob,
            embed: blockedQuote(viewer: ["blocking": "at://did:web:alice.test/app.bsky.graph.block/fake"])
        )
        let decision = try Moderation.moderatePost(post, options: options())
        #expect(decision.causes.count == 1)
        #expect(decision.causes.first?.type == .blocking)
        #expect(decision.causes.first?.downgraded == true)
        expectModerationResult(decision.ui(.contentList), ["filter"], "contentList")
        expectModerationResult(decision.ui(.contentView), [], "contentView")
    }

    @Test("Blocked quote alongside media: blocked-by and list blocks are found too")
    func blockedQuotedPostWithMedia() throws {
        let embed: JSONObject = [
            "$type": "app.bsky.embed.recordWithMedia#view",
            "record": blockedQuote(viewer: [
                "blockedBy": true,
                "blocking": "at://did:web:alice.test/app.bsky.graph.listblock/fake",
                "blockingByList": ModerationMock.listViewBasic(name: "Fake List"),
            ]),
            "media": [
                "$type": "app.bsky.embed.images#view",
                "images": [[
                    "thumb": "https://example.test/thumb.jpg",
                    "fullsize": "https://example.test/full.jpg",
                    "alt": "",
                ] as JSONObject],
            ] as JSONObject,
        ]
        let post = try ModerationMock.postView(record: ModerationMock.post(text: "Hello"), author: bob, embed: embed)
        let decision = try Moderation.moderatePost(post, options: options())
        #expect(decision.causes.map(\.type) == [.blocking, .blockedBy])
        #expect(decision.causes.allSatisfy { $0.downgraded })
        if case .list = decision.blockCause?.source {} else {
            Issue.record("Expected the block to be attributed to the list")
        }
    }

    @Test("Hidden posts: the post itself, a quoted post, and a quoted post next to media")
    func hiddenPosts() throws {
        let quotedURI = "at://did:web:carla.test/app.bsky.feed.post/fake"
        let quote = ModerationMock.embedRecordView(
            record: ModerationMock.post(text: "Quoted"),
            author: ModerationMock.profile(handle: "carla.test")
        )
        let plain = try ModerationMock.postView(record: ModerationMock.post(text: "Hello"), author: bob)
        let quoting = try ModerationMock.postView(record: ModerationMock.post(text: "Hello"), author: bob, embed: quote)
        let quotingWithMedia = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello"),
            author: bob,
            embed: [
                "$type": "app.bsky.embed.recordWithMedia#view",
                "record": quote,
                "media": [
                    "$type": "app.bsky.embed.external#view",
                    "external": ["uri": "https://example.test", "title": "Title", "description": "Description"],
                ] as JSONObject,
            ]
        )

        let hidingPost = try options(hiddenPosts: ["at://did:web:bob.test/app.bsky.feed.post/fake"])
        let hidingQuote = try options(hiddenPosts: ["at://did:web:dave.test/app.bsky.feed.post/other", quotedURI])
        let hidingNothingRelevant = try options(hiddenPosts: ["at://did:web:dave.test/app.bsky.feed.post/other"])

        for (name, decision) in [
            ("post", Moderation.moderatePost(plain, options: hidingPost)),
            ("quote", Moderation.moderatePost(quoting, options: hidingQuote)),
            ("quote with media", Moderation.moderatePost(quotingWithMedia, options: hidingQuote)),
        ] {
            #expect(decision.causes.map(\.type) == [.hidden], "\(name)")
            expectModerationResult(decision.ui(.contentList), ["filter", "blur"], name)
            expectModerationResult(decision.ui(.contentView), ["blur"], name)
        }
        #expect(Moderation.moderatePost(quoting, options: hidingNothingRelevant).causes.isEmpty)
        #expect(Moderation.moderatePost(plain, options: hidingQuote).causes.isEmpty)
    }

    @Test("Hidden posts: hiding applies to the viewer's own post as well")
    func hiddenOwnPost() throws {
        let mine = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello"),
            author: ModerationMock.profile(handle: "alice.test")
        )
        let decision = try Moderation.moderatePost(
            mine,
            options: options(hiddenPosts: ["at://did:web:alice.test/app.bsky.feed.post/fake"])
        )
        #expect(decision.isMe)
        expectModerationResult(decision.ui(.contentList), ["filter", "blur"], "contentList")
    }

    // MARK: Muted words outside the post text

    private func imagesRecord(_ alts: [String]) -> JSONObject {
        [
            "$type": "app.bsky.embed.images",
            "images": alts.map { ["image": ModerationMock.blob(), "alt": $0] as JSONObject },
        ]
    }

    private func externalView(title: String, description: String) -> JSONObject {
        [
            "$type": "app.bsky.embed.external#view",
            "external": ["uri": "https://example.test", "title": title, "description": description],
        ]
    }

    private func mutedWordPredicates(_ post: AppBskyFeedDefs.PostView) throws -> [String] {
        let decision = try Moderation.moderatePost(post, options: options(mutedWords: [ModerationMock.mutedWord("badword")]))
        return decision.causes.flatMap(\.matches).map(\.predicate)
    }

    @Test("Muted words match image alt text, link cards, and the quoted post's text, alt text and link card")
    func mutedWordsInAttachments() throws {
        let carla = ModerationMock.profile(handle: "carla.test")

        // image alt text on the post
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine", embed: imagesRecord(["ok", "a badword here"])),
                author: bob
            )
        ) == ["badword"])

        // link card on the post
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: externalView(title: "Title", description: "has badword inside")
            )
        ) == ["badword"])
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: externalView(title: "badword", description: "")
            )
        ) == ["badword"])

        // quoted post text
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: ModerationMock.embedRecordView(record: ModerationMock.post(text: "badword!"), author: carla)
            )
        ) == ["badword!"])

        // quoted post image alt text
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: ModerationMock.embedRecordView(
                    record: ModerationMock.post(text: "fine", embed: imagesRecord(["badword"])),
                    author: carla
                )
            )
        ) == ["badword"])

        // quoted post link card
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: ModerationMock.embedRecordView(
                    record: ModerationMock.post(
                        text: "fine",
                        embed: [
                            "$type": "app.bsky.embed.external",
                            "external": ["uri": "https://example.test", "title": "A badword", "description": "d"],
                        ]
                    ),
                    author: carla
                )
            )
        ) == ["badword"])

        // image alt text next to a quote
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: [
                    "$type": "app.bsky.embed.recordWithMedia#view",
                    "record": ModerationMock.embedRecordView(record: ModerationMock.post(text: "fine"), author: carla),
                    "media": [
                        "$type": "app.bsky.embed.images#view",
                        "images": [[
                            "thumb": "https://example.test/thumb.jpg",
                            "fullsize": "https://example.test/full.jpg",
                            "alt": "badword",
                        ] as JSONObject],
                    ] as JSONObject,
                ]
            )
        ) == ["badword"])

        // nothing anywhere
        #expect(try mutedWordPredicates(
            ModerationMock.postView(
                record: ModerationMock.post(text: "fine", embed: imagesRecord(["ok"])),
                author: bob,
                embed: externalView(title: "Title", description: "Description")
            )
        ).isEmpty)
    }

    @Test("Muted words in a quote follow the quoted author, not the quoting one")
    func mutedWordsUseQuotedAuthorForFollowExclusion() throws {
        let followedCarla = ModerationMock.profile(
            handle: "carla.test",
            viewer: ["following": "at://did:web:alice.test/app.bsky.graph.follow/fake"]
        )
        let post = try ModerationMock.postView(
            record: ModerationMock.post(text: "fine"),
            author: bob,
            embed: ModerationMock.embedRecordView(record: ModerationMock.post(text: "badword"), author: followedCarla)
        )
        let word = ModerationMock.mutedWord("badword", actorTarget: "exclude-following")
        #expect(try Moderation.moderatePost(post, options: options(mutedWords: [word])).causes.isEmpty)
    }

    @Test("Muted words in media next to a quote follow the author who attached it, not the quoted one")
    func mutedWordsUseOuterAuthorForMediaBesideQuote() throws {
        let followedCarla = ModerationMock.profile(
            handle: "carla.test",
            viewer: ["following": "at://did:web:alice.test/app.bsky.graph.follow/fake"]
        )
        let word = ModerationMock.mutedWord("badword", actorTarget: "exclude-following")
        let media: [String: JSONObject] = [
            "images": [
                "$type": "app.bsky.embed.images#view",
                "images": [[
                    "thumb": "https://example.test/thumb.jpg",
                    "fullsize": "https://example.test/full.jpg",
                    "alt": "badword",
                ] as JSONObject],
            ],
            "external": [
                "$type": "app.bsky.embed.external#view",
                "external": [
                    "uri": "https://example.test",
                    "title": "badword",
                    "description": "",
                ] as JSONObject,
            ],
        ]
        for (kind, view) in media {
            // An unfollowed author (bob) quotes a followed one (carla) and attaches the media.
            let unfollowedAttaches = try ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: bob,
                embed: [
                    "$type": "app.bsky.embed.recordWithMedia#view",
                    "record": ModerationMock.embedRecordView(record: ModerationMock.post(text: "fine"), author: followedCarla),
                    "media": view,
                ]
            )
            #expect(
                try !Moderation.moderatePost(unfollowedAttaches, options: options(mutedWords: [word])).causes.isEmpty,
                "\(kind) attached by an unfollowed author"
            )

            // A followed author quotes an unfollowed one and attaches the media.
            let followedAttaches = try ModerationMock.postView(
                record: ModerationMock.post(text: "fine"),
                author: followedCarla,
                embed: [
                    "$type": "app.bsky.embed.recordWithMedia#view",
                    "record": ModerationMock.embedRecordView(record: ModerationMock.post(text: "fine"), author: bob),
                    "media": view,
                ]
            )
            #expect(
                try Moderation.moderatePost(followedAttaches, options: options(mutedWords: [word])).causes.isEmpty,
                "\(kind) attached by a followed author"
            )
        }
    }

    // MARK: Decision mechanics

    @Test("Merge keeps the first decision's identity and concatenates causes in order")
    func mergeSemantics() throws {
        var first = try ModerationDecision(did: ModerationMock.did("did:web:bob.test"), isMe: true)
        first.addMuted(true)
        var second = try ModerationDecision(did: ModerationMock.did("did:web:carla.test"), isMe: false)
        second.addBlockedBy(true)
        second.addBlockOther(true)

        let merged = ModerationDecision.merge(nil, first, nil, second)
        #expect(merged.did == first.did)
        #expect(merged.isMe)
        #expect(merged.causes.map(\.type) == [.muted, .blockedBy, .blockOther])
        #expect(merged.causes.map(\.priority) == [6, 4, 4])

        let empty = ModerationDecision.merge(nil, nil)
        #expect(empty.did == nil)
        #expect(!empty.isMe)
        #expect(empty.causes.isEmpty)
    }

    @Test("Adders ignore false and nil; downgrade marks every cause")
    func addersAndDowngrade() {
        var decision = ModerationDecision()
        decision.addHidden(false)
        decision.addMuted(false)
        decision.addBlocking(false)
        decision.addBlockedBy(false)
        decision.addBlockOther(false)
        decision.addMutedByList(nil)
        decision.addBlockingByList(nil)
        decision.addMutedWord([])
        #expect(decision.causes.isEmpty)
        #expect(!decision.blocked)
        #expect(!decision.muted)
        #expect(decision.labelCauses.isEmpty)

        decision.addBlocking(true)
        decision.addHidden(true)
        #expect(decision.causes.allSatisfy { !$0.downgraded })
        let downgraded = decision.downgraded()
        #expect(downgraded.causes.allSatisfy { $0.downgraded })
        #expect(decision.causes.allSatisfy { !$0.downgraded })
        expectModerationResult(downgraded.ui(.contentList), ["filter"], "downgraded")
        expectModerationResult(decision.ui(.contentList), ["filter", "blur", "noOverride"], "original")
    }

    @Test("Blocks and mutes never apply to the viewer's own content; equal priorities keep their order")
    func ownContentAndStableOrder() throws {
        var mine = try ModerationDecision(did: ModerationMock.did(alice), isMe: true)
        mine.addBlocking(true)
        mine.addBlockedBy(true)
        mine.addMuted(true)
        mine.addMutedWord([MuteWordMatch(word: ModerationMock.mutedWord("x"), predicate: "x")])
        for context in ModerationBehavior.Context.allCases {
            expectModerationResult(mine.ui(context), [], context.rawValue)
        }

        var theirs = ModerationDecision()
        theirs.addMuted(true)
        theirs.addHidden(true)
        theirs.addBlockOther(true)
        theirs.addBlockedBy(true)
        theirs.addBlocking(true)
        let list = theirs.ui(.contentList)
        #expect(list.filters.map(\.type) == [.blocking, .blockOther, .blockedBy, .muted, .hidden])
        #expect(list.blurs.map(\.type) == [.blocking, .blockOther, .blockedBy, .muted, .hidden])
        #expect(list.noOverride)
    }

    @Test("Label causes record their source, target, setting and definition")
    func labelCauseDetails() throws {
        let subject = try ModerationMock.profileViewBasic(
            handle: "bob.test",
            labels: [
                label("porn", on: "did:web:bob.test"),
                label("sexual", on: "at://did:web:bob.test/app.bsky.actor.profile/self", from: "did:web:bob.test"),
                label("gore", on: "did:web:bob.test"),
                label("unknown-value", on: "did:web:bob.test"),
            ]
        )
        let decision = try Moderation.moderateProfile(
            subject,
            options: options(adultContentEnabled: true, labels: ["porn": .warn, "gore": .hide])
        )
        let causes = decision.labelCauses.compactMap { cause in cause.labelCause.map { (cause, $0) } }
        #expect(causes.map(\.1.label.val) == ["porn", "gore", "sexual"])

        let porn = try #require(causes.first)
        let labelerDid = try ModerationMock.did(labeler)
        #expect(porn.0.source == .labeler(labelerDid))
        #expect(porn.1.target == .account)
        #expect(porn.1.setting == .warn)
        #expect(porn.1.labelDef == KnownLabels.definitions["porn"])
        #expect(porn.1.behavior == ModerationBehavior(avatar: .blur, banner: .blur))
        #expect(!porn.1.noOverride)
        #expect(porn.0.priority == 8)

        // `gore` is an alias with its own identifier, so the setting stored under `gore` applies.
        let gore = causes[1]
        #expect(gore.1.labelDef.identifier == "gore")
        #expect(gore.1.setting == .hide)
        #expect(gore.0.priority == 2)

        // A self-label is attributed to the user and takes the default setting.
        let sexual = causes[2]
        #expect(sexual.0.source == .user)
        #expect(sexual.1.target == .profile)
        #expect(sexual.1.setting == .warn)
    }

    @Test("Label priority follows what the behavior covers")
    func labelPriorities() throws {
        let labelerDid = try ModerationMock.did(labeler)
        func definition(_ identifier: String, blurs: String) throws -> InterpretedLabelValueDefinition {
            try Moderation.interpretLabelValueDefinition(
                ModerationMock.decode(
                    ComAtprotoLabelDefs.LabelValueDefinition.self,
                    [
                        "identifier": identifier,
                        "blurs": blurs,
                        "severity": "alert",
                        "defaultSetting": "warn",
                        "locales": [Any](),
                    ] as JSONObject
                ),
                definedBy: labelerDid
            )
        }
        var opts = try options()
        opts.labelDefs = try [
            labelerDid: [definition("covers-content", blurs: "content"), definition("covers-media", blurs: "media"), definition("covers-nothing", blurs: "none")],
        ]
        let uri = "at://did:web:bob.test/app.bsky.feed.post/fake"
        let post = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello"),
            author: bob,
            labels: [
                label("covers-nothing", on: uri),
                label("covers-media", on: uri),
                label("covers-content", on: uri),
                label("!warn", on: uri),
                label("!hide", on: uri),
            ]
        )
        let decision = Moderation.moderatePost(post, options: opts)
        let priorities = Dictionary(
            decision.labelCauses.compactMap { cause in cause.labelCause.map { ($0.label.val, cause.priority) } },
            uniquingKeysWith: { first, _ in first }
        )
        #expect(priorities == [
            "!hide": 1,
            "!warn": 5,
            "covers-content": 7,
            "covers-media": 7,
            "covers-nothing": 8,
        ])
        #expect(decision.ui(.contentList).blurs.compactMap { $0.labelCause?.label.val } == ["!hide", "!warn", "covers-content"])
    }

    @Test("interpretLabelValueDefinitions expands every definition of a labeler view")
    func interpretsLabelerView() throws {
        let view: AppBskyLabelerDefs.LabelerViewDetailed = try ModerationMock.decode([
            "uri": "at://did:web:labeler.test/app.bsky.labeler.service/self",
            "cid": ModerationMock.fakeCID,
            "creator": ModerationMock.profile(handle: "labeler.test"),
            "policies": [
                "labelValues": ["spoiler", "adult-thing", "porn"],
                "labelValueDefinitions": [
                    [
                        "identifier": "spoiler",
                        "blurs": "content",
                        "severity": "inform",
                        "defaultSetting": "hide",
                        "locales": [["lang": "en", "name": "Spoiler", "description": "Reveals the plot"]],
                    ],
                    [
                        "identifier": "adult-thing",
                        "blurs": "media",
                        "severity": "none",
                        "adultOnly": true,
                        "locales": [Any](),
                    ],
                    [
                        "identifier": "mystery",
                        "blurs": "something-new",
                        "severity": "something-new",
                        "defaultSetting": "something-new",
                        "locales": [Any](),
                    ],
                ] as [JSONObject],
            ] as JSONObject,
            "indexedAt": ModerationMock.timestamp,
        ] as JSONObject)

        let definitions = Moderation.interpretLabelValueDefinitions(view)
        #expect(definitions.map(\.identifier) == ["spoiler", "adult-thing", "mystery"])
        #expect(definitions.allSatisfy { $0.definedBy == view.creator.did && $0.configurable })

        let spoiler = definitions[0]
        #expect(spoiler.defaultSetting == .hide)
        #expect(spoiler.flags == [.noSelf])
        #expect(!spoiler.adultOnly)
        #expect(spoiler.locales.map(\.name) == ["Spoiler"])
        #expect(spoiler.behaviors.account == ModerationBehavior(
            profileList: .inform, profileView: .inform, contentList: .blur, contentView: .inform
        ))
        #expect(spoiler.behaviors.profile == ModerationBehavior(profileList: .inform, profileView: .inform))
        #expect(spoiler.behaviors.content == ModerationBehavior(contentList: .blur, contentView: .inform))

        let adult = definitions[1]
        #expect(adult.defaultSetting == .warn)
        #expect(adult.flags == [.noSelf, .adult])
        #expect(adult.adultOnly)
        #expect(adult.behaviors.account == ModerationBehavior(avatar: .blur, banner: .blur))
        #expect(adult.behaviors.content == ModerationBehavior(contentMedia: .blur))

        // Values this version does not know produce a definition that does nothing visible.
        let mystery = definitions[2]
        #expect(mystery.defaultSetting == .warn)
        #expect(mystery.behaviors == InterpretedLabelValueDefinition.Behaviors())
    }

    // MARK: Tolerance

    @Test("Unknown embed types, unknown record types and unknown quoted records are ignored")
    func toleratesUnknownData() throws {
        let unknownEmbed = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello badword"),
            author: bob,
            embed: ["$type": "com.example.embed#view", "anything": ["nested": true]] as JSONObject
        )
        let unknownRecord = try ModerationMock.postView(
            record: ["$type": "com.example.record", "text": "badword", "createdAt": ModerationMock.timestamp],
            author: bob,
            embed: [
                "$type": "app.bsky.embed.record#view",
                "record": ["$type": "com.example.embed#viewSomething", "uri": "at://did:web:bob.test/x.y.z/1"] as JSONObject,
            ]
        )
        let notFoundQuote = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello"),
            author: bob,
            embed: [
                "$type": "app.bsky.embed.record#view",
                "record": [
                    "$type": "app.bsky.embed.record#viewNotFound",
                    "uri": "at://did:web:carla.test/app.bsky.feed.post/fake",
                    "notFound": true,
                ] as JSONObject,
            ]
        )
        let opts = try options(
            mutedWords: [ModerationMock.mutedWord("badword")],
            hiddenPosts: ["at://did:web:carla.test/app.bsky.feed.post/fake"]
        )

        #expect(Moderation.moderatePost(unknownEmbed, options: opts).causes.map(\.type) == [.muteWord])
        // The record is not a post, so its text is never read.
        #expect(Moderation.moderatePost(unknownRecord, options: opts).causes.isEmpty)
        // A quote that could not be loaded is not a quoted post: hiding its URI has no effect.
        #expect(Moderation.moderatePost(notFoundQuote, options: opts).causes.isEmpty)
    }

    @Test("Signed-out viewers: no account is 'me', and !no-unauthenticated applies")
    func signedOutViewer() throws {
        let subject = try ModerationMock.profileViewBasic(
            handle: "bob.test",
            labels: [label("!no-unauthenticated", on: "at://did:web:bob.test/app.bsky.actor.profile/self", from: "did:web:bob.test")]
        )
        let signedOut = try Moderation.moderateProfile(subject, options: options(viewer: nil))
        #expect(!signedOut.isMe)
        // A self-applied !no-unauthenticated on the profile record counts for the account and the profile.
        #expect(signedOut.labelCauses.compactMap { $0.labelCause?.target } == [.account, .profile])
        expectModerationResult(signedOut.ui(.profileView), ["blur", "noOverride"], "signed out")

        let signedIn = try Moderation.moderateProfile(subject, options: options())
        #expect(signedIn.causes.isEmpty)
    }
}
