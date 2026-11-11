import Foundation
@testable import Petrel
import Testing

/// The built-in label table must equal `definitions/labels.json` of
/// `@atproto/api`, expanded the way its `scripts/code/labels.mjs` does.
@Suite("Moderation: built-in label definitions")
struct ModerationLabelDefinitionsTests {
    private struct Definition: Decodable {
        struct Behaviors: Decodable {
            var account: [String: String]?
            var profile: [String: String]?
            var content: [String: String]?
        }

        var identifier: String
        var alias: [String]?
        var configurable: Bool
        var defaultSetting: String
        var flags: [String]
        var severity: String
        var blurs: String
        var behaviors: Behaviors
    }

    private func definitions() throws -> [Definition] {
        try ModerationVectors.load([Definition].self, "labels")
    }

    private func expectBehavior(
        _ actual: ModerationBehavior,
        equals expected: [String: String]?,
        _ name: String
    ) {
        let expected = expected ?? [:]
        let known = Set(ModerationBehavior.Context.allCases.map(\.rawValue))
        #expect(Set(expected.keys).isSubset(of: known), "\(name): unknown context in vector")
        for context in ModerationBehavior.Context.allCases {
            #expect(
                actual[context]?.rawValue == expected[context.rawValue],
                "\(name).\(context.rawValue)"
            )
        }
    }

    private func expect(_ actual: InterpretedLabelValueDefinition?, matches definition: Definition, as identifier: String) {
        guard let actual else {
            Issue.record("Missing built-in definition for \(identifier)")
            return
        }
        #expect(actual.identifier == identifier)
        #expect(actual.configurable == definition.configurable, "\(identifier).configurable")
        #expect(actual.defaultSetting.rawValue == definition.defaultSetting, "\(identifier).defaultSetting")
        #expect(actual.flags.map(\.rawValue) == definition.flags, "\(identifier).flags")
        #expect(actual.severity == definition.severity, "\(identifier).severity")
        #expect(actual.blurs == definition.blurs, "\(identifier).blurs")
        #expect(actual.locales.isEmpty, "\(identifier).locales")
        #expect(actual.definedBy == nil, "\(identifier).definedBy")
        expectBehavior(actual.behaviors.account, equals: definition.behaviors.account, "\(identifier).account")
        expectBehavior(actual.behaviors.profile, equals: definition.behaviors.profile, "\(identifier).profile")
        expectBehavior(actual.behaviors.content, equals: definition.behaviors.content, "\(identifier).content")
    }

    @Test("Every definition and alias in labels.json has an identical built-in entry")
    func tableMatchesVendoredDefinitions() throws {
        let definitions = try definitions()
        #expect(definitions.count == 7)

        var expectedIdentifiers: Set<String> = []
        for definition in definitions {
            expectedIdentifiers.insert(definition.identifier)
            expect(KnownLabels.definitions[definition.identifier], matches: definition, as: definition.identifier)
            for alias in definition.alias ?? [] {
                expectedIdentifiers.insert(alias)
                expect(KnownLabels.definitions[alias], matches: definition, as: alias)
            }
        }
        #expect(Set(KnownLabels.definitions.keys) == expectedIdentifiers)
    }

    @Test("Default settings are the defaults of the configurable definitions")
    func defaultSettingsMatchVendoredDefinitions() throws {
        var expected: [String: String] = [:]
        for definition in try definitions() where definition.configurable {
            expected[definition.identifier] = definition.defaultSetting
        }
        #expect(KnownLabels.defaultSettings.mapValues(\.rawValue) == expected)
    }

    @Test("Custom label value syntax is lowercase letters and hyphens only")
    func customLabelValueSyntax() {
        for valid in ["custom", "default-hide", "a", "-", "a-b-c"] {
            #expect(ModerationDecision.isCustomLabelValue(valid), "\(valid)")
        }
        for invalid in ["", "BadLabel", "bad/label", "!hide", "porn1", "has space", "ünï", "trailing\n"] {
            #expect(!ModerationDecision.isCustomLabelValue(invalid), "\(invalid)")
        }
    }
}
