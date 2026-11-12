import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// The examples of `Sources/PetrelRepo/PetrelRepo.docc/Repositories.md`,
/// compiled and run. `articleMatchesTheseTests` checks that the statements of
/// every Swift block in the article appear here in the same order, so the two
/// cannot drift. The article wraps each example in a function so that the
/// documentation validator can typecheck it on its own; the wrapper (imports,
/// signature, closing brace, `_ =` and `return` lines) is not compared.
@Suite("Documentation examples (Repositories.md)")
struct RepositoryDocumentationTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

    @Test("Read a repository")
    func readARepository() async throws {
        let didDocument = try Vectors.data("real-repo/diddoc.json")
        let car = try Vectors.data("real-repo/repo.car")
        var profileSummary: (Int, String?, String)?

        let key = try Repository.signingKey(fromDIDDocument: didDocument, did: did)
        let repo = try await Repository.open(
            car: car,
            verification: .signingKey(key),
            expectedDID: did
        )
        let recordCount = repo.statistics?.recordCount ?? 0
        let revision = repo.revision.value

        #expect(recordCount == 1_868)
        #expect(revision == "3mzywjbhlki2y")

        if let profile = try await repo.record(collection: "app.bsky.actor.profile", recordKey: "self") {
            let json = try profile.json()          // the data model's JSON form
            let value = try profile.record()       // a typed data-model value
            let cid = profile.cid                  // CID of the record block
            profileSummary = (json.count, value.type, cid.string)
        }

        var postKeys: [String] = []
        try await repo.forEachRecord(collection: "app.bsky.feed.post") { post in
            postKeys.append(post.recordKey)
        }

        #expect(profileSummary?.1 == "app.bsky.actor.profile")
        #expect(postKeys.count == 297)
        #expect(postKeys == postKeys.sorted())
    }

    @Test("Large repositories")
    func largeRepositories() async throws {
        let scratch = try ScratchDirectory()
        let scratchDirectory = scratch.url
        let exportedFile = try Vectors.url("real-repo/repo.car")
        let key = try Repository.signingKey(
            fromDIDDocument: try Vectors.data("real-repo/diddoc.json"), did: did
        )

        let store = try FileRepositoryBlockStore(url: scratchDirectory.appendingPathComponent("blocks"))
        let large = try await Repository.open(
            carFile: exportedFile,
            verification: .signingKey(key),
            store: store
        )
        let sink = try FileCARByteSink(url: scratchDirectory.appendingPathComponent("copy.car"))
        try await large.exportCAR(to: sink)

        try await sink.synchronize()
        let copy = try await Repository.open(
            carFile: scratchDirectory.appendingPathComponent("copy.car"),
            verification: .signingKey(key)
        )
        #expect(copy.commit == large.commit)
        #expect(copy.statistics == large.statistics)
    }

    @Test("Verify a record proof")
    func verifyARecordProof() async throws {
        let proofCAR = try Vectors.data("real-repo/record-proof-present.car")
        let key = try Repository.signingKey(
            fromDIDDocument: try Vectors.data("real-repo/diddoc.json"), did: did
        )
        let repo = try await Repository.open(
            car: try Vectors.data("real-repo/repo.car"), verification: .signingKey(key)
        )
        var provenCID: CID?

        let proof = try await Repository.verifyRecordProof(
            car: proofCAR,
            did: did,
            collection: "app.bsky.actor.profile",
            recordKey: "self",
            verification: .signingKey(key)
        )
        if let record = proof.record {
            provenCID = record.cid
        } else {
            // The proof shows there is no record at this path in this commit.
            provenCID = nil
        }

        #expect(provenCID != nil)

        let built = try await repo.recordProof(collection: "app.bsky.actor.profile", recordKey: "self")
        let responseBody = try await built.car()

        #expect(built.recordCID == provenCID)
        let again = try await Repository.verifyRecordProof(
            car: responseBody, did: did, collection: "app.bsky.actor.profile",
            recordKey: "self", verification: .signingKey(key)
        )
        #expect(again.record?.cid == provenCID)
    }

    @Test("Make a commit; publish and verify the commit's diff")
    func makeACommit() async throws {
        let signer = K256Keypair.generate()
        let mine = try await Repository.create(did: "did:plc:ewvi7nxzyoun6zhxrhs64oiz", signer: signer)

        let post: PublicRecord = [
            "$type": .string("app.bsky.feed.post"),
            "text": .string("Hello from Petrel"),
            "createdAt": .string("2026-11-11T12:00:00.000Z"),
        ]
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj2")
        let result = try await mine.commit([.create(path: path, record: post)], signer: signer)

        let head = result.repository            // the repository at the new commit
        let export = try await head.exportCAR() // a getRepo response body

        let reopened = try await Repository.open(car: export, verification: .signingKey(signer.publicKey))
        #expect(reopened.statistics?.recordCount == 1)
        #expect(try await reopened.record(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj2")?.record() == post)
        #expect(mine.revision < head.revision)
        #expect(try PublicRecord(json: post.jsonData()) == post)

        let blocks = try await result.diffCAR()     // the event's `blocks`
        let operations = result.operations          // the event's `ops`
        let previousData = result.previousDataCID   // the event's `prevData`

        let diffStore = InMemoryRepositoryBlockStore()
        let parsed = try await PublicRepositoryCAR.load(from: DataCARByteSource(blocks), into: diffStore)
        let received = try await Repository.open(
            commitCID: parsed.rootCID,
            store: diffStore,
            verification: .signingKey(signer.publicKey),
            verifiesTree: false                     // a diff holds only part of the tree
        )
        try await RepositoryCommitDiff.verifyInversion(
            dataCID: received.commit.dataCID,
            operations: operations,
            previousDataCID: previousData,
            blocks: diffStore
        )

        #expect(operations.count == 1)
        #expect(parsed.rootCID == head.commit.cid)
        _ = try await RepositoryCommitDiff.verify(
            commitCID: head.commit.cid,
            operations: operations,
            previousDataCID: previousData,
            blocks: diffStore,
            keyResolver: FixedRepositorySigningKey(signer.publicKey)
        )
    }

    @Test("every Swift block in the article appears in this file, in order")
    func articleMatchesTheseTests() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let article = try String(
            contentsOf: root.appendingPathComponent("Sources/PetrelRepo/PetrelRepo.docc/Repositories.md"),
            encoding: .utf8
        )
        func normalized(_ text: String) -> [String] {
            text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let source = normalized(try String(contentsOf: testFile, encoding: .utf8))

        var blocks: [[String]] = []
        var current: [String]?
        for line in article.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("```swift") {
                current = []
            } else if line.hasPrefix("```"), let block = current {
                blocks.append(normalized(block.joined(separator: "\n")))
                current = nil
            } else {
                current?.append(String(line))
            }
        }
        #expect(blocks.count == 9)
        for block in blocks {
            // The import block is this file's own imports, minus the ones
            // only the tests need.
            if block.allSatisfy({ $0.hasPrefix("import ") }) {
                for line in block { #expect(source.contains(line), "\(line)") }
                continue
            }
            for line in block where line.hasPrefix("import ") {
                #expect(source.contains(line), "\(line)")
            }
            let statements = exampleStatements(block)
            let first = try #require(statements.first)
            // Every statement of the example, in the same order as in this file.
            var remaining = statements[...]
            for line in source where remaining.first == line {
                remaining.removeFirst()
            }
            #expect(remaining.isEmpty, "article block starting `\(first)` is not in the tests: missing `\(remaining.first ?? "")`")
        }
    }

    /// The lines of an article example without its typechecking wrapper:
    /// imports, the `func` signature (up to the line that opens its body),
    /// the closing brace, and `_ =` / `return` lines.
    private func exampleStatements(_ block: [String]) -> [String] {
        var lines = block.filter { !$0.hasPrefix("import ") }
        if lines.first?.hasPrefix("func ") == true,
           let bodyStart = lines.firstIndex(where: { $0.hasSuffix("{") }) {
            lines.removeSubrange(...bodyStart)
            if lines.last == "}" { lines.removeLast() }
        }
        return lines.filter { !$0.hasPrefix("_ = ") && !$0.hasPrefix("return ") }
    }
}
