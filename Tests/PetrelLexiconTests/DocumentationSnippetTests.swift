import Foundation
import Petrel
import PetrelCore
import PetrelLexicon
import Testing

/// Each test here is the compiled form of a snippet in
/// `Sources/PetrelLexicon/PetrelLexicon.docc`. The articles name the test in
/// an HTML comment above the snippet; keep the two in step.
///
/// This file imports `PetrelLexicon` without `@testable`, so the snippets can
/// only use public API.
@Suite("Documentation snippets")
struct DocumentationSnippetTests {
    static let noteSchema = Data(#"""
    {
      "lexicon": 1,
      "id": "com.example.note",
      "defs": {
        "main": {
          "type": "record",
          "key": "tid",
          "record": {
            "type": "object",
            "required": ["text", "createdAt"],
            "properties": {
              "text": { "type": "string", "maxGraphemes": 280, "maxLength": 2800 },
              "createdAt": { "type": "string", "format": "datetime" },
              "langs": { "type": "array", "maxLength": 3, "items": { "type": "string", "format": "language" } },
              "attachment": { "type": "blob", "accept": ["image/*"], "maxSize": 1000000 }
            }
          }
        }
      }
    }
    """#.utf8)

    /// PetrelLexicon.md, "Overview"; RuntimeValidation.md, "Load schemas, validate a record"
    @Test func documentationValidateRecord() throws {
        let schemaJSON = Self.noteSchema

        var catalog = LexiconCatalog()
        try catalog.add(json: schemaJSON)

        let record = try LexValue.record(json: Data(#"""
        { "$type": "com.example.note", "text": "hello", "createdAt": "2026-01-01T00:00:00.000Z" }
        """#.utf8))

        try catalog.validateRecord(record, collection: "com.example.note", recordKey: "3jzfcijpj2z2a")
    }

    /// RuntimeValidation.md, "Load schemas, validate a record" (directory)
    @Test func documentationLoadDirectory() throws {
        let lexiconsDirectory = Vectors.root.appendingPathComponent("lexicon/catalog")

        var catalog = LexiconCatalog()
        try catalog.add(contentsOfDirectory: lexiconsDirectory)

        #expect(catalog.nsids.count == 5)
    }

    static let permissionSetSchema = Data(#"""
    {
      "lexicon": 1,
      "id": "com.example.calendar.authBasic",
      "defs": {
        "main": {
          "type": "permission-set",
          "title": "Calendar",
          "permissions": [
            { "type": "permission", "resource": "repo", "collection": ["com.example.calendar.event"], "action": ["create", "delete"] },
            { "type": "permission", "resource": "rpc", "lxm": ["com.example.calendar.listEvents"], "aud": "*" },
            { "type": "permission", "resource": "repo", "collection": ["app.bsky.feed.post"] },
            { "type": "permission", "resource": "account", "attr": "email" }
          ]
        }
      }
    }
    """#.utf8)

    /// RuntimeValidation.md, "Permission sets"
    @Test func documentationPermissionSet() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Self.permissionSetSchema)
        var granted: [String] = []

        guard case let .permissionSet(set)? = catalog.definition("com.example.calendar.authBasic") else { return }

        for grant in set.grants(publishedAs: "com.example.calendar.authBasic") {
            switch grant {
            case let .repo(collections, actions):
                // Write access to `collections`, limited to `actions` when not nil.
                granted.append("repo \(collections) \(actions ?? ["create", "update", "delete"])")
            case let .rpc(methods, inheritAudience):
                // Calls to `methods`, against any audience or the inherited one.
                granted.append("rpc \(methods) \(inheritAudience ? "inherited audience" : "any audience")")
            }
        }

        // The app.bsky.feed.post declaration is outside the set's namespace and
        // the account declaration is not supported in a permission set.
        #expect(granted == [
            #"repo ["com.example.calendar.event"] ["create", "delete"]"#,
            #"rpc ["com.example.calendar.listEvents"] any audience"#,
        ])
    }

    /// RuntimeValidation.md, "Read the issues"
    @Test func documentationReadIssues() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Self.noteSchema)

        let record: LexValue = [
            "$type": "com.example.note",
            "text": "hello",
            "createdAt": "yesterday",
            "langs": ["en", "not a language"],
        ]

        var report: [String] = []
        do {
            try catalog.validateRecord(record, collection: "com.example.note")
        } catch let error as LexiconValidationError {
            for issue in error.issues {
                report.append("\(issue.path): \(issue.code.rawValue)")
            }
        }

        #expect(report == [
            "/createdAt: stringFormatMismatch",
            "/langs/1: stringFormatMismatch",
        ])
    }

    /// RuntimeValidation.md, "Unknown Lexicon versus invalid data"
    @Test func documentationOptimisticValidation() throws {
        let catalog = LexiconCatalog()
        let record: LexValue = ["$type": "org.unknown.thing", "anything": 1]

        enum Outcome { case valid, unknownLexicon, invalid }
        let outcome: Outcome
        do {
            try catalog.validateRecord(record, collection: "org.unknown.thing")
            outcome = .valid
        } catch LexiconCatalogError.definitionNotFound {
            // No schema for this collection: an "optimistic" writer accepts
            // the record, a "required" one refuses it.
            outcome = .unknownLexicon
        } catch {
            outcome = .invalid
        }

        #expect(outcome == .unknownLexicon)
    }

    /// RuntimeValidation.md, "Strict data-model parsing"
    @Test func documentationStrictParsing() throws {
        // A float is not part of the data model.
        do {
            _ = try LexValue(json: Data(#"{"ratio": 0.5}"#.utf8))
            Issue.record("a float was accepted")
        } catch let error as LexValueError {
            #expect(error.code == .floatNotAllowed)
            #expect(error.path == "/ratio")
        }

        // A `$link` object with anything else in it is not a link.
        do {
            _ = try LexValue(json: Data(#"{"ref": {"$link": "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a", "x": 1}}"#.utf8))
        } catch let error as LexValueError {
            #expect(error.code == .malformedLink)
            #expect(error.path == "/ref")
        }

        // Links and bytes come out typed.
        let value = try LexValue(json: Data(#"""
        {"ref": {"$link": "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"}, "sig": {"$bytes": "aGVsbG8"}}
        """#.utf8))
        #expect(value["ref"]?.cidValue?.codec == .dagCBOR)
        #expect(value["sig"]?.bytesValue == Data("hello".utf8))
    }

    /// RuntimeValidation.md, "Canonical bytes and CIDs"
    @Test func documentationCanonicalBytes() throws {
        let record: LexValue = ["$type": "com.example.note", "text": "hello", "createdAt": "2026-01-01T00:00:00.000Z"]

        let bytes = try record.dagCBOR()
        let cid = try record.cid()

        #expect(cid == CID.fromDAGCBOR(bytes))
        #expect(try LexValue(dagCBOR: bytes) == record)
    }

    /// RuntimeValidation.md, "Validate what Petrel's typed API produces"
    @Test func documentationTypedRecord() throws {
        let post = AppBskyFeedPost(
            text: "hello",
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_767_225_600))
        )

        let record = try LexValue(encoding: post)

        #expect(record.type == "app.bsky.feed.post")
        #expect(record["text"] == "hello")
    }

    static let searchSchema = Data(#"""
    {
      "lexicon": 1,
      "id": "com.example.search",
      "defs": {
        "main": {
          "type": "query",
          "parameters": {
            "type": "params",
            "required": ["q"],
            "properties": {
              "q": { "type": "string", "minLength": 1 },
              "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 25 },
              "tag": { "type": "array", "items": { "type": "string" } }
            }
          },
          "output": {
            "encoding": "application/json",
            "schema": {
              "type": "object",
              "required": ["hits"],
              "properties": { "hits": { "type": "array", "items": { "type": "string", "format": "at-uri" } } }
            }
          }
        }
      }
    }
    """#.utf8)

    /// RuntimeValidation.md, "XRPC parameters and bodies"
    @Test func documentationXRPCParameters() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Self.searchSchema)

        let url = "https://example.com/xrpc/com.example.search?q=cats&tag=a&tag=b"
        let queryItems = URLComponents(string: url)?.queryItems ?? []
        let parameters = try catalog.validateXRPCParameters(queryItems, nsid: "com.example.search")

        #expect(parameters["q"] == "cats")
        #expect(parameters["limit"] == 25)
        #expect(parameters["tag"] == ["a", "b"])

        try catalog.validateXRPCOutput(
            ["hits": ["at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.note/3jzfcijpj2z2a"]],
            nsid: "com.example.search"
        )
    }

    static let streamSchema = Data(#"""
    {
      "lexicon": 1,
      "id": "com.example.stream",
      "defs": {
        "main": {
          "type": "subscription",
          "message": { "schema": { "type": "union", "refs": ["#tick"] } }
        },
        "tick": { "type": "object", "required": ["seq"], "properties": { "seq": { "type": "integer" } } }
      }
    }
    """#.utf8)

    /// RuntimeValidation.md, "Subscription messages"
    @Test func documentationSubscriptionMessage() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Self.streamSchema)

        // An event-stream frame is a header ({"op": 1, "t": "#tick"}) followed
        // by a body that has no `$type` of its own.
        let body: LexValue = ["seq": 42]
        try catalog.validateSubscriptionMessage(body, nsid: "com.example.stream", type: "#tick")
    }

    /// LexiconResolution.md, "Where a Lexicon is published"
    @Test func documentationAuthorityName() throws {
        let name = try LexiconAuthority.dnsName(for: "edu.university.dept.lab.blogging.getBlogPost")
        #expect(name == "_lexicon.blogging.lab.dept.university.edu")

        let did = try LexiconAuthority.did(fromTXT: ["did=did:plc:ewvi7nxzyoun6zhxrhs64oiz"], name: name)
        #expect(did == "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
    }

    /// LexiconResolution.md, "Resolve a Lexicon". Compiled, not run: it would query live DNS.
    func documentationResolveWithIdentity() async throws {
        let resolver = DefaultLexiconResolver(
            identity: IdentityResolver(),
            cache: LexiconResolutionCache(timeToLive: 300)
        )

        let resolved = try await resolver.resolve("com.example.note")
        _ = resolved
    }

    /// LexiconResolution.md, "Replace a step"
    struct ExampleDNS: LexiconDNSTXTResolving {
        func resolveTXT(_ name: String) async throws -> [String] {
            // Query your DNS resolver for the TXT records of `name`.
            name == "_lexicon.example.com" ? ["did=did:web:example.com"] : []
        }
    }

    struct ExampleDIDResolver: LexiconDIDDocumentResolving {
        func resolvePDSEndpoint(for did: String) async throws -> URL {
            // Resolve the DID document and return its #atproto_pds endpoint.
            URL(string: "https://pds.example.com")!
        }
    }

    struct ExampleFetcher: LexiconRecordFetching {
        func fetchRecord(pdsEndpoint: URL, did: String, collection: String, recordKey: String) async throws -> LexiconFetchedRecord {
            LexiconFetchedRecord(value: [
                "$type": "com.atproto.lexicon.schema",
                "lexicon": 1,
                "id": "com.example.note",
                "defs": ["main": ["type": "record", "key": "tid", "record": ["type": "object", "properties": [:]]]],
            ])
        }
    }

    @Test func documentationResolve() async throws {
        let resolver = DefaultLexiconResolver(
            dns: ExampleDNS(),
            didResolver: ExampleDIDResolver(),
            fetcher: ExampleFetcher(), // omit to use LexiconHTTPRecordFetcher
            cache: LexiconResolutionCache(timeToLive: 300)
        )

        let resolved = try await resolver.resolve("com.example.note")

        var catalog = LexiconCatalog()
        try catalog.add(resolved.doc)

        #expect(resolved.did == "did:web:example.com")
        #expect(resolved.uri == "at://did:web:example.com/com.atproto.lexicon.schema/com.example.note")
        #expect(catalog.definition("com.example.note") != nil)
    }
}
