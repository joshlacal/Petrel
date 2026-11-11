import Foundation
@testable import Petrel
import Testing

/// One row of the `TESTS` tables in `tests/moderation-custom-labels.test.ts`
/// and `tests/moderation-quoteposts.test.ts`.
struct ModerationCustomLabelScenario: Decodable, Sendable {
    var blurs: String
    var severity: String
    var account: ExpectedBehaviors
    var profile: ExpectedBehaviors
    var post: ExpectedBehaviors

    /// A row expanded into one case per label target, as the reference suites do.
    struct Case: Sendable, CustomTestStringConvertible {
        var blurs: String
        var severity: String
        var target: String
        var expected: ExpectedBehaviors

        var testDescription: String {
            "blurs=\(blurs), severity=\(severity), target=\(target)"
        }
    }

    var cases: [Case] {
        [
            Case(blurs: blurs, severity: severity, target: "post", expected: post),
            Case(blurs: blurs, severity: severity, target: "profile", expected: profile),
            Case(blurs: blurs, severity: severity, target: "account", expected: account),
        ]
    }

    static func cases(_ vector: String) -> [Case] {
        ((try? ModerationVectors.load([ModerationCustomLabelScenario].self, vector)) ?? []).flatMap(\.cases)
    }

    /// `modOpts(blurs, severity)`: one subscribed labeler defining `custom`, set to hide.
    static func options(blurs: String, severity: String) throws -> ModerationOptions {
        let labeler = try ModerationMock.did("did:web:labeler.test")
        let definition = try Moderation.interpretLabelValueDefinition(
            ModerationMock.decode(
                ComAtprotoLabelDefs.LabelValueDefinition.self,
                [
                    "identifier": "custom",
                    "blurs": blurs,
                    "severity": severity,
                    "defaultSetting": "warn",
                    "locales": [Any](),
                ] as JSONObject
            ),
            definedBy: labeler
        )
        return try ModerationOptions(
            userDid: ModerationMock.did("did:web:alice.test"),
            prefs: ModerationPrefs(
                adultContentEnabled: true,
                labels: [:],
                labelers: [ModerationPrefsLabeler(did: labeler, labels: ["custom": .hide])],
                mutedWords: [],
                hiddenPosts: []
            ),
            labelDefs: [labeler: [definition]]
        )
    }
}

@Suite("Moderation: custom labels")
struct ModerationCustomLabelsTests {
    @Test("The vendored tables are complete")
    func vectorsLoad() throws {
        let custom = try ModerationVectors.load([ModerationCustomLabelScenario].self, "custom-labels")
        let quotes = try ModerationVectors.load([ModerationCustomLabelScenario].self, "quoteposts")
        #expect(custom.count == 9)
        #expect(quotes.count == 9)
        #expect(ModerationCustomLabelScenario.cases("custom-labels").count == 27)
        #expect(ModerationCustomLabelScenario.cases("quoteposts").count == 27)
    }

    /// Port of `tests/moderation-custom-labels.test.ts`.
    @Test("Custom label on the subject", arguments: ModerationCustomLabelScenario.cases("custom-labels"))
    func customLabel(_ scenario: ModerationCustomLabelScenario.Case) throws {
        let options = try ModerationCustomLabelScenario.options(blurs: scenario.blurs, severity: scenario.severity)
        let labeler = "did:web:labeler.test"

        let decision: ModerationDecision
        switch scenario.target {
        case "post":
            decision = try Moderation.moderatePost(
                ModerationMock.postView(
                    record: ModerationMock.post(text: "Hello", langs: nil),
                    author: ModerationMock.profile(handle: "bob.test", displayName: "Bob"),
                    labels: [
                        ModerationMock.label(
                            val: "custom",
                            uri: "at://did:web:bob.test/app.bsky.feed.post/fake",
                            src: labeler
                        ),
                    ]
                ),
                options: options
            )
        case "profile":
            decision = try Moderation.moderateProfile(
                ModerationMock.profileViewBasic(
                    handle: "bob.test",
                    displayName: "Bob",
                    labels: [
                        ModerationMock.label(
                            val: "custom",
                            uri: "at://did:web:bob.test/app.bsky.actor.profile/self",
                            src: labeler
                        ),
                    ]
                ),
                options: options
            )
        default:
            decision = try Moderation.moderateProfile(
                ModerationMock.profileViewBasic(
                    handle: "bob.test",
                    displayName: "Bob",
                    labels: [ModerationMock.label(val: "custom", uri: "did:web:bob.test", src: labeler)]
                ),
                options: options
            )
        }

        expectModerationResults(decision, scenario.expected, scenario.testDescription)
    }

    /// Port of `tests/moderation-quoteposts.test.ts`: the same labels on a
    /// quoted post only ever filter the quoting post, never blur or annotate it.
    @Test("Custom label on a quoted post", arguments: ModerationCustomLabelScenario.cases("quoteposts"))
    func customLabelOnQuotedPost(_ scenario: ModerationCustomLabelScenario.Case) throws {
        let options = try ModerationCustomLabelScenario.options(blurs: scenario.blurs, severity: scenario.severity)
        let labeler = "did:web:labeler.test"

        var postLabels: [JSONObject]?
        var profileLabels: [JSONObject]?
        switch scenario.target {
        case "post":
            postLabels = [
                ModerationMock.label(
                    val: "custom",
                    uri: "at://did:web:carla.test/app.bsky.feed.post/fake",
                    src: labeler
                ),
            ]
        case "profile":
            profileLabels = [
                ModerationMock.label(
                    val: "custom",
                    uri: "at://did:web:carla.test/app.bsky.actor.profile/self",
                    src: labeler
                ),
            ]
        default:
            profileLabels = [ModerationMock.label(val: "custom", uri: "did:web:carla.test", src: labeler)]
        }

        let post = try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello", langs: nil),
            author: ModerationMock.profile(handle: "bob.test", displayName: "Bob"),
            embed: ModerationMock.embedRecordView(
                record: ModerationMock.post(text: "Quoted post text"),
                author: ModerationMock.profile(handle: "carla.test", displayName: "Carla", labels: profileLabels),
                labels: postLabels
            )
        )
        let decision = Moderation.moderatePost(post, options: options)

        expectModerationResults(decision, scenario.expected, scenario.testDescription)
    }
}
