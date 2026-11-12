import Foundation
@testable import Petrel
import Testing

// Helpers run over responses recorded from the public Bluesky AppView
// (see Vectors/bsky-recorded/README.md).

private func recorded(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Vectors/bsky-recorded") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

@Suite("Recorded AppView responses")
struct BskyRecordedFixtureTests {
    @Test("the Bluesky moderation service's label definitions are interpreted as published")
    func labelerDefinitions() throws {
        let data = try recorded("labeler-services")
        let output = try JSONDecoder().decode(AppBskyLabelerGetServices.Output.self, from: data)
        guard case let .appBskyLabelerDefsLabelerViewDetailed(view)? = output.views.first else {
            Issue.record("expected a detailed labeler view")
            return
        }
        #expect(view.creator.did == BskyAgent.bskyLabelerDID)

        let published = try #require(
            try BskyJSON.parse(data)["views"]?.arrayValue?.first?["policies"]?["labelValueDefinitions"]?.arrayValue
        )
        let interpreted = Moderation.interpretLabelValueDefinitions(view)
        #expect(interpreted.count == published.count)
        #expect(published.count >= 10)

        for (definition, raw) in zip(interpreted, published) {
            let identifier = raw["identifier"]?.stringValue ?? ""
            #expect(definition.identifier == identifier)
            #expect(definition.definedBy == view.creator.did)
            #expect(definition.configurable)

            let rawDefault = raw["defaultSetting"]?.stringValue
            let expectedDefault: LabelPreference = rawDefault == "hide" ? .hide : rawDefault == "ignore" ? .ignore : .warn
            #expect(definition.defaultSetting == expectedDefault, "\(identifier)")

            let adultOnly = raw["adultOnly"]?.boolValue ?? false
            #expect(definition.flags.contains(.adult) == adultOnly, "\(identifier)")
            #expect(definition.flags.contains(.noSelf), "\(identifier)")

            let notice: ModerationBehavior.Action? = switch raw["severity"]?.stringValue {
            case "alert": .alert
            case "inform": .inform
            default: nil
            }
            switch raw["blurs"]?.stringValue {
            case "content":
                #expect(definition.behaviors.content.contentList == .blur, "\(identifier)")
                #expect(definition.behaviors.content.contentView == (adultOnly ? .blur : notice), "\(identifier)")
                #expect(definition.behaviors.account.profileList == notice, "\(identifier)")
            case "media":
                #expect(definition.behaviors.content.contentMedia == .blur, "\(identifier)")
                #expect(definition.behaviors.account.avatar == .blur, "\(identifier)")
                #expect(definition.behaviors.content.contentList == nil, "\(identifier)")
            case "none":
                #expect(definition.behaviors.content.contentList == notice, "\(identifier)")
                #expect(definition.behaviors.content.contentMedia == nil, "\(identifier)")
            default:
                Issue.record("unexpected blurs value for \(identifier)")
            }
        }
    }

    @Test("a label from the recorded labeler moderates a post according to its published definition")
    func recordedDefinitionDrivesDecision() throws {
        let output = try JSONDecoder().decode(AppBskyLabelerGetServices.Output.self, from: recorded("labeler-services"))
        guard case let .appBskyLabelerDefsLabelerViewDetailed(view)? = output.views.first else {
            Issue.record("expected a detailed labeler view")
            return
        }
        let labeler = view.creator.did
        let definitions = Moderation.interpretLabelValueDefinitions(view)
        // A custom (non built-in) value that hides by default and blurs content.
        let definition = try #require(definitions.first {
            $0.blurs == "content" && $0.defaultSetting == .hide && KnownLabels.definitions[$0.identifier] == nil
        })

        let post = try BskyJSON.object([
            "uri": "at://did:plc:bob/app.bsky.feed.post/3kpost",
            "cid": "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq",
            "author": ["did": "did:plc:bob", "handle": "bob.test"],
            "record": ["$type": "app.bsky.feed.post", "text": "hello", "createdAt": "2024-01-01T00:00:00.000Z"],
            "indexedAt": "2024-01-01T00:00:00.000Z",
            "labels": [[
                "src": .string(labeler.didString()),
                "uri": "at://did:plc:bob/app.bsky.feed.post/3kpost",
                "val": .string(definition.identifier),
                "cts": "2024-01-01T00:00:00.000Z",
            ]],
        ]).decoded(as: AppBskyFeedDefs.PostView.self)
        let prefs = ModerationPrefs(labelers: [ModerationPrefsLabeler(did: labeler)])

        // With the labeler's definitions the label filters and blurs the post…
        let informed = Moderation.moderatePost(
            post, options: ModerationOptions(userDid: nil, prefs: prefs, labelDefs: [labeler: definitions])
        ).ui(.contentList)
        #expect(informed.filter)
        #expect(informed.blur)

        // …and without them the value is unknown and therefore ignored.
        let uninformed = Moderation.moderatePost(post, options: ModerationOptions(userDid: nil, prefs: prefs))
            .ui(.contentList)
        #expect(!uninformed.filter && !uninformed.blur)
    }

    @Test("a recorded profile decodes, moderates cleanly and maps to its web address")
    func profile() throws {
        let profile = try JSONDecoder().decode(AppBskyActorDefs.ProfileViewDetailed.self, from: recorded("profile"))
        #expect(profile.handle.description == "bsky.app")
        #expect(profile.did.didString() == "did:plc:z72i7hdynmk6r22z27h6tvur")
        #expect((profile.followersCount ?? 0) > 1_000_000)

        let decision = Moderation.moderateProfile(profile, options: ModerationOptions(userDid: nil, prefs: ModerationPrefs()))
        for context in ModerationBehavior.Context.allCases {
            let ui = decision.ui(context)
            #expect(!ui.filter && !ui.blur && !ui.alert && !ui.inform, "\(context)")
        }

        let uri = try ATProtocolURI(uriString: "at://\(profile.did.didString())")
        #expect(BskyAppURL.url(for: uri, handle: profile.handle.description)?.absoluteString
            == "https://bsky.app/profile/bsky.app")
        if let description = profile.description {
            // The profile text is plain; detection over it must agree with its own byte ranges.
            let richText = RichText(text: description)
            for detection in RichText.detect(in: description) {
                #expect(!richText.slice(byteStart: detection.byteStart, byteEnd: detection.byteEnd).isEmpty)
            }
        }
    }
}
