import Foundation
@testable import PetrelLexicon
import Testing

/// The schema-level rules of Lexicon version 1, one rule per case.
@Suite("Lexicon: schema rules")
struct LexiconSchemaRuleTests {
    /// The error code a document is rejected with, or `nil` if it is accepted.
    static func rejection(_ json: String, options: LexiconSchemaOptions = .strict) -> LexiconSchemaError? {
        do {
            _ = try LexiconDoc(json: Data(json.utf8), options: options)
            return nil
        } catch let error as LexiconSchemaError {
            return error
        } catch {
            Issue.record("unexpected error: \(error)")
            return nil
        }
    }

    /// A document `com.example.rules` with the given `defs` body.
    static func doc(_ defs: String) -> String {
        #"{"lexicon":1,"id":"com.example.rules","defs":{\#(defs)}}"#
    }

    /// A document whose `main` object has one property `p` with the given schema.
    static func property(_ schema: String, extraDefs: String = "") -> String {
        doc(#""main":{"type":"object","properties":{"p":\#(schema)}}\#(extraDefs.isEmpty ? "" : "," + extraDefs)"#)
    }

    // MARK: Document

    @Test("document-level rules", arguments: [
        (#"[]"#, LexiconSchemaError.Code.malformedDocument),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a":{"type":"integer"}}"#, .malformedDocument),
        (#"{"id":"com.example.rules","defs":{"a":{"type":"integer"}}}"#, .unsupportedLexiconVersion),
        (#"{"lexicon":2,"id":"com.example.rules","defs":{"a":{"type":"integer"}}}"#, .unsupportedLexiconVersion),
        (#"{"lexicon":"1","id":"com.example.rules","defs":{"a":{"type":"integer"}}}"#, .unsupportedLexiconVersion),
        (#"{"lexicon":1,"defs":{"a":{"type":"integer"}}}"#, .invalidNSID),
        (#"{"lexicon":1,"id":"com.example","defs":{"a":{"type":"integer"}}}"#, .invalidNSID),
        (#"{"lexicon":1,"id":"com.example.rules#main","defs":{"a":{"type":"integer"}}}"#, .invalidNSID),
        (#"{"lexicon":1,"id":"com.example.rules"}"#, .noDefinitions),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{}}"#, .noDefinitions),
        (#"{"lexicon":1,"id":"com.example.rules","defs":[]}"#, .invalidFieldType),
        (##"{"lexicon":1,"id":"com.example.rules","defs":{"#a":{"type":"integer"}}}"##, .invalidDefinitionName),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"":{"type":"integer"}}}"#, .invalidDefinitionName),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a b":{"type":"integer"}}}"#, .invalidDefinitionName),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a":{}}}"#, .missingField),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a":{"type":5}}}"#, .invalidFieldType),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a":"integer"}}"#, .invalidFieldType),
        (#"{"lexicon":1,"id":"com.example.rules","defs":{"a":{"type":"float"}}}"#, .unknownType),
        (#"{"lexicon":1,"id":"com.example.rules","revision":"2","defs":{"a":{"type":"integer"}}}"#, .invalidFieldType),
    ])
    func documentRules(json: String, expected: LexiconSchemaError.Code) {
        #expect(Self.rejection(json)?.code == expected, "\(json)")
    }

    @Test("errors carry the NSID and a JSON pointer into the document")
    func errorLocation() {
        let error = Self.rejection(Self.property(#"{"type":"string","minLength":5,"maxLength":2}"#))
        #expect(error?.nsid == "com.example.rules")
        #expect(error?.path == "/defs/main/properties/p")
        #expect(error?.code == .invalidConstraint)
        #expect(error?.description.hasPrefix("com.example.rules invalidConstraint at /defs/main/properties/p: ") == true)
    }

    // MARK: Where types may appear

    @Test("primary types are only allowed as main", arguments: [
        #""notMain":{"type":"record","key":"tid","record":{"type":"object","properties":{}}}"#,
        #""notMain":{"type":"query"}"#,
        #""notMain":{"type":"procedure"}"#,
        #""notMain":{"type":"subscription","message":{"schema":{"type":"union","refs":[]}}}"#,
        #""notMain":{"type":"permission-set","permissions":[]}"#,
    ])
    func primaryOnlyAsMain(defs: String) {
        #expect(Self.rejection(Self.doc(defs))?.code == .primaryNotMain, "\(defs)")
        // The same definition is fine as main.
        let asMain = defs.replacingOccurrences(of: "\"notMain\"", with: "\"main\"")
        #expect(Self.rejection(Self.doc(asMain)) == nil, "\(asMain)")
    }

    @Test("types that can not be named definitions", arguments: [
        #"{"type":"unknown"}"#,
        #"{"type":"ref","ref":"com.example.other"}"#,
        #"{"type":"union","refs":[]}"#,
        #"{"type":"params","properties":{}}"#,
        #"{"type":"permission","resource":"repo"}"#,
    ])
    func notNameable(def: String) {
        #expect(Self.rejection(Self.doc(#""named":\#(def)"#))?.code == .typeNotAllowed, "named \(def)")
        #expect(Self.rejection(Self.doc(#""main":\#(def)"#))?.code == .typeNotAllowed, "main \(def)")
    }

    @Test("types that can be named definitions", arguments: [
        #"{"type":"object","properties":{}}"#,
        #"{"type":"array","items":{"type":"string"}}"#,
        #"{"type":"token"}"#,
        #"{"type":"string"}"#,
        #"{"type":"integer"}"#,
        #"{"type":"boolean"}"#,
        #"{"type":"bytes"}"#,
        #"{"type":"cid-link"}"#,
        #"{"type":"blob"}"#,
    ])
    func nameable(def: String) {
        #expect(Self.rejection(Self.doc(#""named":\#(def)"#)) == nil, "named \(def)")
        #expect(Self.rejection(Self.doc(#""main":\#(def)"#)) == nil, "main \(def)")
    }

    @Test("types that can not be object properties or array items", arguments: [
        #"{"type":"token"}"#,
        #"{"type":"params","properties":{}}"#,
        #"{"type":"query"}"#,
        #"{"type":"record","key":"tid","record":{"type":"object","properties":{}}}"#,
        #"{"type":"permission","resource":"repo"}"#,
    ])
    func notAField(schema: String) {
        #expect(Self.rejection(Self.property(schema))?.code == .typeNotAllowed, "property \(schema)")
        #expect(Self.rejection(Self.property(#"{"type":"array","items":\#(schema)}"#))?.code == .typeNotAllowed, "items \(schema)")
    }

    @Test("object and array structure")
    func containers() {
        #expect(Self.rejection(Self.doc(#""main":{"type":"object"}"#))?.code == .missingField)
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":[]}"#))?.code == .invalidFieldType)
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":{},"required":"a"}"#))?.code == .invalidFieldType)
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":{"a":{"type":"integer"}},"required":["b"]}"#))?.code == .undefinedProperty)
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":{"a":{"type":"integer"}},"nullable":["b"]}"#))?.code == .undefinedProperty)
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":{"a":{"type":"integer"}},"required":["a"],"nullable":["a"]}"#)) == nil)
        #expect(Self.rejection(Self.doc(#""main":{"type":"array"}"#))?.code == .missingField)
        #expect(Self.rejection(Self.property(#"{"type":"array","items":{"type":"integer"},"minLength":-1}"#))?.code == .invalidConstraint)
        #expect(Self.rejection(Self.property(#"{"type":"array","items":{"type":"integer"},"minLength":3,"maxLength":2}"#))?.code == .invalidConstraint)
        // Property names are free-form: dashes and dollar signs are legal.
        #expect(Self.rejection(Self.doc(#""main":{"type":"object","properties":{"cid-link":{"type":"cid-link"},"$x":{"type":"integer"}}}"#)) == nil)
    }

    @Test("definitions nested past the limit are rejected instead of overflowing the stack")
    func nestingLimit() throws {
        func nestedArrays(_ depth: Int) -> String {
            String(repeating: #"{"type":"array","items":"#, count: depth) + #"{"type":"integer"}"# + String(repeating: "}", count: depth)
        }
        #expect(Self.rejection(Self.property(nestedArrays(20))) == nil)
        #expect(Self.rejection(Self.property(nestedArrays(40)))?.code == .nestingTooDeep)
        // As deep as the data-model parser lets a document be.
        #expect(Self.rejection(Self.property(nestedArrays(120)))?.code == .nestingTooDeep)

        // A hand-built document is held to the same limit.
        var def = LexiconDef.integer(LexInteger())
        for _ in 0 ..< 40 {
            def = .array(LexArray(items: def))
        }
        let doc = LexiconDoc(id: "com.example.deep", defs: ["main": def])
        #expect(throws: LexiconSchemaError.self) { try doc.validate() }
    }

    // MARK: Constraints

    @Test("contradictory or malformed constraints are rejected", arguments: [
        #"{"type":"string","minLength":-1}"#,
        #"{"type":"string","maxGraphemes":-1}"#,
        #"{"type":"string","minGraphemes":4,"maxGraphemes":3}"#,
        #"{"type":"string","const":"a","default":"a"}"#,
        #"{"type":"string","enum":["a","b"],"default":"c"}"#,
        #"{"type":"string","enum":["a","b"],"const":"c"}"#,
        #"{"type":"string","maxLength":2,"default":"abc"}"#,
        #"{"type":"string","format":"did","default":"not a did"}"#,
        #"{"type":"integer","minimum":5,"maximum":4}"#,
        #"{"type":"integer","const":1,"default":1}"#,
        #"{"type":"integer","minimum":5,"default":4}"#,
        #"{"type":"integer","maximum":5,"const":6}"#,
        #"{"type":"integer","enum":[1,2],"default":3}"#,
        #"{"type":"boolean","const":true,"default":true}"#,
        #"{"type":"bytes","minLength":9,"maxLength":8}"#,
        #"{"type":"blob","maxSize":-1}"#,
    ])
    func invalidConstraints(schema: String) {
        #expect(Self.rejection(Self.property(schema))?.code == .invalidConstraint, "\(schema)")
    }

    @Test("constraint values of the wrong JSON type are rejected", arguments: [
        #"{"type":"string","maxLength":"5"}"#,
        #"{"type":"string","enum":"a"}"#,
        #"{"type":"string","knownValues":[1]}"#,
        #"{"type":"string","default":1}"#,
        #"{"type":"string","format":1}"#,
        #"{"type":"integer","minimum":"1"}"#,
        #"{"type":"integer","enum":["1"]}"#,
        #"{"type":"boolean","default":"true"}"#,
        #"{"type":"blob","accept":"image/*"}"#,
        ##"{"type":"union","refs":"#a"}"##,
        #"{"type":"union","refs":[],"closed":"yes"}"#,
        #"{"type":"ref","ref":5}"#,
        #"{"type":"string","description":5}"#,
    ])
    func wrongFieldTypes(schema: String) {
        #expect(Self.rejection(Self.property(schema))?.code == .invalidFieldType, "\(schema)")
    }

    @Test("coherent constraints are accepted", arguments: [
        #"{"type":"string","minLength":0,"maxLength":0}"#,
        #"{"type":"string","enum":["a","b"],"default":"a"}"#,
        #"{"type":"string","knownValues":["a"],"default":"zzz"}"#,
        #"{"type":"string","format":"language","default":"en"}"#,
        #"{"type":"integer","minimum":-5,"maximum":-5,"default":-5}"#,
        #"{"type":"integer","enum":[1,2],"const":2}"#,
        #"{"type":"boolean","default":false}"#,
        #"{"type":"blob","accept":["image/*","*/*","application/vnd.ipld.car"],"maxSize":0}"#,
    ])
    func validConstraints(schema: String) {
        #expect(Self.rejection(Self.property(schema)) == nil, "\(schema)")
    }

    @Test("unknown string formats are rejected unless tolerated")
    func unknownStringFormat() throws {
        let json = Self.property(#"{"type":"string","format":"space-ref"}"#)
        #expect(Self.rejection(json)?.code == .unknownStringFormat)
        #expect(Self.rejection(json, options: .lenient) == nil)
        // Tolerated formats do not constrain data.
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(json.utf8), options: .lenient)
        #expect(throws: Never.self) { try catalog.validate(["p": "anything"], againstDef: "com.example.rules") }
    }

    @Test("unknown definition types are rejected unless tolerated, and never validate data")
    func unknownDefinitionType() throws {
        let json = Self.doc(#""main":{"type":"space","key":"tid"},"ok":{"type":"object","properties":{}}"#)
        #expect(Self.rejection(json)?.code == .unknownType)
        let doc = try LexiconDoc(json: Data(json.utf8), options: .lenient)
        #expect(doc.main?.typeName == "space")
        // Kept verbatim, so nothing is lost on the way back out.
        #expect(try doc.lexValue == LexValue(jsonString: json))
        // A hand-built document is held to the same rule.
        #expect(throws: LexiconSchemaError.self) { try doc.validate(options: .strict) }
        var catalog = LexiconCatalog()
        try catalog.add(doc, options: .lenient)
        do {
            try catalog.validate([:], againstDef: "com.example.rules")
            Issue.record("data validated against an unsupported definition")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.unsupportedSchemaType])
        }
    }

    @Test("blob accept patterns", arguments: [
        ("image/*", true), ("*/*", true), ("image/png", true), ("application/vnd.ipld.car", true),
        ("*", false), ("text/ht*", false), ("*/png", false), ("image", false), ("image/", false), ("/png", false),
        ("image/png/extra", false), ("image/p ng", false), ("", false),
    ])
    func blobAcceptPatterns(pattern: String, valid: Bool) {
        #expect(LexBlob.isValidAcceptPattern(pattern) == valid, "\(pattern)")
        let rejection = Self.rejection(Self.property(#"{"type":"blob","accept":["\#(pattern)"]}"#))
        #expect((rejection == nil) == valid, "\(pattern)")
        if !valid {
            #expect(rejection?.code == .invalidMIMEPattern)
        }
    }

    // MARK: References and unions

    @Test("reference syntax", arguments: [
        ("com.example.other", true), ("com.example.other#thing", true), ("com.example.other#main", true),
        ("#local", true),
        ("", false), ("#", false), ("thing", false), ("com.example", false), ("com.example.other#", false),
        ("com.example.other#a#b", false), ("com.example.other#1a", false), ("lex:com.example.other", false),
        ("com.example.other #thing", false),
    ])
    func referenceSyntax(ref: String, valid: Bool) {
        let json = Self.property(#"{"type":"ref","ref":"\#(ref)"}"#, extraDefs: #""local":{"type":"object","properties":{}}"#)
        let rejection = Self.rejection(json)
        #expect((rejection == nil) == valid, "\(ref): \(String(describing: rejection))")
        if !valid {
            #expect(rejection?.code == .invalidReference)
        }
        let union = Self.property(#"{"type":"union","refs":["\#(ref)"]}"#, extraDefs: #""local":{"type":"object","properties":{}}"#)
        #expect((Self.rejection(union) == nil) == valid, "union \(ref)")
    }

    @Test("references into the same document must resolve, to something referenceable")
    func localReferences() {
        let defs = #""obj":{"type":"object","properties":{}},"tok":{"type":"token"},"str":{"type":"string"}"#
        #expect(Self.rejection(Self.property(##"{"type":"ref","ref":"#obj"}"##, extraDefs: defs)) == nil)
        #expect(Self.rejection(Self.property(##"{"type":"ref","ref":"#str"}"##, extraDefs: defs)) == nil)
        #expect(Self.rejection(Self.property(#"{"type":"ref","ref":"com.example.rules#obj"}"#, extraDefs: defs)) == nil)
        #expect(Self.rejection(Self.property(##"{"type":"ref","ref":"#missing"}"##, extraDefs: defs))?.code == .unresolvedReference)
        #expect(Self.rejection(Self.property(#"{"type":"ref","ref":"com.example.rules#missing"}"#, extraDefs: defs))?.code == .unresolvedReference)
        // A ref can not point at a token.
        #expect(Self.rejection(Self.property(##"{"type":"ref","ref":"#tok"}"##, extraDefs: defs))?.code == .invalidReferenceTarget)
        // Union variants must be objects (or records).
        #expect(Self.rejection(Self.property(##"{"type":"union","refs":["#obj"]}"##, extraDefs: defs)) == nil)
        #expect(Self.rejection(Self.property(##"{"type":"union","refs":["#str"]}"##, extraDefs: defs))?.code == .invalidReferenceTarget)
        #expect(Self.rejection(Self.property(##"{"type":"union","refs":["#tok"]}"##, extraDefs: defs))?.code == .invalidReferenceTarget)
        #expect(Self.rejection(Self.property(##"{"type":"union","refs":["#missing"]}"##, extraDefs: defs))?.code == .unresolvedReference)
    }

    @Test("an empty union is valid only when open")
    func emptyUnion() {
        #expect(Self.rejection(Self.property(#"{"type":"union","refs":[]}"#)) == nil)
        #expect(Self.rejection(Self.property(#"{"type":"union","refs":[],"closed":false}"#)) == nil)
        #expect(Self.rejection(Self.property(#"{"type":"union","refs":[],"closed":true}"#))?.code == .emptyClosedUnion)
        #expect(Self.rejection(Self.property(#"{"type":"union"}"#))?.code == .missingField)
    }

    // MARK: Primary types

    @Test("record rules")
    func records() {
        func record(_ body: String) -> String {
            Self.doc(#""main":{"type":"record",\#(body)}"#)
        }
        #expect(Self.rejection(record(#""key":"tid","record":{"type":"object","properties":{}}"#)) == nil)
        #expect(Self.rejection(record(#""key":"literal:self","record":{"type":"object","properties":{}}"#)) == nil)
        #expect(Self.rejection(record(#""record":{"type":"object","properties":{}}"#))?.code == .missingField)
        #expect(Self.rejection(record(#""key":"tid""#))?.code == .missingField)
        #expect(Self.rejection(record(#""key":"uuid","record":{"type":"object","properties":{}}"#))?.code == .invalidRecordKeyType)
        #expect(Self.rejection(record(#""key":"literal:a/b","record":{"type":"object","properties":{}}"#))?.code == .invalidRecordKeyType)
        #expect(Self.rejection(record(#""key":"tid","record":{"type":"string"}"#))?.code == .invalidFieldType)
        #expect(Self.rejection(record(#""key":"tid","record":{"type":"object","properties":{"t":{"type":"token"}}}"#))?.code == .typeNotAllowed)
    }

    @Test("query parameters are limited to primitives and arrays of primitives")
    func parameters() {
        func query(_ properties: String, required: String = "[]") -> String {
            Self.doc(#""main":{"type":"query","parameters":{"type":"params","required":\#(required),"properties":{\#(properties)}}}"#)
        }
        #expect(Self.rejection(query(#""a":{"type":"boolean"},"b":{"type":"integer"},"c":{"type":"string"},"d":{"type":"unknown"}"#)) == nil)
        #expect(Self.rejection(query(#""a":{"type":"array","items":{"type":"string"}}"#)) == nil)
        #expect(Self.rejection(query(#""a":{"type":"array","items":{"type":"integer"}}"#)) == nil)
        for schema in [
            #"{"type":"object","properties":{}}"#,
            #"{"type":"bytes"}"#,
            #"{"type":"cid-link"}"#,
            #"{"type":"blob"}"#,
            #"{"type":"ref","ref":"com.example.other"}"#,
            #"{"type":"union","refs":[]}"#,
            #"{"type":"array","items":{"type":"array","items":{"type":"string"}}}"#,
            #"{"type":"array","items":{"type":"object","properties":{}}}"#,
            #"{"type":"array","items":{"type":"ref","ref":"com.example.other"}}"#,
        ] {
            #expect(Self.rejection(query(#""a":\#(schema)"#))?.code == .typeNotAllowed, "\(schema)")
        }
        #expect(Self.rejection(query(#""a":{"type":"string"}"#, required: #"["b"]"#))?.code == .undefinedProperty)
        #expect(Self.rejection(Self.doc(#""main":{"type":"query","parameters":{"type":"object","properties":{}}}"#))?.code == .invalidFieldType)
        #expect(Self.rejection(Self.doc(#""main":{"type":"query","parameters":{"type":"params"}}"#))?.code == .missingField)
    }

    @Test("XRPC bodies, errors and subscription messages")
    func bodies() {
        func procedure(_ body: String) -> String {
            Self.doc(#""main":{"type":"procedure",\#(body)},"obj":{"type":"object","properties":{}}"#)
        }
        #expect(Self.rejection(procedure(#""input":{"encoding":"application/json","schema":{"type":"object","properties":{}}}"#)) == nil)
        #expect(Self.rejection(procedure(##""input":{"encoding":"application/json","schema":{"type":"ref","ref":"#obj"}}"##)) == nil)
        #expect(Self.rejection(procedure(##""output":{"encoding":"application/json","schema":{"type":"union","refs":["#obj"]}}"##)) == nil)
        #expect(Self.rejection(procedure(#""input":{"encoding":"*/*"}"#)) == nil)
        #expect(Self.rejection(procedure(#""input":{"schema":{"type":"object","properties":{}}}"#))?.code == .missingField)
        #expect(Self.rejection(procedure(#""input":{"encoding":""}"#))?.code == .invalidConstraint)
        #expect(Self.rejection(procedure(#""input":{"encoding":"application/json","schema":{"type":"string"}}"#))?.code == .typeNotAllowed)
        #expect(Self.rejection(procedure(#""output":{"encoding":"application/json","schema":{"type":"array","items":{"type":"string"}}}"#))?.code == .typeNotAllowed)
        #expect(Self.rejection(procedure(#""errors":[{"name":"Bad Name"}]"#))?.code == .invalidConstraint)
        #expect(Self.rejection(procedure(#""errors":[{"description":"nameless"}]"#))?.code == .missingField)
        #expect(Self.rejection(procedure(#""errors":[{"name":"Fine","description":"ok"}]"#)) == nil)

        func subscription(_ body: String) -> String {
            Self.doc(#""main":{"type":"subscription",\#(body)},"obj":{"type":"object","properties":{}}"#)
        }
        #expect(Self.rejection(subscription(##""message":{"schema":{"type":"union","refs":["#obj"]}}"##)) == nil)
        #expect(Self.rejection(subscription(#""parameters":{"type":"params","properties":{}}"#))?.code == .missingField)
        #expect(Self.rejection(subscription(#""message":{}"#))?.code == .missingField)
        // A subscription message schema must be a union, not an object.
        #expect(Self.rejection(subscription(#""message":{"schema":{"type":"object","properties":{}}}"#))?.code == .typeNotAllowed)
        #expect(Self.rejection(subscription(##""message":{"schema":{"type":"ref","ref":"#obj"}}"##))?.code == .typeNotAllowed)
    }

    @Test("permission-set rules")
    func permissionSets() throws {
        func set(_ body: String) -> String {
            Self.doc(#""main":{"type":"permission-set",\#(body)}"#)
        }
        #expect(Self.rejection(set(#""permissions":[]"#)) == nil)
        #expect(Self.rejection(set(#""title":"x""#))?.code == .missingField)
        #expect(Self.rejection(set(#""permissions":{}"#))?.code == .invalidFieldType)
        #expect(Self.rejection(set(#""permissions":[{"type":"permission"}]"#))?.code == .missingField)
        #expect(Self.rejection(set(#""permissions":[{"type":"permission","resource":""}]"#))?.code == .invalidConstraint)
        #expect(Self.rejection(set(#""permissions":[{"type":"object","resource":"repo"}]"#))?.code == .invalidFieldType)
        #expect(Self.rejection(set(#""permissions":[{"type":"permission","resource":"repo","collection":{"a":1}}]"#))?.code == .invalidFieldType)
        #expect(Self.rejection(set(#""permissions":[],"title:lang":{"not a tag":"x"}"#))?.code == .invalidLanguageTag)
        #expect(Self.rejection(set(#""permissions":[],"detail:lang":{"pt-BR":5}"#))?.code == .invalidFieldType)

        // Resources and parameters this version does not know are valid
        // schema, kept as written, and grant nothing.
        let json = set(#"""
        "permissions":[
          {"type":"permission","resource":"blob","accept":["image/*"]},
          {"type":"permission","resource":"account","attr":"email"},
          {"type":"permission","resource":"identity","attr":"handle"},
          {"type":"permission","resource":"teleport","destination":"mars","speed":9},
          {"type":"permission","resource":"repo","collection":["com.example.a"],"future":true},
          {"type":"permission","resource":"repo","collection":["*"]},
          {"type":"permission","resource":"repo","collection":[]},
          {"type":"permission","resource":"repo","collection":["com.example.a","com.example.a"]},
          {"type":"permission","resource":"repo","collection":["com.example.a"],"action":["read"]},
          {"type":"permission","resource":"rpc","lxm":["com.example.get"],"aud":"did:web:example.com#svc"},
          {"type":"permission","resource":"rpc","lxm":["com.example.get"],"aud":"*","inheritAud":true},
          {"type":"permission","resource":"rpc","lxm":["com.example.get"]},
          {"type":"permission","resource":"repo","collection":["com.example.a"]}
        ]
        """#)
        let doc = try LexiconDoc(json: Data(json.utf8))
        guard case let .permissionSet(parsed)? = doc.main else {
            Issue.record("not a permission set")
            return
        }
        #expect(parsed.permissions.map(\.resource) == [
            "blob", "account", "identity", "teleport", "repo", "repo", "repo", "repo", "repo", "rpc", "rpc", "rpc", "repo",
        ])
        #expect(parsed.permissions[3].parameters == ["destination": "mars", "speed": 9])
        #expect(parsed.permissions.dropLast().allSatisfy { $0.grant == nil })
        #expect(parsed.permissions.last?.grant == .repo(collections: ["com.example.a"], actions: nil))
        #expect(try LexiconDoc(json: doc.jsonData()) == doc)
    }

    // MARK: Model

    @Test("fields the language does not define are tolerated on decode")
    func extraFieldsTolerated() throws {
        let json = #"""
        {"lexicon":1,"id":"com.example.rules","$type":"com.atproto.lexicon.schema","x-vendor":{"a":[1,2]},
         "defs":{"main":{"type":"object","futureKeyword":true,"properties":{"p":{"type":"string","pattern":"^a"}}}}}
        """#
        let doc = try LexiconDoc(json: Data(json.utf8))
        #expect(doc.id == "com.example.rules")
        guard case let .object(main)? = doc.main, case let .string(property)? = main.properties["p"] else {
            Issue.record("unexpected model shape")
            return
        }
        #expect(property == LexString())
    }

    @Test("Codable round trip preserves every field of every type")
    func codableRoundTrip() throws {
        let json = #"""
        {"lexicon":1,"id":"com.example.everything","revision":3,"description":"all types","defs":{
          "main":{"type":"procedure","description":"d",
            "parameters":{"type":"params","description":"p","required":["q"],"properties":{
              "q":{"type":"string","description":"s","format":"did","minLength":1,"maxLength":99,"minGraphemes":1,"maxGraphemes":50,"knownValues":["a"]},
              "n":{"type":"integer","minimum":-1,"maximum":10,"enum":[1,2],"default":2},
              "b":{"type":"boolean","default":true},
              "l":{"type":"array","items":{"type":"string","enum":["x","y"]},"minLength":1,"maxLength":3},
              "u":{"type":"unknown"}}},
            "input":{"description":"in","encoding":"application/json","schema":{"type":"ref","ref":"#thing"}},
            "output":{"encoding":"application/json","schema":{"type":"union","description":"u","refs":["#thing","com.example.other#x"],"closed":true}},
            "errors":[{"name":"Nope","description":"no"},{"name":"Bare"}]},
          "thing":{"type":"object","description":"o","required":["s"],"nullable":["s"],"properties":{
            "s":{"type":"string","const":"k"},
            "i":{"type":"integer","const":4},
            "t":{"type":"boolean","const":false},
            "by":{"type":"bytes","description":"b","minLength":1,"maxLength":2},
            "c":{"type":"cid-link","description":"c"},
            "bl":{"type":"blob","description":"b","accept":["image/*"],"maxSize":1000},
            "un":{"type":"unknown","description":"u"},
            "arr":{"type":"array","description":"a","items":{"type":"ref","description":"r","ref":"#thing"}},
            "open":{"type":"union","refs":[]},
            "nested":{"type":"object","properties":{"x":{"type":"integer"}}}}},
          "tok":{"type":"token","description":"t"},
          "str":{"type":"string","knownValues":["com.example.everything#tok"]},
          "num":{"type":"integer"},
          "flag":{"type":"boolean"},
          "raw":{"type":"bytes"},
          "link":{"type":"cid-link"},
          "file":{"type":"blob"},
          "list":{"type":"array","items":{"type":"integer"}}
        }}
        """#
        let source = try LexValue(jsonString: json)
        let doc = try LexiconDoc(json: Data(json.utf8))
        #expect(doc.revision == 3)
        #expect(doc.description == "all types")
        // No field of the source is lost by the model.
        #expect(doc.lexValue == source)
        // Foundation's coders agree with the native path.
        let encoded = try JSONEncoder().encode(doc)
        #expect(try LexValue(json: encoded) == source)
        #expect(try JSONDecoder().decode(LexiconDoc.self, from: encoded) == doc)
        // A single definition is Codable on its own.
        let def = try #require(doc.defs["thing"])
        #expect(try JSONDecoder().decode(LexiconDef.self, from: JSONEncoder().encode(def)) == def)
    }

    @Test("Codable decoding validates")
    func codableValidates() {
        let invalid = Data(#"{"lexicon":1,"id":"com.example.rules","defs":{"x":{"type":"unknown"}}}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LexiconDoc.self, from: invalid) }
    }

    @Test("a subscription, a record and a permission set round-trip")
    func primaryRoundTrips() throws {
        for file in try Vectors.jsonFiles(in: "lexicon/catalog") {
            let doc = try LexiconDoc(json: Vectors.data(file))
            #expect(try LexiconDoc(doc.lexValue) == doc, "\(file)")
        }
    }

    // MARK: Catalog

    @Test("the catalog rejects duplicates unless asked to replace")
    func catalogDuplicates() throws {
        let first = Data(Self.doc(#""a":{"type":"integer"}"#).utf8)
        let second = Data(Self.doc(#""b":{"type":"string"}"#).utf8)
        var catalog = LexiconCatalog()
        try catalog.add(json: first)
        #expect(throws: LexiconSchemaError.self) { try catalog.add(json: second) }
        #expect(catalog.definition("com.example.rules#a") != nil)
        try catalog.add(json: second, replaceExisting: true)
        #expect(catalog.definition("com.example.rules#a") == nil)
        #expect(catalog.definition("com.example.rules#b")?.typeName == "string")
        #expect(catalog.remove("com.example.rules")?.id == "com.example.rules")
        #expect(catalog.nsids.isEmpty)
        #expect(catalog.remove("com.example.rules") == nil)
    }

    @Test("a hand-built document is validated when added")
    func handBuiltDocument() throws {
        var doc = LexiconDoc(id: "com.example.built", defs: [
            "main": .record(LexRecord(key: "tid", record: LexObject(
                properties: ["text": .string(LexString(maxGraphemes: 10))],
                required: ["text"]
            ))),
        ])
        var catalog = LexiconCatalog()
        try catalog.add(doc)
        #expect(throws: Never.self) {
            try catalog.validateRecord(["$type": "com.example.built", "text": "hi"], collection: "com.example.built")
        }
        doc.defs["extra"] = .ref(LexRef(ref: "#main"))
        #expect(throws: LexiconSchemaError.self) { try catalog.add(doc, replaceExisting: true) }
        doc.defs["extra"] = nil
        doc.lexicon = 2
        #expect(throws: LexiconSchemaError.self) { try doc.validate() }
    }

    @Test("references parse and print canonically")
    func references() {
        #expect(LexiconReference("com.example.a")?.description == "com.example.a")
        #expect(LexiconReference("com.example.a#main")?.description == "com.example.a")
        #expect(LexiconReference("com.example.a#main") == LexiconReference("com.example.a"))
        #expect(LexiconReference("com.example.a#view")?.name == "view")
        #expect(LexiconReference("#view") == nil)
        #expect(LexiconReference("#view", relativeTo: "com.example.a")?.description == "com.example.a#view")
    }
}
