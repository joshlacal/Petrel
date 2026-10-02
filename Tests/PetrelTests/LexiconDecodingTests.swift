import Foundation
@testable import Petrel
import Testing

/// Covers the generated-decode helpers in `Core/Types/LexiconDecoding.swift`: the shared
/// `LexiconCodingKey` that lets unions hand their keyed container to object variants, the
/// primitive-array decoders, the 24-byte `DynamicCodingKeys`, and the out-of-line logging
/// helpers. Every assertion compares against the behavior of the code these replace.
@Suite("Generated Lexicon decoding helpers")
struct LexiconDecodingTests {
    /// The per-type `CodingKeys` enums that generated decode bodies used before
    /// `LexiconCodingKey`. The type name must be exactly `CodingKeys` because the
    /// synthesized description prints it.
    private enum Reference {
        enum CodingKeys: String, CodingKey {
            case text
            case `default`
            case type = "$type"
            case unicode = "clé\"\\"
        }
    }

    // MARK: LexiconCodingKey

    @Test("LexiconCodingKey prints exactly like the generated CodingKeys enums it replaces")
    func lexiconCodingKeyDescriptionMatchesSynthesizedCodingKeys() {
        let references: [Reference.CodingKeys] = [.text, .default, .type, .unicode]
        for reference in references {
            let key = LexiconCodingKey(stringValue: reference.stringValue)
            #expect(key.stringValue == reference.stringValue)
            #expect(key.intValue == nil)
            #expect(key.description == reference.description)
            #expect(key.debugDescription == reference.debugDescription)
            #expect(String(describing: key) == String(describing: reference))
            #expect(String(reflecting: key) == String(reflecting: reference))
            #expect("\([key as CodingKey])" == "\([reference as CodingKey])")
        }
        let literal: LexiconCodingKey = "$type"
        #expect(literal.stringValue == "$type")
        #expect(LexiconCodingKey(intValue: 0) == nil)
        // Fits the 3-word inline buffer of `any CodingKey`, so coding-path nodes never box it.
        #expect(MemoryLayout<LexiconCodingKey>.size <= 24)
    }

    @Test("DynamicCodingKeys is 24 bytes and keeps its string and integer key semantics")
    func dynamicCodingKeysLayoutAndSemantics() throws {
        typealias Key = ATProtocolValueContainer.DynamicCodingKeys
        #expect(MemoryLayout<Key>.size <= 24)

        let stringKey = try #require(Key(stringValue: "text"))
        #expect(stringKey.stringValue == "text")
        #expect(stringKey.intValue == nil)
        #expect(stringKey.description == #"DynamicCodingKeys(stringValue: "text", intValue: nil)"#)

        let numericString = try #require(Key(stringValue: "7"))
        #expect(numericString.intValue == nil)

        for value in [0, 5, -3, Int.max, Int.min + 1] {
            let intKey = try #require(Key(intValue: value))
            #expect(intKey.intValue == value)
            #expect(intKey.stringValue == String(value))
            #expect(intKey.description == "DynamicCodingKeys(stringValue: \"\(value)\", intValue: \(value))")
        }
        // The one unrepresentable input (the "no int" sentinel) is refused rather than
        // misreported as a string key.
        #expect(Key(intValue: Int.min) == nil)
    }

    // MARK: Union container sharing

    private static let unionCases: [String] = [
        #"{"$type":"app.bsky.embed.images#view","images":[{"thumb":"https://cdn.example/t.jpg","fullsize":"https://cdn.example/f.jpg","alt":"a"}]}"#,
        #"{"$type":"app.bsky.embed.images#view"}"#,
        #"{"$type":"app.bsky.embed.images#view","images":"x"}"#,
        #"{"$type":"app.bsky.embed.images#view","images":[{"thumb":3,"fullsize":"https://x/y","alt":""}]}"#,
        #"{"$type":"app.bsky.embed.images#view","images":[{"thumb":"https://x/y","alt":""}]}"#,
        #"{"$type":"app.bsky.embed.images#view","$type":"app.bsky.embed.external#view","images":[]}"#,
        #"{"$type":"app.bsky.embed.images#view","images":[],"future":[1.5,{"x":null}]}"#,
    ]

