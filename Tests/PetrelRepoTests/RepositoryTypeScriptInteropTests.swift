import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelRepo
import Testing

/// Repositories Petrel writes, checked by the TypeScript reference
/// implementation (`@atproto/repo`) rather than by Petrel itself.
///
/// For each curve Petrel creates a repository, commits creates across two
/// collections, then a commit with an update, a delete and a create. The
/// reference must verify the full export's signature and records, rebuild
/// the same MST root from the records, apply the last commit's diff to the
/// export before it, accept inclusion and absence proofs, and refuse the
/// export under another key or DID.
///
/// Needs Node.js and a directory with the packages pinned in
/// `Vectors/repo-ts-interop/package.json` installed; set
/// `PETREL_TS_INTEROP_DIR` to it. Skipped otherwise. Set
/// `PETREL_REPO_TS_INTEROP_TRANSCRIPT` to a file path to keep the reference's
/// transcript.
@Suite("Repository: TypeScript reference interop")
struct RepositoryTypeScriptInteropTests {
    private struct Input: Encodable {
        let cases: [Case]
    }

    private struct Case: Encodable {
        struct Record: Encodable { let path: String; let cid: String }
        struct Operation: Encodable { let action: String; let path: String; let cid: String?; let prev: String? }
        struct Proof: Encodable { let path: String; let cid: String?; let car: String }

        let label: String
        let did: String
        let didKey: String
        let commitCID: String
        let revision: String
        let dataCID: String
        let repositoryCAR: String
        let records: [Record]
        let previousRepositoryCAR: String
        let diffCAR: String
        let operations: [Operation]
        let proofs: [Proof]
    }

    private struct Output: Decodable {
        struct Check: Decodable { let name: String; let ok: Bool }
        struct Result: Decodable { let label: String; let commitCID: String; let checks: [Check] }
        let cases: [Result]
    }

    private static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

    private static func record(_ collection: String, _ text: String) -> PublicRecord {
        ["$type": .string(collection), "text": .string(text), "createdAt": .string("2026-11-12T00:00:00.000Z")]
    }

    private static func writtenCase(label: String, signer: any ATProtoKeypair) async throws -> Case {
        let posts = "app.bsky.feed.post"
        let likes = "app.bsky.feed.like"
        func path(_ collection: String, _ key: String) throws -> PublicRepositoryPath {
            try PublicRepositoryPath(collection: collection, recordKey: key)
        }
        var repository = try await Repository.create(did: did, signer: signer)
        var first: [PublicRepositoryWrite] = []
        for index in 0 ..< 40 {
            first.append(.create(path: try path(posts, "3l\(index)post"), record: record(posts, "post \(index)")))
        }
        for index in 0 ..< 10 {
            first.append(.create(path: try path(likes, "3l\(index)like"), record: record(likes, "like \(index)")))
        }
        repository = try await repository.commit(first, signer: signer).repository
        let previousCAR = try await repository.exportCAR()

        let last = try await repository.commit([
            .update(path: try path(posts, "3l0post"), record: record(posts, "edited"), expectedRecordCID: nil),
            .delete(path: try path(posts, "3l1post"), expectedRecordCID: nil),
            .delete(path: try path(likes, "3l2like"), expectedRecordCID: nil),
            .create(path: try path(posts, "3l99post"), record: record(posts, "new")),
        ], signer: signer)
        repository = last.repository

        var records: [Case.Record] = []
        try await repository.forEachRecordReference { path, cid in
            records.append(Case.Record(path: path.mstKey, cid: cid.string))
        }
        let operations = last.operations.map { operation -> Case.Operation in
            switch operation {
            case let .create(path, cid):
                Case.Operation(action: "create", path: path.mstKey, cid: cid.string, prev: nil)
            case let .update(path, cid, previous):
                Case.Operation(action: "update", path: path.mstKey, cid: cid.string, prev: previous.string)
            case let .delete(path, previous):
                Case.Operation(action: "delete", path: path.mstKey, cid: nil, prev: previous.string)
            }
        }
        var proofs: [Case.Proof] = []
        for (collection, key) in [(posts, "3l0post"), (likes, "3l9like"), (posts, "3l1post")] {
            let proof = try await repository.recordProof(collection: collection, recordKey: key)
            proofs.append(Case.Proof(
                path: proof.path.mstKey, cid: proof.recordCID?.string,
                car: try await proof.car().base64EncodedString()
            ))
        }
        return Case(
            label: label,
            did: did,
            didKey: signer.publicKey.didKey,
            commitCID: repository.commit.cid.string,
            revision: repository.commit.revision.value,
            dataCID: repository.commit.dataCID.string,
            repositoryCAR: try await repository.exportCAR().base64EncodedString(),
            records: records,
            previousRepositoryCAR: previousCAR.base64EncodedString(),
            diffCAR: try await last.diffCAR().base64EncodedString(),
            operations: operations,
            proofs: proofs
        )
    }

    @Test(
        "the TypeScript reference verifies Petrel-written repositories, diffs and proofs on both curves (live)",
        .enabled(if: ProcessInfo.processInfo.environment["PETREL_TS_INTEROP_DIR"] != nil)
    )
    func referenceVerifiesWrittenRepositories() async throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = try #require(environment["PETREL_TS_INTEROP_DIR"])
        #expect(
            FileManager.default.fileExists(atPath: "\(directory)/node_modules/@atproto/repo/package.json"),
            "PETREL_TS_INTEROP_DIR needs the packages in Vectors/repo-ts-interop/package.json"
        )
        let script = try #require(Bundle.module.url(
            forResource: "verify-petrel-repos", withExtension: "mjs", subdirectory: "Vectors/repo-ts-interop"
        ))
        let input = Input(cases: [
            try await Self.writtenCase(label: "k256", signer: K256Keypair.generate()),
            try await Self.writtenCase(label: "p256", signer: P256Keypair.generate()),
        ])

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("petrel-repo-interop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let inputURL = scratch.appendingPathComponent("repos.json")
        let outputURL = scratch.appendingPathComponent("verified.json")
        try JSONEncoder().encode(input).write(to: inputURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [environment["PETREL_TS_INTEROP_NODE"] ?? "node", script.path, inputURL.path, outputURL.path]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let transcript = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if let path = environment["PETREL_REPO_TS_INTEROP_TRANSCRIPT"] {
            try transcript.write(to: URL(fileURLWithPath: path))
        }
        #expect(process.terminationStatus == 0, "\(String(decoding: transcript, as: UTF8.self))")

        let output = try JSONDecoder().decode(Output.self, from: Data(contentsOf: outputURL))
        #expect(output.cases.map(\.label) == ["k256", "p256"])
        for (result, written) in zip(output.cases, input.cases) {
            #expect(result.commitCID == written.commitCID)
            // Four checks on the export, one on the root, three on the diff,
            // one per proof, two refusals.
            #expect(result.checks.count == 4 + 1 + 3 + written.proofs.count + 2)
            for check in result.checks {
                #expect(check.ok, "\(result.label): \(check.name)")
            }
        }
    }
}
