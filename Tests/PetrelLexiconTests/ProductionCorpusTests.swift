import Foundation
import Petrel
@testable import PetrelLexicon
import Testing

/// Loads the Lexicon corpus Petrel generates its typed API from
/// (`generator/lexicons`: app.bsky, com.atproto, chat.bsky, tools.ozone, …)
/// to prove the runtime model reads every production schema.
///
/// The corpus lives in the repository, not in the test bundle. In a checkout
/// that ships without it (a source archive, a consumer's dependency cache)
/// these tests report nothing rather than fail.
@Suite("Lexicon: production corpus")
struct ProductionCorpusTests {
    static let corpusRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("generator/lexicons", isDirectory: true)

    static func corpusFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: corpusRoot, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "json" {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    /// The one extension to Lexicon version 1 the corpus uses: the
    /// permissioned-spaces draft's `space-ref` string format. Documents that
    /// use it must be loaded with `allowUnknownStringFormats`; under the
    /// strict options they are rejected for exactly that reason.
    static let draftStringFormats: Set<String> = ["space-ref"]

    static func loadCorpus() throws -> (catalog: LexiconCatalog, strictRejections: [String: LexiconSchemaError])? {
        let files = corpusFiles()
        guard !files.isEmpty else { return nil }
        var catalog = LexiconCatalog()
        var strictRejections: [String: LexiconSchemaError] = [:]
        for file in files {
            let data = try Data(contentsOf: file)
            do {
                _ = try LexiconDoc(json: data)
            } catch let error as LexiconSchemaError {
                strictRejections[file.lastPathComponent] = error
            }
            do {
                try catalog.add(json: data, options: LexiconSchemaOptions(allowUnknownStringFormats: true))
            } catch {
                Issue.record("\(file.path): \(error)")
            }
        }
        return (catalog, strictRejections)
    }

    @Test("every bundled production Lexicon parses and passes schema validation")
    func corpusLoads() throws {
        guard let (catalog, strictRejections) = try Self.loadCorpus() else { return }
        let files = Self.corpusFiles()
        #expect(files.count >= 400, "the corpus looks truncated: \(files.count) files")
        #expect(catalog.nsids.count == files.count)

        // Namespaces the SDK ships.
        for prefix in ["app.bsky.", "com.atproto.", "chat.bsky.", "tools.ozone."] {
            #expect(catalog.nsids.contains { $0.hasPrefix(prefix) }, "no \(prefix)* Lexicon loaded")
        }

        // Strict Lexicon v1 rejects a document only for the recorded draft
        // extension, never for anything else.
        for (file, error) in strictRejections {
            #expect(error.code == .unknownStringFormat, "\(file) is rejected by strict validation: \(error)")
            #expect(Self.draftStringFormats.contains { error.message.contains("\"\($0)\"") }, "\(file): unexpected format: \(error)")
        }

        // The corpus is closed under reference: every ref and union variant
        // resolves, to a definition of a kind it may point at.
        let problems = catalog.referenceProblems()
        #expect(problems.isEmpty, "unresolved or invalid references: \(problems.prefix(10))")
    }

    @Test("every production Lexicon survives a model round trip")
    func corpusRoundTrips() throws {
        let options = LexiconSchemaOptions(allowUnknownStringFormats: true)
        for file in Self.corpusFiles() {
            let doc = try LexiconDoc(json: Data(contentsOf: file), options: options)
            let again = try LexiconDoc(doc.lexValue, options: options)
            #expect(again == doc, "round trip changed \(file.lastPathComponent)")
        }
    }

    @Test("a record built with Petrel's generated types validates against the production Lexicon")
    func generatedRecordValidates() throws {
        guard let (catalog, _) = try Self.loadCorpus() else { return }
        let post = AppBskyFeedPost(
            text: "Lexicon validation, end to end",
            langs: [LanguageCodeContainer(languageCode: "en")],
            tags: ["atproto"],
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let record = try LexValue(encoding: post)
        #expect(throws: Never.self) {
            try catalog.validateRecord(record, collection: "app.bsky.feed.post", recordKey: "3jzfcijpj2z2a")
        }

        // app.bsky.feed.post limits text to 300 graphemes and 3000 bytes;
        // the generated type does not, the runtime validator does.
        let tooLong = AppBskyFeedPost(
            text: String(repeating: "é", count: 301),
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_700_000_000))
        )
        do {
            try catalog.validateRecord(LexValue(encoding: tooLong), collection: "app.bsky.feed.post")
            Issue.record("a 301-grapheme post validated")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.stringTooManyGraphemes])
            #expect(error.first.path == "/text")
        }

        // The record key of a post is a TID.
        do {
            try catalog.validateRecord(record, collection: "app.bsky.feed.post", recordKey: "self")
            Issue.record("a non-TID record key validated for app.bsky.feed.post")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.recordKeyMismatch])
        }
    }

    @Test("production XRPC schemas validate parameters and output")
    func productionXRPC() throws {
        guard let (catalog, _) = try Self.loadCorpus() else { return }
        let decoded = try catalog.validateXRPCParameters(
            [URLQueryItem(name: "actor", value: "atproto.com"), URLQueryItem(name: "limit", value: "30")],
            nsid: "app.bsky.feed.getAuthorFeed"
        )
        #expect(decoded["actor"] == "atproto.com")
        #expect(decoded["limit"] == 30)
        // Defaults declared by the Lexicon are filled in.
        #expect(decoded["filter"] == "posts_with_replies")

        #expect(throws: LexiconValidationError.self) {
            try catalog.validateXRPCParameters(
                [URLQueryItem(name: "actor", value: "atproto.com"), URLQueryItem(name: "limit", value: "1000")],
                nsid: "app.bsky.feed.getAuthorFeed"
            )
        }
        #expect(throws: Never.self) {
            try catalog.validateXRPCOutput(["did": "did:plc:ewvi7nxzyoun6zhxrhs64oiz"], nsid: "com.atproto.identity.resolveHandle")
        }
        #expect(throws: LexiconValidationError.self) {
            try catalog.validateXRPCOutput(["did": "atproto.com"], nsid: "com.atproto.identity.resolveHandle")
        }
    }

    @Test("the Lexicon of Lexicons is in the corpus and describes itself as a record")
    func metaSchema() throws {
        guard let (catalog, _) = try Self.loadCorpus() else { return }
        guard case let .record(schema)? = catalog.definition(lexiconSchemaCollection) else {
            Issue.record("com.atproto.lexicon.schema is not a record definition")
            return
        }
        #expect(schema.keyType == .nsid)
        let published: LexValue = [
            "$type": "com.atproto.lexicon.schema",
            "lexicon": 1,
            "id": "com.example.thing",
            "defs": ["main": ["type": "token"]],
        ]
        #expect(throws: Never.self) {
            try catalog.validateRecord(published, collection: lexiconSchemaCollection, recordKey: "com.example.thing")
        }
    }
}
