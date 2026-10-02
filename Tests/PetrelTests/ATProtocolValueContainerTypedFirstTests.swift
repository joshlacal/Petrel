import Foundation
@_spi(Testing) @testable import Petrel
import Synchronization
import Testing

/// Differential tests for typed-first fidelity and the probe-order hints in
/// `ATProtocolValueContainer` (generator/templates/ATProtocolValueContainer.jinja).
///
/// Each case decodes the same bytes twice on the same `JSONDecoder` instance: once on the default
/// path (typed-first + hints, active only for Foundation's strict JSON decoder) and once inside
/// `withLegacyDynamicDecoding`, which runs the unchanged legacy raw-first path. Accepted values must
/// match in canonical JSON and in the known/unknown classification of every dynamic container;
/// rejections must match in error class, and in full description when the input has one error.
///
/// Foundation's `allKeys` order follows each dictionary's per-instance hash seed, so for a record
/// with several throwing fields even two legacy decodes can surface different keys. Multi-error
/// cases therefore compare the error class only.
@Suite("ATProtocolValueContainer typed-first differential")
struct ATProtocolValueContainerTypedFirstTests {
    // MARK: - Detection and toggle

    @Test("Foundation's JSONDecoder is strict; the toggle and other decoders are not")
    func strictDecoderDetection() throws {
        let decoder = JSONDecoder()
        #expect(try decoder.decode(StrictnessProbe.self, from: Data("{}".utf8)).isStrict)
        let legacy = try ATProtocolValueContainer.withLegacyDynamicDecoding {
            try decoder.decode(StrictnessProbe.self, from: Data("{}".utf8))
        }
        #expect(!legacy.isStrict)
        // The override is scoped to the task-local binding.
        #expect(try decoder.decode(StrictnessProbe.self, from: Data("{}".utf8)).isStrict)

        let inMemory = try StrictnessProbe(from: ATProtocolValueContainerDecoder(value: .object([:])))
        #expect(!inMemory.isStrict)
    }

    @Test("The legacy override does not leak into concurrently running tasks")
    func legacyOverrideIsTaskScoped() async throws {
        let data = Data("{}".utf8)
        let outside = Task.detached { try JSONDecoder().decode(StrictnessProbe.self, from: data).isStrict }
        let inside = try ATProtocolValueContainer.withLegacyDynamicDecoding {
            try JSONDecoder().decode(StrictnessProbe.self, from: data).isStrict
        }
        #expect(!inside)
        #expect(try await outside.value)
    }

