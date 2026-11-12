import Foundation
import Petrel
import Testing

/// The usage examples of the moderation documentation, compiled and run.
/// These use only the public API (no `@testable`), as an app would.
@Suite("Moderation: documentation examples")
struct ModerationDocExampleTests {
    /// A post as `app.bsky.feed.getTimeline` returns it: labeled `porn` by a
    /// labeler, quoting nothing, written by an account the viewer muted.
    private func timelinePost() throws -> AppBskyFeedDefs.PostView {
        let json = """
        {
          "uri": "at://did:plc:author000000000000000000/app.bsky.feed.post/3kabc",
          "cid": "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq",
          "author": {
            "did": "did:plc:author000000000000000000",
            "handle": "author.example.com",
            "viewer": { "muted": true }
          },
          "record": {
            "$type": "app.bsky.feed.post",
            "text": "A post about spoilers",
            "createdAt": "2024-01-01T00:00:00.000Z"
          },
          "indexedAt": "2024-01-01T00:00:00.000Z",
          "labels": [
            {
              "src": "did:plc:ar7c4by46qjdydhdevvrndac",
              "uri": "at://did:plc:author000000000000000000/app.bsky.feed.post/3kabc",
              "val": "porn",
              "cts": "2024-01-01T00:00:00.000Z"
            }
          ]
        }
        """
        return try JSONDecoder().decode(AppBskyFeedDefs.PostView.self, from: Data(json.utf8))
    }

    @Test("Deciding how to show a post in a feed")
    func moderationUIDecision() throws {
        let post = try timelinePost()
        let viewer = try DID(didString: "did:plc:viewer000000000000000000")
        let bskyLabeler = try DID(didString: "did:plc:ar7c4by46qjdydhdevvrndac")

        // The viewer's settings. In an app these come from the account's
        // preferences; here they are written out.
        let prefs = ModerationPrefs(
            adultContentEnabled: true,
            labels: ["porn": .warn],
            labelers: [ModerationPrefsLabeler(did: bskyLabeler)],
            mutedWords: [AppBskyActorDefs.MutedWord(value: "spoilers", targets: [.content], actorTarget: "all")]
        )
        let options = ModerationOptions(userDid: viewer, prefs: prefs)

        let decision = Moderation.moderatePost(post, options: options)

        // In a feed: leave filtered posts out, cover blurred ones.
        let inFeed = decision.ui(.contentList)
        #expect(inFeed.filter) // the author is muted and the text has a muted word
        #expect(inFeed.blur)
        #expect(!inFeed.noOverride) // the user may tap "Show"

        // Media is decided separately from the post body.
        let media = decision.ui(.contentMedia)
        #expect(media.blur) // `porn` set to "warn" covers the media
        #expect(!media.noOverride)

        // Say why, from the causes behind the decision.
        var reasons: [String] = []
        for cause in inFeed.blurs + media.blurs {
            switch cause.kind {
            case let .label(label):
                reasons.append("Labeled \(label.labelDef.identifier)")
            case let .muteWord(matches):
                reasons.append("Muted word: \(matches.map(\.word.value).joined(separator: ", "))")
            case .muted:
                reasons.append("Muted account")
            case .blocking, .blockedBy, .blockOther:
                reasons.append("Blocked")
            case .hidden:
                reasons.append("Hidden by you")
            }
        }
        #expect(reasons == ["Muted word: spoilers", "Muted account", "Labeled porn"])

        // The same post for a viewer who has not enabled adult content: the
        // label hides it outright and the media cover cannot be removed.
        var strict = options
        strict.prefs.adultContentEnabled = false
        let strictMedia = Moderation.moderatePost(post, options: strict).ui(.contentMedia)
        #expect(strictMedia.blur)
        #expect(strictMedia.noOverride)
    }

    @Test("Using a labeler's own label definitions")
    func customLabelDefinitions() throws {
        // A labeler's service view, as `app.bsky.labeler.getServices(detailed: true)` returns it.
        let json = """
        {
          "uri": "at://did:plc:labeler0000000000000000/app.bsky.labeler.service/self",
          "cid": "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq",
          "creator": { "did": "did:plc:labeler0000000000000000", "handle": "labeler.example.com" },
          "policies": {
            "labelValues": ["spoiler"],
            "labelValueDefinitions": [
              {
                "identifier": "spoiler",
                "severity": "inform",
                "blurs": "content",
                "defaultSetting": "warn",
                "locales": [{ "lang": "en", "name": "Spoiler", "description": "Gives away the plot." }]
              }
            ]
          },
          "indexedAt": "2024-01-01T00:00:00.000Z"
        }
        """
        let labelerView = try JSONDecoder().decode(AppBskyLabelerDefs.LabelerViewDetailed.self, from: Data(json.utf8))
        let labeler = labelerView.creator.did

        let options = ModerationOptions(
            userDid: nil,
            prefs: ModerationPrefs(labelers: [ModerationPrefsLabeler(did: labeler, labels: ["spoiler": .hide])]),
            labelDefs: [labeler: Moderation.interpretLabelValueDefinitions(labelerView)]
        )

        let spoiler = ComAtprotoLabelDefs.Label(
            src: labeler,
            uri: URI(uriString: "at://did:plc:author000000000000000000/app.bsky.feed.post/3kabc"),
            val: "spoiler",
            cts: ATProtocolDate(date: Date(timeIntervalSince1970: 1_704_067_200))
        )
        var decision = ModerationDecision()
        decision.addLabel(.content, spoiler, options: options)

        let inFeed = decision.ui(.contentList)
        #expect(inFeed.filter) // the user chose "hide" for this labeler's `spoiler`
        #expect(inFeed.blur)
        #expect(decision.ui(.contentView).inform) // opened directly: a notice, not a cover
        #expect(inFeed.blurs.first?.source == .labeler(labeler))
    }
}
