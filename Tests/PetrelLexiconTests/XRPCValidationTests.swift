import Foundation
@testable import PetrelLexicon
import Testing

/// XRPC parameter, body and subscription-message validation, against the
/// official catalog documents and a few purpose-built ones.
@Suite("Lexicon: XRPC validation")
struct XRPCValidationTests {
    static func issues(_ body: () throws -> Void) -> [LexiconValidationIssue] {
        do {
            try body()
            return []
        } catch let error as LexiconValidationError {
            return error.issues
        } catch {
            Issue.record("unexpected error: \(error)")
            return []
        }
    }

    static func items(_ pairs: KeyValuePairs<String, String?>) -> [URLQueryItem] {
        pairs.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    // MARK: Query-string parameters (official catalog query.json)

    @Test("query strings are coerced by the declared type")
    func coercion() throws {
        let catalog = try Vectors.catalog()
        let decoded = try catalog.validateXRPCParameters(
            Self.items([
                "stringField": "hello",
                "boolean": "true",
                "integer": "-42",
                "handle": "alice.example.com",
                "array": "1",
                "array": "2",
                "array": "3",
                "unknownParam": "ignored",
            ]),
            nsid: "example.lexicon.query"
        )
        #expect(decoded == [
            "stringField": "hello",
            "boolean": true,
            "integer": -42,
            "handle": "alice.example.com",
            "array": [1, 2, 3],
        ])
    }

    @Test("a required parameter must be present")
    func requiredParameter() throws {
        let catalog = try Vectors.catalog()
        let found = Self.issues { try catalog.validateXRPCParameters(Self.items(["integer": "1"]), nsid: "example.lexicon.query") }
        #expect(found == [
            LexiconValidationIssue(path: "/stringField", code: .missingRequiredProperty, message: "required parameter \"stringField\" is missing"),
        ])
        #expect(Self.issues { try catalog.validateXRPCParameters([], nsid: "example.lexicon.query") }.map(\.code) == [.missingRequiredProperty])
    }

    @Test("values that do not coerce are type mismatches", arguments: [
        ("boolean", "yes"), ("boolean", "TRUE"), ("boolean", "1"),
        ("integer", "1.5"), ("integer", "abc"), ("integer", "+1"), ("integer", "1e3"), ("integer", " 1"),
        ("integer", "9223372036854775808"), ("integer", "-"),
    ])
    func coercionFailures(name: String, value: String) throws {
        let catalog = try Vectors.catalog()
        let found = Self.issues {
            try catalog.validateXRPCParameters(Self.items(["stringField": "x", name: value]), nsid: "example.lexicon.query")
        }
        #expect(found.map(\.code) == [.typeMismatch], "\(name)=\(value)")
        #expect(found.first?.path == "/\(name)")
    }

    @Test("format and constraints apply to coerced values")
    func constraintsOnParameters() throws {
        let catalog = try Vectors.catalog()
        let found = Self.issues {
            try catalog.validateXRPCParameters(Self.items(["stringField": "x", "handle": "not a handle", "array": "1", "array": "two"]), nsid: "example.lexicon.query")
        }
        #expect(found.map(\.path) == ["/array/1", "/handle"])
        #expect(found.map(\.code) == [.typeMismatch, .stringFormatMismatch])
    }

    @Test("a single occurrence of an array parameter is a one-element array; a repeated scalar is an error")
    func repetition() throws {
        let catalog = try Vectors.catalog()
        let decoded = try catalog.validateXRPCParameters(Self.items(["stringField": "x", "array": "7"]), nsid: "example.lexicon.query")
        #expect(decoded["array"] == [7])
        let found = Self.issues {
            try catalog.validateXRPCParameters(Self.items(["stringField": "a", "stringField": "b"]), nsid: "example.lexicon.query")
        }
        // Reported once: the repeated value is not also called "missing".
        #expect(found.map(\.code) == [.repeatedParameter])
    }

    @Test("empty and valueless items are treated as absent")
    func emptyValues() throws {
        let catalog = try Vectors.catalog()
        let decoded = try catalog.validateXRPCParameters(
            Self.items(["stringField": "x", "integer": "", "boolean": nil]),
            nsid: "example.lexicon.query"
        )
        #expect(decoded == ["stringField": "x"])
        #expect(Self.issues {
            try catalog.validateXRPCParameters(Self.items(["stringField": ""]), nsid: "example.lexicon.query")
        }.map(\.code) == [.missingRequiredProperty])
    }

    @Test("URLComponents query items decode percent-encoding before validation")
    func fromURL() throws {
        let catalog = try Vectors.catalog()
        let components = try #require(URLComponents(string: "https://pds.example/xrpc/example.lexicon.query?stringField=a%20b%26c&integer=5&array=1&array=2"))
        let decoded = try catalog.validateXRPCParameters(components.queryItems ?? [], nsid: "example.lexicon.query")
        #expect(decoded == ["stringField": "a b&c", "integer": 5, "array": [1, 2]])
    }

    // MARK: Defaults and typed parameters

    static func defaultsCatalog() throws -> LexiconCatalog {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.search","defs":{"main":{"type":"query","parameters":{"type":"params","required":["q","limit"],"properties":{
          "q":{"type":"string","minLength":1,"maxLength":10},
          "limit":{"type":"integer","minimum":1,"maximum":100,"default":25},
          "sort":{"type":"string","enum":["top","latest"],"default":"top"},
          "exact":{"type":"boolean","default":false},
          "tags":{"type":"array","maxLength":2,"items":{"type":"string","maxLength":4}},
          "flags":{"type":"array","items":{"type":"boolean"}},
          "opaque":{"type":"unknown"}
        }}}}}
        """#.utf8))
        try catalog.add(json: Data(#"{"lexicon":1,"id":"com.example.bare","defs":{"main":{"type":"query"}}}"#.utf8))
        return catalog
    }

    @Test("declared defaults are filled in, and satisfy `required`")
    func defaults() throws {
        let catalog = try Self.defaultsCatalog()
        let decoded = try catalog.validateXRPCParameters(Self.items(["q": "cats"]), nsid: "com.example.search")
        #expect(decoded == ["q": "cats", "limit": 25, "sort": "top", "exact": false])
        let explicit = try catalog.validateXRPCParameters(
            Self.items(["q": "cats", "limit": "100", "sort": "latest", "exact": "true", "tags": "a", "tags": "b", "flags": "true", "flags": "false", "opaque": "{}"]),
            nsid: "com.example.search"
        )
        #expect(explicit == [
            "q": "cats", "limit": 100, "sort": "latest", "exact": true, "tags": ["a", "b"], "flags": [true, false], "opaque": "{}",
        ])
    }

    @Test("parameter constraints: range, enum, lengths")
    func parameterConstraints() throws {
        let catalog = try Self.defaultsCatalog()
        func codes(_ pairs: KeyValuePairs<String, String?>) -> [LexiconValidationIssue.Code] {
            Self.issues { try catalog.validateXRPCParameters(Self.items(pairs), nsid: "com.example.search") }.map(\.code)
        }
        #expect(codes(["q": "cats", "limit": "0"]) == [.integerTooSmall])
        #expect(codes(["q": "cats", "limit": "101"]) == [.integerTooLarge])
        #expect(codes(["q": "cats", "sort": "random"]) == [.valueNotInEnum])
        #expect(codes(["q": "this is too long"]) == [.stringTooLong])
        #expect(codes(["q": "cats", "tags": "a", "tags": "b", "tags": "c"]) == [.arrayTooLong])
        #expect(codes(["q": "cats", "tags": "toolong"]) == [.stringTooLong])
        #expect(codes(["q": "cats", "flags": "maybe"]) == [.typeMismatch])
    }

    @Test("typed parameters are validated without coercion")
    func typedParameters() throws {
        let catalog = try Self.defaultsCatalog()
        let decoded = try catalog.validateXRPCParameters(["q": "cats", "limit": 5, "tags": ["a"]], nsid: "com.example.search")
        #expect(decoded == ["q": "cats", "limit": 5, "sort": "top", "exact": false, "tags": ["a"]])
        // A string is not an integer once the values are typed.
        #expect(Self.issues { try catalog.validateXRPCParameters(["q": "cats", "limit": "5"], nsid: "com.example.search") }.map(\.code) == [.typeMismatch])
        #expect(Self.issues { try catalog.validateXRPCParameters(["limit": 5], nsid: "com.example.search") }.map(\.path) == ["/q"])
        #expect(Self.issues { try catalog.validateXRPCParameters("q=cats", nsid: "com.example.search") }.map(\.code) == [.typeMismatch])
    }

    @Test("an endpoint without parameters accepts and returns nothing")
    func noParameters() throws {
        let catalog = try Self.defaultsCatalog()
        #expect(try catalog.validateXRPCParameters(Self.items(["anything": "x"]), nsid: "com.example.bare").isEmpty)
        #expect(try catalog.validateXRPCParameters([:], nsid: "com.example.bare").isEmpty)
    }

    @Test("parameters can only be validated for a query, procedure or subscription")
    func parametersCatalogErrors() throws {
        let catalog = try Vectors.catalog()
        #expect(throws: LexiconCatalogError.definitionTypeMismatch(
            reference: "example.lexicon.record",
            expected: ["query", "procedure", "subscription"],
            actual: "record"
        )) {
            try catalog.validateXRPCParameters([], nsid: "example.lexicon.record")
        }
        #expect(throws: LexiconCatalogError.definitionNotFound("example.lexicon.absent")) {
            try catalog.validateXRPCParameters([], nsid: "example.lexicon.absent")
        }
        // Procedures and subscriptions declare parameters too.
        #expect(try catalog.validateXRPCParameters(Self.items(["integer": "3"]), nsid: "example.lexicon.procedure") == ["integer": 3])
        #expect(try catalog.validateXRPCParameters(Self.items(["cursor": "12"]), nsid: "example.lexicon.subscription") == ["cursor": 12])
    }

    // MARK: Bodies (official catalog query.json / procedure.json)

    @Test("output bodies are validated against the output schema")
    func output() throws {
        let catalog = try Vectors.catalog()
        #expect(throws: Never.self) { try catalog.validateXRPCOutput(["a": 1, "b": 2], nsid: "example.lexicon.query") }
        #expect(throws: Never.self) { try catalog.validateXRPCOutput([:], nsid: "example.lexicon.query") }
        #expect(Self.issues { try catalog.validateXRPCOutput(["a": "one"], nsid: "example.lexicon.query") }.map(\.path) == ["/a"])
        #expect(Self.issues { try catalog.validateXRPCOutput([1, 2], nsid: "example.lexicon.query") }.map(\.code) == [.typeMismatch])
        #expect(Self.issues { try catalog.validateXRPCOutput(nil, nsid: "example.lexicon.query") }.map(\.code) == [.nullNotAllowed])
        // The procedure's output schema covers blob, unknown, array and object.
        #expect(Self.issues {
            try catalog.validateXRPCOutput(["array": [1, "2"], "object": ["a": true], "unknown": 5], nsid: "example.lexicon.procedure")
        }.map(\.path) == ["/array/1", "/object/a", "/unknown"])
    }

    @Test("input bodies are validated against the input schema")
    func input() throws {
        let catalog = try Vectors.catalog()
        // The official procedure's input refers to app.bsky.actor.defs#preferences,
        // which the five catalog files do not include.
        #expect(Self.issues { try catalog.validateXRPCInput([:], nsid: "example.lexicon.procedure") }.map(\.code) == [.missingRequiredProperty])
        let unresolved = Self.issues { try catalog.validateXRPCInput(["preferences": []], nsid: "example.lexicon.procedure") }
        #expect(unresolved.map(\.code) == [.unresolvedReference])
        #expect(unresolved.first?.path == "/preferences")
        // A query has no input.
        #expect(throws: LexiconCatalogError.definitionTypeMismatch(reference: "example.lexicon.query", expected: ["procedure"], actual: "query")) {
            try catalog.validateXRPCInput([:], nsid: "example.lexicon.query")
        }
        #expect(throws: LexiconCatalogError.self) { try catalog.validateXRPCOutput([:], nsid: "example.lexicon.subscription") }
    }

    @Test("ref and union body schemas; endpoints without a schema accept anything")
    func bodySchemas() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.defs","defs":{
          "item":{"type":"object","required":["id"],"properties":{"id":{"type":"integer"}}},
          "note":{"type":"object","required":["text"],"properties":{"text":{"type":"string"}}},
          "name":{"type":"string"}}}
        """#.utf8))
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.put","defs":{"main":{"type":"procedure",
          "input":{"encoding":"application/json","schema":{"type":"ref","ref":"com.example.defs#item"}},
          "output":{"encoding":"application/json","schema":{"type":"union","closed":true,"refs":["com.example.defs#item","com.example.defs#note"]}}}}}
        """#.utf8))
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.upload","defs":{"main":{"type":"procedure","input":{"encoding":"*/*"},"output":{"encoding":"application/json"}}}}
        """#.utf8))
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.badref","defs":{"main":{"type":"procedure",
          "input":{"encoding":"application/json","schema":{"type":"ref","ref":"com.example.defs#name"}}}}}
        """#.utf8))

        #expect(throws: Never.self) { try catalog.validateXRPCInput(["id": 1], nsid: "com.example.put") }
        #expect(Self.issues { try catalog.validateXRPCInput(["id": "1"], nsid: "com.example.put") }.map(\.path) == ["/id"])
        #expect(Self.issues { try catalog.validateXRPCInput("x", nsid: "com.example.put") }.map(\.code) == [.typeMismatch])

        #expect(throws: Never.self) {
            try catalog.validateXRPCOutput(["$type": "com.example.defs#note", "text": "hi"], nsid: "com.example.put")
        }
        #expect(Self.issues { try catalog.validateXRPCOutput(["text": "hi"], nsid: "com.example.put") }.map(\.code) == [.missingTypeDiscriminator])
        #expect(Self.issues {
            try catalog.validateXRPCOutput(["$type": "com.example.defs#item", "id": "x"], nsid: "com.example.put")
        }.map(\.path) == ["/id"])
        #expect(Self.issues {
            try catalog.validateXRPCOutput(["$type": "com.example.other#thing"], nsid: "com.example.put")
        }.map(\.code) == [.unionVariantNotAllowed])

        // No schema: nothing to check, whatever the body is.
        #expect(throws: Never.self) { try catalog.validateXRPCInput("raw bytes stand-in", nsid: "com.example.upload") }
        #expect(throws: Never.self) { try catalog.validateXRPCOutput(["anything": [1, nil]], nsid: "com.example.upload") }

        // A body schema that refers to a non-object can not describe a body.
        #expect(Self.issues { try catalog.validateXRPCInput("x", nsid: "com.example.badref") }.map(\.code) == [.invalidReferenceTarget])
    }

    // MARK: Subscription messages (official catalog subscription.json)

    @Test("subscription messages: the frame header names the variant")
    func subscriptionWithHeaderType() throws {
        let catalog = try Vectors.catalog()
        // Event-stream bodies carry no $type; the header's `t` is "#yo".
        #expect(throws: Never.self) {
            try catalog.validateSubscriptionMessage(["seq": 1, "yo": true], nsid: "example.lexicon.subscription", type: "#yo")
        }
        #expect(throws: Never.self) {
            try catalog.validateSubscriptionMessage(["name": "OutdatedCursor"], nsid: "example.lexicon.subscription", type: "#info")
        }
        #expect(throws: Never.self) {
            try catalog.validateSubscriptionMessage(["seq": 1, "yo": true], nsid: "example.lexicon.subscription", type: "example.lexicon.subscription#yo")
        }
        let found = Self.issues {
            try catalog.validateSubscriptionMessage(["seq": "one"], nsid: "example.lexicon.subscription", type: "#yo")
        }
        #expect(found.map(\.path) == ["/seq", "/yo"])
        #expect(found.map(\.code) == [.typeMismatch, .missingRequiredProperty])
        // The union is open: a message type this schema does not know passes.
        #expect(throws: Never.self) {
            try catalog.validateSubscriptionMessage(["whatever": 1], nsid: "example.lexicon.subscription", type: "#futureEvent")
        }
        #expect(Self.issues {
            try catalog.validateSubscriptionMessage("not an object", nsid: "example.lexicon.subscription", type: "#yo")
        }.map(\.code) == [.typeMismatch])
    }

    @Test("subscription messages: without a header type the body must carry $type")
    func subscriptionWithBodyType() throws {
        let catalog = try Vectors.catalog()
        #expect(throws: Never.self) {
            try catalog.validateSubscriptionMessage(
                ["$type": "example.lexicon.subscription#yo", "seq": 1, "yo": false],
                nsid: "example.lexicon.subscription"
            )
        }
        #expect(Self.issues {
            try catalog.validateSubscriptionMessage(["seq": 1, "yo": false], nsid: "example.lexicon.subscription")
        }.map(\.code) == [.missingTypeDiscriminator])
        #expect(throws: LexiconCatalogError.self) {
            try catalog.validateSubscriptionMessage([:], nsid: "example.lexicon.query")
        }
    }

    @Test("a closed message union rejects an unknown header type")
    func closedSubscriptionUnion() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.stream","defs":{
          "main":{"type":"subscription","message":{"schema":{"type":"union","closed":true,"refs":["#tick"]}}},
          "tick":{"type":"object","required":["n"],"properties":{"n":{"type":"integer"}}}}}
        """#.utf8))
        #expect(throws: Never.self) { try catalog.validateSubscriptionMessage(["n": 1], nsid: "com.example.stream", type: "#tick") }
        let found = Self.issues { try catalog.validateSubscriptionMessage(["n": 1], nsid: "com.example.stream", type: "#tock") }
        #expect(found.map(\.code) == [.unionVariantNotAllowed])
        #expect(found.first?.path == "")
    }
}