    @Test("Typed-first skips the nested registry re-decode that the legacy raw pass performs")
    func typedFirstSkipsNestedRegistryDecodes() throws {
        TypedFirstProbeRegistration.ensureRegistered()
        let json = Data(#"{"$type":"test.petrel.typedFirst#record","child":{"$type":"test.petrel.typedFirst#child","name":"x"},"note":"n"}"#.utf8)
        let decoder = JSONDecoder()

        let typedBefore = TypedFirstProbeChild.initCount.load(ordering: .relaxed)
        let typedFirst = try decoder.decode(ATProtocolValueContainer.self, from: json)
        let typedCalls = TypedFirstProbeChild.initCount.load(ordering: .relaxed) - typedBefore

        let legacyBefore = TypedFirstProbeChild.initCount.load(ordering: .relaxed)
        let legacy = try ATProtocolValueContainer.withLegacyDynamicDecoding {
            try decoder.decode(ATProtocolValueContainer.self, from: json)
        }
        let legacyCalls = TypedFirstProbeChild.initCount.load(ordering: .relaxed) - legacyBefore

        #expect(signature(typedFirst) == signature(legacy))
        guard case let .knownType(value) = typedFirst else {
            Issue.record("expected .knownType, got \(typedFirst)")
            return
        }
        #expect(value is TypedFirstProbeRecord)
        // Legacy decodes the child once through the registry (raw pass) and once inside the
        // parent's typed decode; typed-first proves the child against the JSON instead.
        #expect(legacyCalls == 2)
        #expect(typedCalls == 1)
    }

    // MARK: - Registry

    @Test("Core registry entries are verified except ids whose Swift type has no typeIdentifier")
    func coreRegistryVerifiedBits() throws {
        let factory = ATProtocolValueContainer.decoderFactory
        for id in ["app.bsky.feed.post", "app.bsky.richtext.facet#link", "com.atproto.repo.strongRef", "app.bsky.embed.images"] {
            let entry = try #require(factory.entry(for: id))
            #expect(entry.typeIdentifierVerified, "\(id)")
            #expect(entry.isCoreID, "\(id)")
        }
        let preferences = try #require(factory.entry(for: "app.bsky.actor.defs#preferences"))
        #expect(!preferences.typeIdentifierVerified)
        #expect(factory.entry(for: "example.unregistered") == nil)
    }

    @Test("Overlay claims: first typed claim verified, closures and competing types never")
    func overlayClaimsVerifiedBits() throws {
        let factory = ATProtocolValueContainer.decoderFactory
        let idA = "test.petrel.typedFirst.claims#a"
        let idB = "test.petrel.typedFirst.claims#b"

        ATProtocolValueContainer.registerDecoder(forType: idA, as: ClaimProbeA.self)
        #expect(try #require(factory.entry(for: idA)).typeIdentifierVerified)
        ATProtocolValueContainer.registerDecoder(forType: idA, as: ClaimProbeA.self)
        #expect(try #require(factory.entry(for: idA)).typeIdentifierVerified, "re-registering the same type keeps the bit")
        ATProtocolValueContainer.registerDecoder(forType: idA, as: ClaimProbeAPrime.self)
        #expect(try !#require(factory.entry(for: idA)).typeIdentifierVerified, "a second Swift type breaks the invariant")
        ATProtocolValueContainer.registerDecoder(forType: idA, as: ClaimProbeA.self)
        #expect(try !#require(factory.entry(for: idA)).typeIdentifierVerified, "a broken id stays unverified")

        ATProtocolValueContainer.registerDecoder(forType: idB) { decoder in
            .knownType(try ClaimProbeB(from: decoder))
        }
        #expect(try !#require(factory.entry(for: idB)).typeIdentifierVerified, "closure registrations are unverified")
        #expect(try !#require(factory.entry(for: idB)).isCoreID)
    }

    /// Swan registers its own `ComAtprotoRepoApplyWrites` write types over the core ids. The overlay
    /// must keep winning and the id must stop being verified, so nested objects of that id take the
    /// legacy subtree comparison under typed-first.
    @Test("Swan-style override of com.atproto.repo.applyWrites#create keeps winning and is unverified")
    func swanStyleCoreOverride() throws {
        OverrideRegistration.ensureRegistered()
        let entry = try #require(ATProtocolValueContainer.decoderFactory.entry(for: "com.atproto.repo.applyWrites#create"))
        #expect(!entry.typeIdentifierVerified)
        #expect(entry.isCoreID)

        let create = #"{"$type":"com.atproto.repo.applyWrites#create","collection":"app.bsky.feed.post","rkey":"3k","value":\#(Self.post(""))}"#
        let top = try JSONDecoder().decode(ATProtocolValueContainer.self, from: Data(create.utf8))
        guard case let .knownType(value) = top else {
            Issue.record("expected the overlay type, got \(top)")
            return
        }
        #expect(value is SwanStyleApplyWritesCreate, "the overlay must win over the built-in decoder")

        let batch = #"{"$type":"example.batch","writes":[\#(create),\#(create)],"single":\#(create)}"#
        expectSameOutcome(kind: .root, json: Data(batch.utf8), name: "swan_batch")
        expectSameOutcome(kind: .root, json: Data(create.utf8), name: "swan_create")
    }

    /// An overlay that overrides a core union member and re-encodes fewer fields than the core
    /// type. Legacy demotes the parent record (the parent's typed sub-object has a field the
    /// overlay's re-encoding lacks). Comparing the parent's typed view with the JSON directly would
    /// wrongly accept it; the unverified bit forces the legacy subtree comparison instead.
    @Test("Overridden union members force the legacy subtree comparison (keyed and array positions)")
    func overriddenUnionMemberMatchesLegacy() throws {
        OverrideRegistration.ensureRegistered()
        let profile = #"{"$type":"app.bsky.actor.profile","displayName":"x","labels":{"$type":"com.atproto.label.defs#selfLabels","values":[{"val":"porn"}]}}"#
        let profileOutcome = expectSameOutcome(kind: .root, json: Data(profile.utf8), name: "override_keyed")
        #expect(profileOutcome.signatures.first?.hasPrefix("unknown<app.bsky.actor.profile>") == true)

        let threadgate = #"{"$type":"app.bsky.feed.threadgate","post":"at://did:plc:abc/app.bsky.feed.post/3k","allow":[{"$type":"app.bsky.feed.threadgate#listRule","list":"at://did:plc:abc/app.bsky.graph.list/3k"}],"createdAt":"2026-01-01T00:00:00.000Z"}"#
        let threadgateOutcome = expectSameOutcome(kind: .root, json: Data(threadgate.utf8), name: "override_array")
        #expect(threadgateOutcome.signatures.first?.hasPrefix("unknown<app.bsky.feed.threadgate>") == true)
    }

    // MARK: - Fixtures

    @Test(
        "Fixture corpus decodes identically on both paths",
        .enabled(if: Self.fixturesDirectory != nil),
        arguments: ["small-profile", "medium-search", "large-feed", "unicode-feed", "difficult-feed", "base64-records",
                    "ProbeMix/probe-booleans", "ProbeMix/probe-integers", "ProbeMix/probe-strings"]
    )
    func fixtureDifferential(_ name: String) throws {
        let directory = try #require(Self.fixturesDirectory)
        let data = try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
        let kind: ModelKind = switch name {
        case "small-profile": .profile
        case "medium-search": .search
        case let other where other.hasSuffix("-feed"): .timeline
        default: .records
        }
        let outcome = expectSameOutcome(kind: kind, json: data, name: name)
        #expect(outcome.status == "accepted", "\(name): \(outcome.detail.prefix(200))")
    }

    // MARK: - Edge cases

    @Test("Adversarial edge cases decode identically on both paths", arguments: Self.edgeCases)
    func edgeCaseDifferential(_ edge: EdgeCase) {
        for keyStrategy in [KeyStrategy.default, .snake] {
            expectSameOutcome(kind: edge.kind, json: edge.data, name: "\(edge.name) [\(keyStrategy)]", keyStrategy: keyStrategy)
        }
    }

    @Test("Records with several throwing fields reject with the same error class", arguments: Self.multiErrorCases)
    func multiErrorRecords(_ edge: EdgeCase) {
        for keyStrategy in [KeyStrategy.default, .snake] {
            let decoder = keyStrategy.makeDecoder()
            let typedFirst = Self.outcome(kind: edge.kind, data: edge.data, decoder: decoder, legacy: false)
            let legacy = Self.outcome(kind: edge.kind, data: edge.data, decoder: decoder, legacy: true)
            #expect(typedFirst.status == "rejected", "\(edge.name)")
            #expect(legacy.status == "rejected", "\(edge.name)")
            if edge.sameClass {
                #expect(typedFirst.errorClass == legacy.errorClass, "\(edge.name): \(typedFirst.errorClass) vs \(legacy.errorClass)")
            }
        }
    }

    @Test("Foundation's internal number error is neither swallowed nor remapped")
    func nonRepresentableNumbersKeepFoundationsError() {
        for json in [#"{"value":{"a":[1,1.5]}}"#, #"{"value":\#(Self.post(#","future":9223372036854775808"#))}"#] {
            let decoder = JSONDecoder()
            let typedFirst = Self.outcome(kind: .dynamic, data: Data(json.utf8), decoder: decoder, legacy: false)
            let legacy = Self.outcome(kind: .dynamic, data: Data(json.utf8), decoder: decoder, legacy: true)
            #expect(typedFirst.status == "rejected")
            #expect(typedFirst.errorClass == "DecodingError.dataCorrupted")
            #expect(typedFirst == legacy)
        }
    }

    // MARK: - Work bound on nested records

    /// Each case nests `depth` registered records (see `ChainCase`). A typed-first decode must never
    /// decode a subtree typed-first and then again in its fallback (round 1: 2^depth), and must never
    /// start a nested typed-first record under a subtree its typed decode already paid for (round 2:
    /// depth^2 under a degraded optional). Two counters measure the work on this task only, and both
    /// must stay within the stated bound of at most two legacy passes over any subtree (one in the
    /// typed decode or the walk, one in the fallback) plus the outermost record's own typed decode,
    /// whatever the depth:
    /// - typed decodes of the chain records (one per record decode): at most 2 x legacy's + 1;
    /// - passes over the bottom (a registered marker beside the innermost value, decoded once per raw
    ///   pass that reaches it): at most 2 x legacy's.
    /// Where legacy itself is exponential (an accepted typed dynamic field or an accepted unknown
    /// union member, which the legacy raw pass and the legacy typed decode both decode), typed-first
    /// must not exceed it.
    @Test("Nested records cost linear work in depth", arguments: ChainCase.all)
    func nestedRecordsCostLinearWork(_ chain: ChainCase) {
        ChainRegistration.ensureRegistered()
        let data = Data(chain.json.utf8)
        for keyStrategy in [KeyStrategy.default, .snake] {
            let decoder = keyStrategy.makeDecoder()
            let typed = ChainCounter.count {
                _ = Self.outcome(kind: .root, data: data, decoder: decoder, legacy: false)
            }
            let legacy = ChainCounter.count {
                _ = Self.outcome(kind: .root, data: data, decoder: decoder, legacy: true)
            }
            let outcome = expectSameOutcome(kind: .root, json: data, name: "\(chain.name) [\(keyStrategy)]", keyStrategy: keyStrategy)
            #expect(outcome.status == chain.expectedStatus, "\(chain.name): \(outcome.detail.prefix(200))")
            let detail = "\(chain.name) [\(keyStrategy)] at depth \(chain.depth): typed-first \(typed), legacy \(legacy)"
            if chain.legacyIsExponential {
                #expect(typed.records <= legacy.records, "\(detail)")
                #expect(typed.bottomPasses <= legacy.bottomPasses, "\(detail)")
            } else {
                #expect(typed.records <= 2 * legacy.records + 1, "\(detail)")
                #expect(typed.bottomPasses <= 2 * legacy.bottomPasses, "\(detail)")
                #expect(legacy.bottomPasses == 1, "\(detail)")
            }
        }
    }
}

// MARK: - Nested-record chains

extension ATProtocolValueContainerTypedFirstTests {
    /// A chain of `depth` registered records, innermost value `bottom`:
    /// - `rawOnly`: the next level sits in an unknown top-level field (`x`) of the record;
    /// - `nestedRawOnly`: it sits in an unknown field of a typed sub-object (`meta.x`);
    /// - `typedDynamic`: it is the record's typed `unknown` field (`value`), like
    ///   `com.atproto.repo.applyWrites#create`;
    /// - `degradedUnion`: it sits in an unknown member of the record's OPTIONAL open union (`extra`),
    ///   like `app.bsky.feed.post.embed` or `.labels`. A throwing bottom fails the member's dynamic
    ///   decode, so the typed decode degrades the optional to nil after paying the whole chain, and
    ///   the key is raw-only in the walk;
    /// - `degradedUnionArray`: the same through an optional array of structs holding a union array
    ///   (`facets[].features[]`), like `app.bsky.feed.post.facets`.
    /// A `name` with surrounding spaces demotes every level: the typed decoder trims it (as URI
    /// normalization does for real records), so the typed view no longer matches the wire.
    /// Every bottom is an array whose first element is a registered marker record (counted once per
    /// raw pass that reaches the bottom) and whose second element is the innermost value.
    struct ChainCase: Sendable, CustomTestStringConvertible {
        enum Family: String, CaseIterable, Sendable {
            case rawOnly, nestedRawOnly, typedDynamic, degradedUnion, degradedUnionArray
        }

