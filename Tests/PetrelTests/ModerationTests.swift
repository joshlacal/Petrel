import Foundation
@testable import Petrel
import Testing

/// Port of `tests/moderation.test.ts`.
@Suite("Moderation")
struct ModerationTests {
    private let labeler = "did:web:labeler.test"

    private func options(
        adultContentEnabled: Bool = true,
        labels: [String: LabelPreference] = [:],
        labelers: [String: [String: LabelPreference]] = [:],
        labelDefs: [JSONObject] = []
    ) throws -> ModerationOptions {
        let labelerDid = try ModerationMock.did(labeler)
        let definitions = try labelDefs.map {
            try Moderation.interpretLabelValueDefinition(
                ModerationMock.decode(ComAtprotoLabelDefs.LabelValueDefinition.self, $0),
                definedBy: labelerDid
            )
        }
        return try ModerationOptions(
            userDid: ModerationMock.did("did:web:alice.test"),
            prefs: ModerationPrefs(
                adultContentEnabled: adultContentEnabled,
                labels: labels,
                labelers: labelers.map { try ModerationPrefsLabeler(did: ModerationMock.did($0.key), labels: $0.value) },
                mutedWords: [],
                hiddenPosts: []
            ),
            labelDefs: definitions.isEmpty ? [:] : [labelerDid: definitions]
        )
    }

    private func definition(
        _ identifier: String,
        blurs: String,
        severity: String,
        defaultSetting: String,
        adultOnly: Bool? = nil
    ) -> JSONObject {
        var definition: JSONObject = [
            "identifier": identifier,
            "blurs": blurs,
            "severity": severity,
            "defaultSetting": defaultSetting,
            "locales": [Any](),
        ]
        if let adultOnly { definition["adultOnly"] = adultOnly }
        return definition
    }

    private func bobProfile(labelSource: String, value: String) throws -> AppBskyActorDefs.ProfileViewBasic {
        try ModerationMock.profileViewBasic(
            handle: "bob.test",
            displayName: "Bob",
            labels: [
                ModerationMock.label(
                    val: value,
                    uri: "at://did:web:bob.test/app.bsky.actor.profile/self",
                    src: labelSource
                ),
            ]
        )
    }

    /// A post by Bob carrying the given label values from the test labeler.
    private func bobPost(labels values: [String]) throws -> AppBskyFeedDefs.PostView {
        try ModerationMock.postView(
            record: ModerationMock.post(text: "Hello", langs: nil),
            author: ModerationMock.profile(handle: "bob.test", displayName: "Bob"),
            labels: values.map {
                ModerationMock.label(val: $0, uri: "at://did:web:bob.test/app.bsky.post/fake", src: labeler)
            }
        )
    }

    private func expectNoModeration(_ decision: ModerationDecision, sourceLocation: SourceLocation = #_sourceLocation) {
        expectModerationResults(decision, ExpectedBehaviors(), sourceLocation: sourceLocation)
    }

    @Test("Applies self-labels on profiles according to the global preferences")
    func selfLabelsOnProfiles() throws {
        // porn (hide)
        let hidden = try Moderation.moderateProfile(
            bobProfile(labelSource: "did:web:bob.test", value: "porn"),
            options: options(labels: ["porn": .hide])
        )
        expectModerationResult(hidden.ui(.avatar), ["blur"], "post avatar")

        // porn (ignore)
        let ignored = try Moderation.moderateProfile(
            bobProfile(labelSource: "did:web:bob.test", value: "porn"),
            options: options(labels: ["porn": .ignore])
        )
        expectModerationResult(ignored.ui(.avatar), [], "post avatar")
    }

    @Test("Ignores labels from unsubscribed moderators or ignored labels for a moderator")
    func unsubscribedOrIgnoredLabelers() throws {
        // porn (moderator disabled)
        let unsubscribed = try Moderation.moderateProfile(
            bobProfile(labelSource: labeler, value: "porn"),
            options: options(labels: ["porn": .hide])
        )
        expectNoModeration(unsubscribed)

        // porn (label group disabled)
        let ignored = try Moderation.moderateProfile(
            bobProfile(labelSource: labeler, value: "porn"),
            options: options(labels: ["porn": .ignore], labelers: [labeler: ["porn": .ignore]])
        )
        expectNoModeration(ignored)
    }

