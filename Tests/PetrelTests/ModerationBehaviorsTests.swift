import Foundation
@testable import Petrel
import Testing

/// Port of `tests/moderation-behaviors.test.ts`: the behavior matrix of
/// built-in labels, blocks and mutes across every UI context. The scenarios
/// are the reference suite's own tables, vendored as JSON.
struct ModerationBehaviorSuite: Decodable, Sendable {
    struct User: Decodable, Sendable {
        var blocking: Bool
        var blockingByList: Bool
        var blockedBy: Bool
        var muted: Bool
        var mutedByList: Bool
    }

    struct Configuration: Decodable, Sendable {
        var authed: Bool?
        var adultContentEnabled: Bool?
        var settings: [String: String]?
    }

    struct Labels: Decodable, Sendable {
        var post: [String]?
        var profile: [String]?
        var account: [String]?
        var quotedPost: [String]?
        var quotedAccount: [String]?
    }

    struct Scenario: Decodable, Sendable, CustomTestStringConvertible {
        var name: String
        var cfg: String
        var subject: String
        var author: String
        var quoteAuthor: String?
        var labels: Labels
        var behaviors: ExpectedBehaviors

        var testDescription: String {
            name
        }
    }

    var users: [String: User]
    var configurations: [String: Configuration]
    var scenarios: [Scenario]

    static let shared: ModerationBehaviorSuite? = try? ModerationVectors.load(ModerationBehaviorSuite.self, "behaviors")

    /// Scenarios whose name starts with `//` are disabled in the reference suite.
    static var enabledScenarios: [Scenario] {
        (shared?.scenarios ?? []).filter { !$0.name.hasPrefix("//") }
    }

    // MARK: ModerationBehaviorSuiteRunner

    func profile(_ name: String, account: [String]?, profile: [String]?) throws -> JSONObject {
        let user = try #require(users[name], "Unknown user \(name)")

        var labels: [JSONObject] = []
        for value in account ?? [] {
            labels.append(ModerationMock.label(val: value, uri: "did:web:\(name)"))
        }
        for value in profile ?? [] {
            labels.append(
                ModerationMock.label(val: value, uri: "at://did:web:\(name)/app.bsky.actor.profile/self")
            )
        }

        var viewer: JSONObject = [
            "muted": user.muted || user.mutedByList,
            "blockedBy": user.blockedBy,
        ]
        if user.mutedByList {
            viewer["mutedByList"] = ModerationMock.listViewBasic(name: "Fake List")
        }
        if user.blocking || user.blockingByList {
            viewer["blocking"] = "at://did:web:self.test/app.bsky.graph.block/fake"
        }
        if user.blockingByList {
            viewer["blockingByList"] = ModerationMock.listViewBasic(name: "Fake List")
        }

        return ModerationMock.profile(handle: "\(name).test", viewer: viewer, labels: labels)
    }

    func postScenario(_ scenario: Scenario) throws -> AppBskyFeedDefs.PostView {
        let author = try profile(scenario.author, account: scenario.labels.account, profile: scenario.labels.profile)
        let authorDid = author["did"] as? String ?? ""
        let postURI = "at://\(authorDid)/app.bsky.feed.post/fake"

        var embed: JSONObject?
        if let quoteAuthor = scenario.quoteAuthor {
            embed = try ModerationMock.embedRecordView(
                record: ModerationMock.post(text: "Quoted post text"),
                author: profile(quoteAuthor, account: scenario.labels.quotedAccount, profile: nil),
                labels: (scenario.labels.quotedPost ?? []).map { ModerationMock.label(val: $0, uri: postURI) }
            )
        }

        return try ModerationMock.postView(
            record: ModerationMock.post(text: "Post text"),
            author: author,
            embed: embed,
            labels: (scenario.labels.post ?? []).map { ModerationMock.label(val: $0, uri: postURI) }
        )
    }

    func profileScenario(_ scenario: Scenario) throws -> AppBskyActorDefs.ProfileViewBasic {
        try ModerationMock.decode(
            profile(scenario.author, account: scenario.labels.account, profile: scenario.labels.profile)
        )
    }

    func moderationOptions(_ scenario: Scenario) throws -> ModerationOptions {
        let configuration = try #require(configurations[scenario.cfg], "Unknown configuration \(scenario.cfg)")
        var labels: [String: LabelPreference] = [:]
        for (label, setting) in configuration.settings ?? [:] {
            let preference: LabelPreference = try #require(LabelPreference(rawValue: setting))
            labels[label] = preference
        }
        return try ModerationOptions(
            userDid: configuration.authed == false ? nil : ModerationMock.did("did:web:self.test"),
            prefs: ModerationPrefs(
                adultContentEnabled: configuration.adultContentEnabled ?? false,
                labels: labels,
                labelers: [ModerationPrefsLabeler(did: ModerationMock.did(ModerationMock.fakeLabeler))],
                mutedWords: [],
                hiddenPosts: []
            )
        )
    }
}

@Suite("Moderation: post and profile behaviors")
struct ModerationBehaviorsTests {
    @Test("The vendored behavior matrix is complete")
    func vectorsLoad() throws {
        let suite = try ModerationVectors.load(ModerationBehaviorSuite.self, "behaviors")
        #expect(suite.users.count == 8)
        #expect(suite.configurations.count == 13)
        #expect(suite.scenarios.count == 67)
        #expect(ModerationBehaviorSuite.enabledScenarios.count == 67)
        for scenario in suite.scenarios {
            #expect(suite.users[scenario.author] != nil, "\(scenario.name): author")
            #expect(suite.configurations[scenario.cfg] != nil, "\(scenario.name): cfg")
            #expect(["post", "profile"].contains(scenario.subject), "\(scenario.name): subject")
        }
    }

    @Test("Behavior scenario", arguments: ModerationBehaviorSuite.enabledScenarios)
    func scenario(_ scenario: ModerationBehaviorSuite.Scenario) throws {
        let suite = try #require(ModerationBehaviorSuite.shared)
        let options = try suite.moderationOptions(scenario)

        let decision: ModerationDecision
        var contexts: [ModerationBehavior.Context] = [
            .avatar, .banner, .displayName, .contentList, .contentView, .contentMedia,
        ]
        if scenario.subject == "profile" {
            decision = try Moderation.moderateProfile(suite.profileScenario(scenario), options: options)
            contexts = [.profileList, .profileView] + contexts
        } else {
            decision = try Moderation.moderatePost(suite.postScenario(scenario), options: options)
        }

        expectModerationResults(decision, scenario.behaviors, scenario.name, contexts: contexts)
    }
}