        enum Bottom: String, CaseIterable, Sendable {
            case integer, fraction, badLink, overflow, cidV0Link

            var innermost: String {
                switch self {
                case .integer: "1"
                case .fraction: "1.5"
                case .badLink: #"{"$link":"not-a-cid"}"#
                case .overflow: "9223372036854775808"
                case .cidV0Link: #"{"$link":"QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"}"#
                }
            }

            var json: String {
                #"[{"$type":"\#(ChainBottom.typeIdentifier)"},\#(innermost)]"#
            }
        }

        let family: Family
        let bottom: Bottom
        let demoting: Bool

        var name: String {
            "\(family.rawValue)-\(bottom.rawValue)\(demoting ? "-demoting" : "")"
        }

        var testDescription: String {
            name
        }

        /// Legacy decodes a typed dynamic field, and the dynamic value of an unknown union member,
        /// twice per level when the chain is accepted.
        var legacyIsExponential: Bool {
            switch family {
            case .typedDynamic, .degradedUnion, .degradedUnionArray: bottom == .integer
            case .rawOnly, .nestedRawOnly: false
            }
        }

        var depth: Int {
            legacyIsExponential ? 10 : 16
        }

        var expectedStatus: String {
            bottom == .integer ? "accepted" : "rejected"
        }