    /// Before this change a union decoded an object variant with `Variant(from: decoder)` at
    /// the same position, so its outcome was exactly the variant's own outcome. The shared
    /// container must preserve that: same value, same error text and coding path.
    @Test("Union decoding through the shared container matches decoding the variant directly")
    func unionVariantOutcomesMatchDirectVariantDecoding() {
        for json in Self.unionCases {
            let data = Data(json.utf8)
            let union = Result { try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: data) }
            let direct = Result { try JSONDecoder().decode(AppBskyEmbedImages.View.self, from: data) }
            switch (union, direct) {
            case let (.success(.appBskyEmbedImagesView(value)), .success(expected)):
                #expect(value == expected, "\(json)")
            case let (.failure(unionError), .failure(directError)):
                expectSameError(json, directError, unionError)
            default:
                Issue.record("Outcome kind differs for \(json): union=\(union) direct=\(direct)")
            }
        }
    }

    @Test("Union $type errors keep the CodingKeys-style key text")
    func unionTypeKeyErrors() {
        let missing = Result { try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: Data(#"{"images":[]}"#.utf8)) }
        guard case let .failure(DecodingError.keyNotFound(key, context)) = missing else {
            Issue.record("Expected keyNotFound for a union without $type, got \(missing)")
            return
        }
        #expect(key.stringValue == "$type")
        #expect(key.description == #"CodingKeys(stringValue: "$type", intValue: nil)"#)
        #expect(context.debugDescription == #"No value associated with key CodingKeys(stringValue: "$type", intValue: nil) ("$type")."#)

        let wrongType = Result { try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: Data(#"{"$type":5}"#.utf8)) }
        guard case let .failure(DecodingError.typeMismatch(_, mismatch)) = wrongType else {
            Issue.record("Expected typeMismatch for a non-string $type, got \(wrongType)")
            return
        }
        #expect(mismatch.codingPath.map(\.description) == [#"CodingKeys(stringValue: "$type", intValue: nil)"#])
    }

    @Test("Unknown $type still falls back to .unexpected with the full raw object")
    func unknownUnionVariantFallsBack() throws {
        let json = #"{"$type":"example.future#view","x":[1,true,null]}"#
        let value = try JSONDecoder().decode(AppBskyFeedDefs.PostViewEmbedUnion.self, from: Data(json.utf8))
        guard case let .unexpected(container) = value else {
            Issue.record("Expected .unexpected, got \(value)")
            return
        }
        let raw = try JSONDecoder().decode(ATProtocolValueContainer.self, from: Data(json.utf8))
        #expect(container == raw)
    }

    @Test("Union decoding through the in-memory container decoder matches the direct variant")
    func inMemoryUnionDecoding() {
        let image: ATProtocolValueContainer = .object([
            "thumb": .string("https://cdn.example/t.jpg"),
            "fullsize": .string("https://cdn.example/f.jpg"),
            "alt": .string("a"),
        ])
        let values: [ATProtocolValueContainer] = [
            .object(["$type": .string("app.bsky.embed.images#view"), "images": .array([image])]),
            .object(["$type": .string("app.bsky.embed.images#view")]),
            .object(["$type": .string("app.bsky.embed.images#view"), "images": .string("x")]),
        ]
        for value in values {
            let union = Result { try AppBskyFeedDefs.PostViewEmbedUnion(from: ATProtocolValueContainerDecoder(value: value)) }
            let direct = Result { try AppBskyEmbedImages.View(from: ATProtocolValueContainerDecoder(value: value)) }
            switch (union, direct) {
            case let (.success(.appBskyEmbedImagesView(decoded)), .success(expected)):
                #expect(decoded == expected)
            case let (.failure(unionError), .failure(directError)):
                expectSameError("\(value)", directError, unionError)
            default:
                Issue.record("Outcome kind differs: union=\(union) direct=\(direct)")
            }
        }
    }

    // MARK: Primitive arrays

    private struct StdlibStrings: Decodable {
        let values: [String]?
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            values = try container.decode([String].self, forKey: .values)
        }
    }

    private struct FastStrings: Decodable {
        let values: [String]?
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            values = try container.decode(_LexiconStringArray.self, forKey: .values).values
        }
    }

    private struct StdlibOptionalStrings: Decodable {
        let values: [String]?
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            values = try container.decodeIfPresent([String].self, forKey: .values)
        }
    }

    private struct FastOptionalStrings: Decodable {
        let values: [String]?
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            values = try container.decodeIfPresent(_LexiconStringArray.self, forKey: .values)?.values
        }
    }

    private struct StdlibInts: Decodable {
        let values: [Int]
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            values = try decoder.container(keyedBy: CodingKeys.self).decode([Int].self, forKey: .values)
        }
    }

    private struct FastInts: Decodable {
        let values: [Int]
        enum CodingKeys: String, CodingKey { case values }
        init(from decoder: Decoder) throws {
            values = try decoder.container(keyedBy: CodingKeys.self).decode(_LexiconIntArray.self, forKey: .values).values
        }
    }

    private static let arrayInputs: [String] = [
        #"{"values":[]}"#,
        #"{"values":["a","bb","é🦋","é","a\u0000b"]}"#,
        #"{"values":["a",1]}"#,
        #"{"values":["a",null]}"#,
        #"{"values":[true]}"#,
        #"{"values":[{}]}"#,
        #"{"values":[["a"]]}"#,
        #"{"values":"a"}"#,
        #"{"values":null}"#,
        #"{}"#,
        #"{"values":{"a":"b"}}"#,
        #"{"values":["\uD800"]}"#,
        #"{"values":[1,2,3e0,-0]}"#,
        #"{"values":[1,2.5]}"#,
        #"{"values":[18446744073709551615]}"#,
        #"{"values":[9223372036854775807,-9223372036854775808]}"#,
        #"{"values":["1"]}"#,
        #"{"values":[1,]}"#,
        #"[1]"#,
    ]

    @Test("String/Int array fast path matches Array.init(from:) through JSONDecoder")
    func primitiveArraysMatchStdlibThroughJSONDecoder() {
        for json in Self.arrayInputs {
            let data = Data(json.utf8)
            expectSameOutcome(
                json,
                Result { try JSONDecoder().decode(StdlibStrings.self, from: data).values },
                Result { try JSONDecoder().decode(FastStrings.self, from: data).values }
            )
            expectSameOutcome(
                json,
                Result { try JSONDecoder().decode(StdlibOptionalStrings.self, from: data).values },
                Result { try JSONDecoder().decode(FastOptionalStrings.self, from: data).values }
            )
            expectSameOutcome(
                json,
                Result { try JSONDecoder().decode(StdlibInts.self, from: data).values },
                Result { try JSONDecoder().decode(FastInts.self, from: data).values }
            )
        }
    }

    @Test("String/Int array fast path matches Array.init(from:) through the in-memory decoder")
    func primitiveArraysMatchStdlibThroughInMemoryDecoder() {
        let inputs: [ATProtocolValueContainer] = [
            .object(["values": .array([])]),
            .object(["values": .array([.string("a"), .string("b")])]),
            .object(["values": .array([.string("a"), .number(1)])]),
            .object(["values": .array([.null])]),
            .object(["values": .array([.bool(true)])]),
            .object(["values": .array([.object([:])])]),
            .object(["values": .string("a")]),
            .object(["values": .null]),
            .object([:]),
            .object(["values": .array([.number(1), .number(-2)])]),
        ]
        for value in inputs {
            let label = "\(value)"
            expectSameOutcome(
                label,
                Result { try StdlibStrings(from: ATProtocolValueContainerDecoder(value: value)).values },
                Result { try FastStrings(from: ATProtocolValueContainerDecoder(value: value)).values }
            )
            expectSameOutcome(
                label,
                Result { try StdlibOptionalStrings(from: ATProtocolValueContainerDecoder(value: value)).values },
                Result { try FastOptionalStrings(from: ATProtocolValueContainerDecoder(value: value)).values }
            )
            expectSameOutcome(
                label,
                Result { try StdlibInts(from: ATProtocolValueContainerDecoder(value: value)).values },
                Result { try FastInts(from: ATProtocolValueContainerDecoder(value: value)).values }
            )
        }
    }

    @Test("Generated [String] properties keep their decode outcomes")
    func generatedStringArrayProperties() throws {
        let ok = try JSONDecoder().decode(
            ComAtprotoServerDescribeServer.Output.self,
            from: Data(#"{"did":"did:web:example.com","availableUserDomains":["a","b"]}"#.utf8)
        )
        #expect(ok.availableUserDomains == ["a", "b"])

        let bad = Result {
            try JSONDecoder().decode(
                ComAtprotoServerDescribeServer.Output.self,
                from: Data(#"{"did":"did:web:example.com","availableUserDomains":["a",1]}"#.utf8)
            )
        }
        guard case let .failure(DecodingError.typeMismatch(type, context)) = bad else {
            Issue.record("Expected typeMismatch, got \(bad)")
            return
        }
        #expect(ObjectIdentifier(type) == ObjectIdentifier(String.self))
        #expect(context.codingPath.map(\.stringValue) == ["availableUserDomains", "Index 1"])

        // Optional record field: a malformed array still degrades to nil.
        let post = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"x","createdAt":"2026-01-01T00:00:00.000Z","tags":["a",1]}"#.utf8)
        )
        #expect(post.tags == nil)
        let tagged = try JSONDecoder().decode(
            AppBskyFeedPost.self,
            from: Data(#"{"$type":"app.bsky.feed.post","text":"x","createdAt":"2026-01-01T00:00:00.000Z","tags":["a","b"]}"#.utf8)
        )
        #expect(tagged.tags == ["a", "b"])
    }

    // MARK: Diagnostics

    private struct SampleError: Error, CustomStringConvertible {
        var description: String {
            "sample \"failure\" — é"
        }
    }

    @Test("Out-of-line diagnostics produce the exact text of the former inline log calls")
    func diagnosticsMessagesMatchFormerInlineText() {
        let error: any Error = SampleError()
        let decodingError: any Error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))
        for error in [error, decodingError] {
            #expect(
                _LexiconDecodeDiagnostics.optionalPropertyDegradedMessage("tags", error)
                    == "Decoding error for optional property 'tags' — degrading to nil: \(error)"
            )
            #expect(
                _LexiconDecodeDiagnostics.requiredPropertyFailedMessage("uri", error)
                    == "Decoding error for required property 'uri': \(error)"
            )
            #expect(
                _LexiconDecodeDiagnostics.requiredSubStructPropertyFailedMessage("did", error)
                    == "Decoding error for required sub-struct property 'did': \(error)"
            )
            #expect(
                _LexiconDecodeDiagnostics.successfulResponseDecodeFailedMessage("app.bsky.feed.getTimeline", error)
                    == "Failed to decode successful response for app.bsky.feed.getTimeline: \(error)"
            )
        }
    }

    // MARK: Comparison helper self-checks

    @Test("Error comparison ignores NSError userInfo order but still catches real differences")
    func errorComparisonIsOrderStableAndDiscriminating() {
        func wrapped(_ userInfo: [String: Any]) -> any Error {
            DecodingError.dataCorrupted(.init(
                codingPath: [LexiconCodingKey(stringValue: "values")],
                debugDescription: "The given data was not valid JSON.",
                underlyingError: NSError(domain: NSCocoaErrorDomain, code: 3840, userInfo: userInfo)
            ))
        }
        let reference = wrapped(["NSDebugDescription": "bad", "NSJSONSerializationErrorIndex": 18, "extra": "x"])
        let reordered = wrapped(["extra": "x", "NSJSONSerializationErrorIndex": 18, "NSDebugDescription": "bad"])
        let differentIndex = wrapped(["NSDebugDescription": "bad", "NSJSONSerializationErrorIndex": 19, "extra": "x"])

        #expect(containsNSError(reference))
        #expect(!containsNSError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))))
        #expect(Self.asNSError(SampleError()) == nil)
        #expect(normalizedErrorDescription(reference) == normalizedErrorDescription(reordered))
        #expect(normalizedErrorDescription(reference) != normalizedErrorDescription(differentIndex))

        expectSameError("reordered userInfo", reference, reordered)
        withKnownIssue("A different userInfo value must still be reported") {
            expectSameError("different userInfo value", reference, differentIndex)
        }
        withKnownIssue("A different debug description must still be reported") {
            expectSameError(
                "different message",
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "a")),
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "b"))
            )
        }
    }

    // MARK: Helpers

    private func codingPathDescription(_ error: any Error) -> String {
        switch error {
        case let DecodingError.keyNotFound(key, context):
            return (context.codingPath + [key]).map(\.description).joined(separator: "/")
        case let DecodingError.typeMismatch(_, context), let DecodingError.valueNotFound(_, context):
            return context.codingPath.map(\.description).joined(separator: "/")
        case let DecodingError.dataCorrupted(context):
            return context.codingPath.map(\.description).joined(separator: "/")
        default:
            return "non-DecodingError \(type(of: error))"
        }
    }

    /// Compares two thrown errors component by component, and also by their full rendered text
    /// whenever that text is stable.
    ///
    /// The full text is not stable when an error wraps an `NSError` (for example Foundation's
    /// "not valid JSON" errors for a lone surrogate): `userInfo` is a Swift dictionary whose
    /// iteration order is seeded per instance, so two otherwise identical errors print their
    /// userInfo keys in different orders unless `SWIFT_DETERMINISTIC_HASHING` is set. Those
    /// errors are compared through `normalizedErrorDescription`, which sorts the userInfo.
    private func expectSameError(
        _ label: String,
        _ reference: any Error,
        _ candidate: any Error,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            String(describing: type(of: reference)) == String(describing: type(of: candidate)),
            "\(label)",
            sourceLocation: sourceLocation
        )
        #expect(
            normalizedErrorDescription(reference) == normalizedErrorDescription(candidate),
            "\(label)",
            sourceLocation: sourceLocation
        )
        #expect(codingPathDescription(reference) == codingPathDescription(candidate), "\(label)", sourceLocation: sourceLocation)
        if !containsNSError(reference), !containsNSError(candidate) {
            #expect(String(describing: reference) == String(describing: candidate), "\(label)", sourceLocation: sourceLocation)
            #expect(String(reflecting: reference) == String(reflecting: candidate), "\(label)", sourceLocation: sourceLocation)
        }
    }

    /// Every component of an error's rendered text, in an order-stable form: the
    /// `DecodingError` case, its type or key, the coding path, the debug description, and the
    /// underlying error (an `NSError` contributes its domain, code and sorted userInfo).
    private func normalizedErrorDescription(_ error: any Error) -> String {
        switch error {
        case let DecodingError.typeMismatch(type, context):
            return "typeMismatch(\(type)) " + normalizedContext(context)
        case let DecodingError.valueNotFound(type, context):
            return "valueNotFound(\(type)) " + normalizedContext(context)
        case let DecodingError.keyNotFound(key, context):
            return "keyNotFound(\(key.description)) " + normalizedContext(context)
        case let DecodingError.dataCorrupted(context):
            return "dataCorrupted " + normalizedContext(context)
        default:
            if let nsError = Self.asNSError(error) {
                let userInfo = nsError.userInfo
                    .map { key, value in "\(key)=\(normalizedUserInfoValue(value))" }
                    .sorted()
                    .joined(separator: ", ")
                return "NSError(domain: \(nsError.domain), code: \(nsError.code), userInfo: [\(userInfo)])"
            }
            return "\(type(of: error)): \(String(reflecting: error))"
        }
    }

    private func normalizedContext(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map(\.description).joined(separator: "/")
        let underlying = context.underlyingError.map(normalizedErrorDescription) ?? "nil"
        return "path: [\(path)] debugDescription: \(context.debugDescription) underlying: \(underlying)"
    }

    private func normalizedUserInfoValue(_ value: Any) -> String {
        if let error = value as? any Error {
            return normalizedErrorDescription(error)
        }
        return "\(value)"
    }

    /// True when rendering the error prints an `NSError` userInfo dictionary.
    private func containsNSError(_ error: any Error) -> Bool {
        switch error {
        case let DecodingError.typeMismatch(_, context),
             let DecodingError.valueNotFound(_, context),
             let DecodingError.keyNotFound(_, context),
             let DecodingError.dataCorrupted(context):
            return context.underlyingError.map(containsNSError) ?? false
        default:
            return Self.asNSError(error) != nil
        }
    }

    /// The error as an `NSError` only when it really is one, not a Swift error that Darwin
    /// would bridge (casting `any Error` to `NSError` always succeeds there). The cast goes
    /// through `Any` so it is an ordinary conditional cast on both Darwin and Linux.
    private static func asNSError(_ error: any Error) -> NSError? {
        guard type(of: error) is NSError.Type else { return nil }
        let value: Any = error
        return value as? NSError
    }

    private func expectSameOutcome<T: Equatable>(
        _ label: String,
        _ reference: Result<T, any Error>,
        _ candidate: Result<T, any Error>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        switch (reference, candidate) {
        case let (.success(a), .success(b)):
            #expect(a == b, "\(label)", sourceLocation: sourceLocation)
        case let (.failure(a), .failure(b)):
            expectSameError(label, a, b, sourceLocation: sourceLocation)
        default:
            Issue.record("Outcome kind differs for \(label): reference=\(reference) candidate=\(candidate)", sourceLocation: sourceLocation)
        }
    }
}