    @Test("Can manually apply hiding")
    func manualHiding() throws {
        var decision = try Moderation.moderatePost(
            bobPost(labels: []),
            options: options(labelers: [labeler: [:]])
        )
        decision.addHidden(true)
        expectModerationResult(decision.ui(.contentList), ["filter", "blur"], "contentList")
        expectModerationResult(decision.ui(.contentView), ["blur"], "contentView")
    }

    @Test("Prioritizes filters and blurs correctly on merge")
    func prioritizesFiltersAndBlurs() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["porn", "!hide"]),
            options: options(labels: ["porn": .hide], labelers: [labeler: [:]])
        )
        let list = decision.ui(.contentList)
        #expect(list.filters.map { $0.labelCause?.label.val } == ["!hide", "porn"])
        #expect(list.blurs.first?.labelCause?.label.val == "!hide")
        #expect(decision.ui(.contentMedia).blurs.first?.labelCause?.label.val == "porn")
    }

    @Test("Prioritizes custom label definitions")
    func prioritizesCustomDefinitions() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["porn"]),
            options: options(
                labels: ["porn": .warn],
                labelers: [labeler: ["porn": .warn]],
                labelDefs: [definition("porn", blurs: "none", severity: "inform", defaultSetting: "warn")]
            )
        )
        expectModerationResults(
            decision,
            ExpectedBehaviors(contentList: ["inform"], contentView: ["inform"])
        )
    }

    @Test("Doesnt allow custom behaviors to override imperative labels")
    func imperativeLabelsCannotBeRedefined() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["!hide"]),
            options: options(
                labelers: [labeler: [:]],
                labelDefs: [definition("!hide", blurs: "none", severity: "inform", defaultSetting: "warn")]
            )
        )
        expectModerationResults(
            decision,
            ExpectedBehaviors(
                contentList: ["filter", "blur", "noOverride"],
                contentView: ["blur", "noOverride"]
            )
        )
    }

    @Test("Ignores invalid label value names")
    func ignoresInvalidLabelValueNames() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["BadLabel", "bad/label"]),
            options: options(
                labelers: [labeler: ["BadLabel": .hide, "bad/label": .hide]],
                labelDefs: [
                    definition("BadLabel", blurs: "content", severity: "inform", defaultSetting: "warn"),
                    definition("bad/label", blurs: "content", severity: "inform", defaultSetting: "warn"),
                ]
            )
        )
        expectNoModeration(decision)
    }

    @Test("Custom labels can set the default setting")
    func customLabelsSetDefaultSetting() throws {
        let opts = try options(
            labelers: [labeler: [:]],
            labelDefs: [
                definition("default-hide", blurs: "content", severity: "inform", defaultSetting: "hide"),
                definition("default-warn", blurs: "content", severity: "inform", defaultSetting: "warn"),
                definition("default-ignore", blurs: "content", severity: "inform", defaultSetting: "ignore"),
            ]
        )

        let hide = try Moderation.moderatePost(bobPost(labels: ["default-hide"]), options: opts)
        expectModerationResults(
            hide,
            ExpectedBehaviors(contentList: ["filter", "blur"], contentView: ["inform"])
        )

        let warn = try Moderation.moderatePost(bobPost(labels: ["default-warn"]), options: opts)
        expectModerationResults(
            warn,
            ExpectedBehaviors(contentList: ["blur"], contentView: ["inform"])
        )

        let ignore = try Moderation.moderatePost(bobPost(labels: ["default-ignore"]), options: opts)
        expectNoModeration(ignore)
    }

    @Test("Custom labels can require adult content to be enabled")
    func customLabelsCanRequireAdultContent() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["adult"]),
            options: options(
                adultContentEnabled: false,
                labels: ["adult": .ignore],
                labelers: [labeler: ["adult": .ignore]],
                labelDefs: [
                    definition("adult", blurs: "content", severity: "inform", defaultSetting: "hide", adultOnly: true),
                ]
            )
        )
        expectModerationResults(
            decision,
            ExpectedBehaviors(
                contentList: ["filter", "blur", "noOverride"],
                contentView: ["blur", "noOverride"]
            )
        )
    }

    @Test("Adult content disabled forces the preference to hide")
    func adultContentDisabledForcesHide() throws {
        let decision = try Moderation.moderatePost(
            bobPost(labels: ["porn"]),
            options: options(
                adultContentEnabled: false,
                labels: ["porn": .ignore],
                labelers: [labeler: [:]]
            )
        )
        expectModerationResults(
            decision,
            ExpectedBehaviors(contentList: ["filter"], contentMedia: ["blur", "noOverride"])
        )
    }
}