        var json: String {
            let name = demoting ? #"" n ""# : #""n""#
            var inner = bottom.json
            for _ in 0 ..< depth {
                switch family {
                case .rawOnly:
                    inner = #"{"$type":"\#(ChainRecord.typeIdentifier)","name":\#(name),"x":\#(inner)}"#
                case .nestedRawOnly:
                    inner = #"{"$type":"\#(ChainRecord.typeIdentifier)","name":\#(name),"meta":{"label":"l","x":\#(inner)}}"#
                case .typedDynamic:
                    inner = #"{"$type":"\#(ChainEnvelope.typeIdentifier)","name":\#(name),"value":\#(inner)}"#
                case .degradedUnion:
                    inner = #"{"$type":"\#(ChainRecord.typeIdentifier)","name":\#(name),"extra":{"$type":"example.future.member","x":\#(inner)}}"#
                case .degradedUnionArray:
                    inner = #"{"$type":"\#(ChainRecord.typeIdentifier)","name":\#(name),"facets":[{"features":[{"$type":"example.future.member","x":\#(inner)}]}]}"#
                }
            }
            return inner
        }

        static let all: [ChainCase] = Family.allCases.flatMap { family in
            Bottom.allCases.flatMap { bottom in
                [false, true].map { ChainCase(family: family, bottom: bottom, demoting: $0) }
            }
        }
    }
}

// MARK: - Differential harness

extension ATProtocolValueContainerTypedFirstTests {
    enum ModelKind: Sendable {
        case root, dynamic, dynamicArray, profile, search, timeline, records
    }

    enum KeyStrategy: CustomStringConvertible {
        case `default`, snake

        func makeDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            if case .snake = self {
                decoder.keyDecodingStrategy = .convertFromSnakeCase
            }
            return decoder
        }

        var description: String {
            switch self {
            case .default: "default"
            case .snake: "snake"
            }
        }
    }

    struct Outcome: Equatable {
        var status: String
        var errorClass: String
        var detail: String
        var signatures: [String]
    }

    struct EdgeCase: Sendable, CustomTestStringConvertible {
        let name: String
        let kind: ModelKind
        let data: Data
        var sameClass = true
        var testDescription: String { name }
    }

    struct DynamicProbe: Codable { let value: ATProtocolValueContainer }
    struct DynamicArrayProbe: Codable { let value: [ATProtocolValueContainer] }

    struct StrictnessProbe: Decodable {
        let isStrict: Bool
        init(from decoder: Decoder) throws {
            isStrict = ATProtocolValueContainer.isStrictJSONDecoder(decoder)
        }
    }

    @discardableResult
    func expectSameOutcome(
        kind: ModelKind,
        json: Data,
        name: String,
        keyStrategy: KeyStrategy = .default,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Outcome {
        let decoder = keyStrategy.makeDecoder()
        let typedFirst = Self.outcome(kind: kind, data: json, decoder: decoder, legacy: false)
        let legacy = Self.outcome(kind: kind, data: json, decoder: decoder, legacy: true)
        #expect(typedFirst.status == legacy.status, "\(name): status", sourceLocation: sourceLocation)
        #expect(typedFirst.errorClass == legacy.errorClass, "\(name): error class", sourceLocation: sourceLocation)
        #expect(typedFirst.detail == legacy.detail, "\(name): detail", sourceLocation: sourceLocation)
        #expect(typedFirst.signatures == legacy.signatures, "\(name): container classification", sourceLocation: sourceLocation)
        return typedFirst
    }

    static func outcome(kind: ModelKind, data: Data, decoder: JSONDecoder, legacy: Bool) -> Outcome {
        do {
            let model: any Encodable = try legacy
                ? ATProtocolValueContainer.withLegacyDynamicDecoding { try decode(kind: kind, data: data, decoder: decoder) }
                : decode(kind: kind, data: data, decoder: decoder)
            var signatures: [String] = []
            collectSignatures(model, into: &signatures)
            return Outcome(status: "accepted", errorClass: "", detail: canonical(model), signatures: signatures)
        } catch {
            return Outcome(status: "rejected", errorClass: errorClass(error), detail: normalizedDescription(error), signatures: [])
        }
    }

    static func decode(kind: ModelKind, data: Data, decoder: JSONDecoder) throws -> any Encodable {
        switch kind {
        case .root: try decoder.decode(ATProtocolValueContainer.self, from: data)
        case .dynamic: try decoder.decode(DynamicProbe.self, from: data)
        case .dynamicArray: try decoder.decode(DynamicArrayProbe.self, from: data)
        case .profile: try decoder.decode(AppBskyActorGetProfile.Output.self, from: data)
        case .search: try decoder.decode(AppBskyActorSearchActors.Output.self, from: data)
        case .timeline: try decoder.decode(AppBskyFeedGetTimeline.Output.self, from: data)
        case .records: try decoder.decode(ComAtprotoRepoListRecords.Output.self, from: data)
        }
    }

    static func canonical(_ model: any Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return String(decoding: try encoder.encode(model), as: UTF8.self)
        } catch {
            return "<encoding failed: \(error)>"
        }
    }

    static func errorClass(_ error: any Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return String(reflecting: type(of: error))
        }
        switch decodingError {
        case .typeMismatch: return "DecodingError.typeMismatch"
        case .valueNotFound: return "DecodingError.valueNotFound"
        case .keyNotFound: return "DecodingError.keyNotFound"
        case .dataCorrupted: return "DecodingError.dataCorrupted"
        @unknown default: return "DecodingError.unknown"
        }
    }

    /// NSError `UserInfo` prints in hash order; sort it so only semantic differences remain.
    static func normalizedDescription(_ error: any Error) -> String {
        var detail = String(describing: error)
        if let range = detail.range(of: "UserInfo={") {
            let tail = detail[range.upperBound...].dropLast()
            let parts = tail.split(separator: ", ").sorted()
            detail = String(detail[..<range.upperBound]) + parts.joined(separator: ", ") + "}"
        }
        return detail
    }

    static func collectSignatures(_ value: Any, into signatures: inout [String], depth: Int = 0) {
        guard depth <= 64 else { return }
        if let container = value as? ATProtocolValueContainer {
            signatures.append(signature(container))
            return
        }
        for child in Mirror(reflecting: value).children {
            collectSignatures(child.value, into: &signatures, depth: depth + 1)
        }
    }

    /// Case structure of a dynamic container: known type and its canonical body, unknown type id.
    static func signature(_ value: ATProtocolValueContainer) -> String {
        switch value {
        case let .knownType(inner):
            "known<\(String(reflecting: type(of: inner)))>\(canonical(inner))"
        case let .unknownType(type, inner):
            "unknown<\(type)>(\(signature(inner)))"
        case let .object(dict):
            "{" + dict.keys.sorted().map { "\($0):\(signature(dict[$0]!))" }.joined(separator: ",") + "}"
        case let .array(items):
            "[" + items.map(signature).joined(separator: ",") + "]"
        case let .string(string): "s\(string.debugDescription)"
        case let .number(number): "n\(number)"
        case let .bigNumber(string): "N\(string)"
        case let .bool(bool): "b\(bool)"
        case .null: "null"
        case let .link(link): "link(\(link.cid.string))"
        case let .bytes(bytes): "bytes(\(bytes.data.base64EncodedString()))"
        case let .decodeError(message): "decodeError(\(message))"
        }
    }

    func signature(_ value: ATProtocolValueContainer) -> String {
        Self.signature(value)
    }

    static let fixturesDirectory: URL? = {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Benchmarks/JSON/Fixtures")
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("large-feed.json").path) ? directory : nil
    }()
}

// MARK: - Edge-case corpus

extension ATProtocolValueContainerTypedFirstTests {
    static let date = "2026-01-01T00:00:00.000Z"
    static let cid = "bafkreifqkz7gikummmwlitlxwfqnverjhacyeu4i3dytnmhn5bmuowkzoy"
    static let strongRefCID = "bafyreibe7vchdsgdlh7w3zjd5bhn566yranqwfojxbkck2yjcypzmcg7dq"

    static func post(_ extra: String) -> String {
        #"{"$type":"app.bsky.feed.post","text":"hello","createdAt":"\#(date)"\#(extra)}"#
    }

    static func edge(_ name: String, _ kind: ModelKind, _ json: String) -> EdgeCase {
        EdgeCase(name: name, kind: kind, data: Data(json.utf8))
    }

    static let edgeCases: [EdgeCase] = {
        let image = #"{"$type":"blob","ref":{"$link":"\#(cid)"},"mimeType":"image/png","size":1}"#
        var cases: [EdgeCase] = [
            // Known records, future fields, degraded optionals.
            edge("known_minimal", .root, post("")),
            edge("extra_field_bool", .root, post(#","future":true"#)),
            edge("extra_field_float_throws", .root, post(#","future":1.5"#)),
            edge("extra_field_overflow_throws", .root, post(#","future":9223372036854775808"#)),
            edge("extra_field_negative_overflow_throws", .root, post(#","future":-9223372036854775809"#)),
            edge("extra_field_exponent_huge_throws", .root, post(#","future":{"deep":[1,2,{"x":1e400}]}"#)),
            edge("extra_field_integral_exponent", .root, post(#","future":[1e2,2.0,-0]"#)),
            edge("extra_field_bad_link_throws", .root, post(#","future":{"$link":"not-a-cid"}"#)),
            edge("extra_field_link_number_throws", .root, post(#","future":{"$link":5}"#)),
            edge("extra_field_link_null", .root, post(#","future":{"$link":null}"#)),
            edge("extra_field_bad_bytes_throws", .root, post(#","future":{"$bytes":"Zh=="}"#)),
            edge("extra_field_bytes_number_throws", .root, post(#","future":{"$bytes":5}"#)),
            edge("extra_field_uppercase_link", .root, post(#","future":{"$link":"\#(cid.uppercased())"}"#)),
            edge("extra_field_nested_known", .root, post(#","future":{"$type":"app.bsky.richtext.facet#tag","tag":"x"}"#)),
            edge("extra_field_nested_unknown_wrapping_known", .root, post(#","future":{"$type":"example.unknown.nested","x":{"$type":"app.bsky.richtext.facet#tag","tag":"t"}}"#)),
            edge("extra_field_links_array", .root, post(#","future":[{"$link":"\#(cid)"},{"$link":"\#(cid)"},{"$link":"\#(cid)"}]"#)),
            edge("extra_field_array_hint_swallow", .root, post(#","future":[[1],[2],[{"$link":5}]]"#)),
            edge("extra_field_object_hint_throw", .root, post(#","future":[{"a":1},{"a":2},{"$link":5}]"#)),
            edge("extra_field_mixed_array", .root, post(#","future":["s",0,{"a":1},[2],true,null,"t","u","v",1,2,3]"#)),
            edge("optional_degraded_rawok", .root, post(#","langs":3"#)),
            edge("optional_degraded_string", .root, post(#","langs":"en""#)),
            edge("optional_degraded_rawthrows", .root, post(#","langs":1.5"#)),
            edge("optional_degraded_rawthrows_nested", .root, post(#","embed":{"$type":"app.bsky.embed.images","images":[{"alt":"a","image":{"$type":"blob","ref":{"$link":"not-a-cid"},"mimeType":"image/png","size":1}}]}"#)),
            edge("embed_unknown_member", .root, post(#","embed":{"$type":"example.future.embed","x":1}"#)),
            edge("embed_registered_foreign_member", .root, post(#","embed":{"$type":"app.bsky.richtext.facet#tag","tag":"x"}"#)),
            edge("reply_missing_parent", .root, post(#","reply":{"root":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
            edge("lang_region", .root, post(#","langs":["zh-Hans-CN","en-US"]"#)),
            edge("long_fraction_date", .root, #"{"$type":"app.bsky.feed.post","text":"t","createdAt":"2026-07-20T14:13:03.720942844Z"}"#),
            // Fidelity demotions (the typed decoder normalizes the wire value).
            edge("facet_link_trim", .root, post(#","facets":[{"index":{"byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#link","uri":" https://example.com "}]}]"#)),
            edge("label_uri_trim", .root, #"{"$type":"com.atproto.label.defs#label","src":"did:plc:example1234567890abcdef","uri":" https://example.com/item ","val":"test-label","cts":"\#(date)"}"#),
            edge("embed_external_uri_trim", .root, post(#","embed":{"$type":"app.bsky.embed.external","external":{"uri":" https://example.com ","title":"t","description":"d"}}"#)),
            // Nested $type framing.
            edge("facet_unknown_feature", .root, post(#","facets":[{"index":{"byteStart":0,"byteEnd":5},"features":[{"$type":"example.future.facet","value":true}]}]"#)),
            edge("facet_index_framed", .root, post(#","facets":[{"index":{"$type":"app.bsky.richtext.facet#byteSlice","byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}]}]"#)),
            edge("facet_index_wrong_type", .root, post(#","facets":[{"index":{"$type":"app.bsky.richtext.facet#tag","tag":"x","byteStart":0,"byteEnd":5},"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}]}]"#)),
            edge("facet_feature_type_not_string", .root, post(#","facets":[{"index":{"byteStart":0,"byteEnd":5},"features":[{"$type":5,"tag":"x"}]}]"#)),
            edge("strongref_with_foreign_type", .root, post(#","reply":{"root":{"$type":"app.bsky.richtext.facet#tag","tag":"t","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"},"parent":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
            edge("strongref_with_own_type", .root, post(#","reply":{"root":{"$type":"com.atproto.repo.strongRef","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"},"parent":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
            edge("strongref_type_null", .root, post(#","reply":{"root":{"$type":null,"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"},"parent":{"uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}}"#)),
            edge("int_as_float_in_known", .root, post(#","facets":[{"index":{"byteStart":1.0,"byteEnd":1e1},"features":[{"$type":"app.bsky.richtext.facet#tag","tag":"x"}]}]"#)),
            edge("blob_large_integral_size", .root, post(#","embed":{"$type":"app.bsky.embed.images","images":[{"alt":"a","image":{"$type":"blob","ref":{"$link":"\#(cid)"},"mimeType":"image/png","size":9007199254740993.0}}]}"#)),
            edge("explicit_nulls", .root, post(#","embed":{"$type":"app.bsky.embed.images","captions":[],"external":null,"images":[{"alt":"a","aspectRatio":{"height":1,"width":2},"image":\#(image)}],"record":null},"facets":[{"features":[{"$type":"app.bsky.richtext.facet#mention","did":"did:plc:mrvatd2g4xdzxlcdam3ljnxc","tag":null,"uri":null}],"index":{"byteEnd":4,"byteStart":0}}]"#)),
            edge("explicit_null_required", .root, #"{"$type":"app.bsky.feed.post","text":null,"createdAt":"\#(date)"}"#),
            edge("special_lookalike_in_known", .root, post(#","future":{"$link":"x","extra":1}"#)),
            edge("bytes_lookalike_in_known", .root, post(#","future":{"$bytes":"AAH/","x":1}"#)),
            // $type problems at the top level.
            edge("type_not_string", .root, #"{"$type":5,"text":"x","createdAt":"\#(date)"}"#),
            edge("type_null", .root, #"{"$type":null,"text":"x","createdAt":"\#(date)"}"#),
            edge("duplicate_text", .root, #"{"$type":"app.bsky.feed.post","text":"a","text":"b","createdAt":"\#(date)"}"#),
            edge("text_wrong_type", .root, #"{"$type":"app.bsky.feed.post","text":42,"createdAt":"\#(date)"}"#),
            edge("missing_required", .root, #"{"$type":"app.bsky.feed.post","text":"x"}"#),
            edge("snake_keys", .root, #"{"$type":"app.bsky.feed.post","text":"x","created_at":"\#(date)","future_field":1}"#),
            // Unknown records carrying known ones.
            edge("unknown_wrapping_known", .root, #"{"$type":"example.unknown","inner":\#(post("")),"list":[\#(post("")),null,1,"s"]}"#),
            edge("unknown_wrapping_embed", .root, #"{"$type":"example.unknown","embed":{"$type":"app.bsky.embed.images","images":[{"alt":"a","image":\#(image)}]}}"#),
            edge("untyped_wrapping_known", .root, #"{"a":\#(post("")),"b":[\#(post("")),\#(post("")),\#(post(#","future":1.5"#))]}"#),
            edge("array_of_records", .dynamicArray, #"{"value":[\#(post("")),\#(post(#","langs":["en"]"#)),null]}"#),
            edge("bytes_in_unknown", .root, #"{"$type":"example.unknown","b":{"$bytes":"AAH/"},"l":{"$link":"\#(cid)"}}"#),
            edge("strongref_root", .root, #"{"$type":"com.atproto.repo.strongRef","uri":"at://did:plc:abc/app.bsky.feed.post/1","cid":"\#(strongRefCID)"}"#),
            edge("preferences_array_type", .root, #"{"$type":"app.bsky.actor.defs#preferences","items":[]}"#),
            // Shapes.
            edge("empty_object", .root, "{}"),
            edge("top_level_primitives", .dynamicArray, #"{"value":[null,true,false,"text",-9223372036854775808,9223372036854775807,[],{},[null,{"present":null}]]}"#),
            edge("top_level_string", .root, #""text""#),
            edge("top_level_array", .root, #"[1,"a",{"$type":"app.bsky.richtext.facet#tag","tag":"x"},[true]]"#),
            edge("dyn_fraction_throws", .dynamic, #"{"value":{"a":[1,1.5]}}"#),
            edge("dyn_number_string_mix", .dynamic, #"{"value":{"a":"1","b":1,"c":"true","d":true,"e":"null"}}"#),
            edge("dyn_predicted_kinds_change", .dynamic, #"{"value":["a","b","c",1,2,3,true,false,true,[1],[2],[3],{"x":1},{"y":2},{"z":3},"d"]}"#),
            edge("deep_64", .dynamic, "{\"value\":" + String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64) + "}"),
            edge("deep_600", .dynamic, "{\"value\":" + String(repeating: "[", count: 600) + "0" + String(repeating: "]", count: 600) + "}"),
        ]
        // {"$type":"app.bsky.feed.post","text":"x","createdAt":"…","future":"\xC0\xAF"}
        var invalidUTF8 = Array(#"{"$type":"app.bsky.feed.post","text":"x","createdAt":"\#(date)","future":""#.utf8)
        invalidUTF8 += [0xC0, 0xAF]
        invalidUTF8 += Array(#""}"#.utf8)
        cases.append(EdgeCase(name: "invalid_utf8_in_extra", kind: .root, data: Data(invalidUTF8)))
        var invalidUTF8Typed = Array(#"{"$type":"app.bsky.feed.post","text":""#.utf8)
        invalidUTF8Typed += [0xC0, 0xAF]
        invalidUTF8Typed += Array(#"","createdAt":"\#(date)"}"#.utf8)
        cases.append(EdgeCase(name: "invalid_utf8_in_typed_field", kind: .root, data: Data(invalidUTF8Typed)))
        return cases
    }()

    static let multiErrorCases: [EdgeCase] = [
        edge("two_floats", .root, post(#","futureA":1.5,"futureB":2.5,"futureC":{"x":3.5}"#)),
        edge("two_bad_links", .root, post(#","futureA":{"$link":"not-a-cid"},"futureB":{"$link":"also-bad"}"#)),
        edge("two_overflows_in_degraded_and_unknown", .root, post(#","langs":9223372036854775808,"future":18446744073709551616"#)),
        EdgeCase(name: "float_and_bad_link", kind: .root, data: Data(post(#","futureA":1.5,"futureB":{"$link":"not-a-cid"}"#).utf8), sameClass: false),
    ]
}

// MARK: - Test-only registry types

/// Registers the probe types once per process. Registration is process-global; the ids are unique
/// to this file.
private enum TypedFirstProbeRegistration {
    static let registered: Bool = {
        ATProtocolValueContainer.registerDecoder(forType: TypedFirstProbeRecord.typeIdentifier, as: TypedFirstProbeRecord.self)
        ATProtocolValueContainer.registerDecoder(forType: TypedFirstProbeChild.typeIdentifier, as: TypedFirstProbeChild.self)
        return true
    }()

    static func ensureRegistered() {
        _ = registered
    }
}

/// Overlay registrations that override core ids. No other test in this target and no harness
/// fixture uses `com.atproto.label.defs#selfLabels`, `app.bsky.feed.threadgate#listRule` or
/// `com.atproto.repo.applyWrites#create`, so overriding them process-wide is safe.
private enum OverrideRegistration {
    static let registered: Bool = {
        ATProtocolValueContainer.registerDecoder(forType: "com.atproto.repo.applyWrites#create", as: SwanStyleApplyWritesCreate.self)
        ATProtocolValueContainer.registerDecoder(forType: "com.atproto.label.defs#selfLabels", as: LossyOverlayValue<SelfLabelsID>.self)
        ATProtocolValueContainer.registerDecoder(forType: "app.bsky.feed.threadgate#listRule", as: LossyOverlayValue<ListRuleID>.self)
        return true
    }()

    static func ensureRegistered() {
        _ = registered
    }
}

private struct TypedFirstProbeChild: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst#child"
    static let initCount = Atomic<Int>(0)

    let name: String

    init(from decoder: Decoder) throws {
        Self.initCount.add(1, ordering: .relaxed)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
        try container.encode(name, forKey: .name)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        map.append(key: "name", value: name)
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        (other as? Self) == self
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case name
    }
}

private struct TypedFirstProbeRecord: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst#record"

    let child: TypedFirstProbeChild
    let note: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        child = try container.decode(TypedFirstProbeChild.self, forKey: .child)
        note = try container.decode(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
        try container.encode(child, forKey: .child)
        try container.encode(note, forKey: .note)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        map.append(key: "note", value: note)
        map.append(key: "child", value: try child.toCBORValue())
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        (other as? Self) == self
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case child
        case note
    }
}

/// Swan-style overlay: a separately generated type for a core id, registered with the typed overload.
private struct SwanStyleApplyWritesCreate: ATProtocolValue {
    static let typeIdentifier = "com.atproto.repo.applyWrites#create"

    let collection: String
    let rkey: String?
    let value: ATProtocolValueContainer

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collection = try container.decode(String.self, forKey: .collection)
        rkey = try container.decodeIfPresent(String.self, forKey: .rkey)
        value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
        try container.encode(collection, forKey: .collection)
        try container.encodeIfPresent(rkey, forKey: .rkey)
        try container.encode(value, forKey: .value)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        map.append(key: "collection", value: collection)
        if let rkey {
            map.append(key: "rkey", value: rkey)
        }
        map.append(key: "value", value: try value.toCBORValue())
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        (other as? Self) == self
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case collection
        case rkey
        case value
    }
}

private protocol OverlayID {
    static var id: String { get }
}

private enum SelfLabelsID: OverlayID { static var id: String { "com.atproto.label.defs#selfLabels" } }
private enum ListRuleID: OverlayID { static var id: String { "app.bsky.feed.threadgate#listRule" } }

/// An overlay that accepts any object for a core id but re-encodes it as an empty map: its own
/// fidelity check passes (no typed keys), while a parent's typed view of the same object has
/// fields the overlay's re-encoding lacks.
private struct LossyOverlayValue<ID: OverlayID>: ATProtocolValue {
    static var typeIdentifier: String { ID.id }

    init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: CodingKeys.self)
    }

    func encode(to encoder: Encoder) throws {
        _ = encoder.container(keyedBy: CodingKeys.self)
    }

    func toCBORValue() throws -> Any {
        OrderedCBORMap()
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        other is Self
    }

    private enum CodingKeys: CodingKey {}
}

private struct ClaimProbeA: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.claims#a"
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {}
    func toCBORValue() throws -> Any { OrderedCBORMap() }
    func isEqual(to other: any ATProtocolValue) -> Bool { other is Self }
}

private struct ClaimProbeAPrime: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.claims#a"
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {}
    func toCBORValue() throws -> Any { OrderedCBORMap() }
    func isEqual(to other: any ATProtocolValue) -> Bool { other is Self }
}

private struct ClaimProbeB: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.claims#b"
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {}
    func toCBORValue() throws -> Any { OrderedCBORMap() }
    func isEqual(to other: any ATProtocolValue) -> Bool { other is Self }
}

// MARK: - Chain types (work-bound tests)

private enum ChainRegistration {
    static let registered: Bool = {
        ATProtocolValueContainer.registerDecoder(forType: ChainRecord.typeIdentifier, as: ChainRecord.self)
        ATProtocolValueContainer.registerDecoder(forType: ChainEnvelope.typeIdentifier, as: ChainEnvelope.self)
        ATProtocolValueContainer.registerDecoder(forType: ChainBottom.typeIdentifier, as: ChainBottom.self)
        return true
    }()

    static func ensureRegistered() {
        _ = registered
    }
}

/// Counts typed decodes of the chain types and passes over the chain bottom made on the current
/// task, so parallel test cases do not see each other's decodes.
private enum ChainCounter {
    struct Counts: CustomStringConvertible {
        /// Typed decodes of `ChainRecord` and `ChainEnvelope` (one per record decode).
        let records: Int
        /// Typed decodes of the `ChainBottom` marker: one per raw pass over the bottom (the marker is
        /// accepted, so the legacy object path decodes it once per pass, and nothing else does).
        let bottomPasses: Int

        var description: String {
            "\(records) record decodes, \(bottomPasses) bottom passes"
        }
    }

    final class Box: Sendable {
        let records = Atomic<Int>(0)
        let bottomPasses = Atomic<Int>(0)
    }

    @TaskLocal static var current: Box?

    static func count(_ body: () -> Void) -> Counts {
        let box = Box()
        $current.withValue(box) {
            body()
        }
        return Counts(
            records: box.records.load(ordering: .relaxed),
            bottomPasses: box.bottomPasses.load(ordering: .relaxed)
        )
    }

    static func record() {
        current?.records.add(1, ordering: .relaxed)
    }

    static func bottomPass() {
        current?.bottomPasses.add(1, ordering: .relaxed)
    }
}

private struct ChainMeta: Codable, Hashable, Sendable {
    let label: String

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "label", value: label)
        return map
    }
}

/// An open union with no known member, mirroring a generated union's `.unexpected` case: an
/// unknown `$type` decodes the whole object as a dynamic value.
private enum ChainUnion: Codable, Hashable, Sendable {
    case unexpected(ATProtocolValueContainer)

    init(from decoder: Decoder) throws {
        self = .unexpected(try ATProtocolValueContainer(from: decoder))
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .unexpected(container):
            try container.encode(to: encoder)
        }
    }

    func toCBORValue() throws -> Any {
        switch self {
        case let .unexpected(container):
            try container.toCBORValue()
        }
    }
}

/// A struct holding a union array, mirroring `app.bsky.richtext.facet` (`features`).
private struct ChainFacet: Codable, Hashable, Sendable {
    let features: [ChainUnion]

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "features", value: try features.map { try $0.toCBORValue() })
        return map
    }
}

/// A record whose typed decode ignores unknown fields, trims `name`, and degrades its optional
/// union fields to nil when they fail to decode, as generated records do.
private struct ChainRecord: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.chain#record"

    let name: String
    let meta: ChainMeta?
    let extra: ChainUnion?
    let facets: [ChainFacet]?

    init(from decoder: Decoder) throws {
        ChainCounter.record()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespaces)
        meta = try container.decodeIfPresent(ChainMeta.self, forKey: .meta)
        do {
            extra = try container.decodeIfPresent(ChainUnion.self, forKey: .extra)
        } catch {
            // Forward compatibility, as in generated records: a malformed optional degrades to nil.
            extra = nil
        }
        do {
            facets = try container.decodeIfPresent([ChainFacet].self, forKey: .facets)
        } catch {
            facets = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(meta, forKey: .meta)
        try container.encodeIfPresent(extra, forKey: .extra)
        try container.encodeIfPresent(facets, forKey: .facets)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        map.append(key: "name", value: name)
        if let meta {
            map.append(key: "meta", value: try meta.toCBORValue())
        }
        if let extra {
            map.append(key: "extra", value: try extra.toCBORValue())
        }
        if let facets {
            map.append(key: "facets", value: try facets.map { try $0.toCBORValue() })
        }
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        (other as? Self) == self
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case name
        case meta
        case extra
        case facets
    }
}

/// The marker beside every chain bottom. Its typed decode counts one pass over the bottom.
private struct ChainBottom: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.chain#bottom"

    init(from decoder: Decoder) throws {
        ChainCounter.bottomPass()
        _ = try decoder.container(keyedBy: CodingKeys.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        other is Self
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
}

/// A record with a typed dynamic (`unknown`) field, like `com.atproto.repo.applyWrites#create`.
private struct ChainEnvelope: ATProtocolValue {
    static let typeIdentifier = "test.petrel.typedFirst.chain#envelope"

    let name: String
    let value: ATProtocolValueContainer

    init(from decoder: Decoder) throws {
        ChainCounter.record()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespaces)
        value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "$type", value: Self.typeIdentifier)
        map.append(key: "name", value: name)
        map.append(key: "value", value: try value.toCBORValue())
        return map
    }

    func isEqual(to other: any ATProtocolValue) -> Bool {
        (other as? Self) == self
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case name
        case value
    }
}
