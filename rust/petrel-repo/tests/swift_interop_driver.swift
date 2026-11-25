import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo

struct OpJSON: Codable {
    let action: String
    let collection: String
    let rkey: String
    let cid: String?
    let prev: String?
}

struct SwiftManifest: Codable {
    let did: String
    let p256DidKey: String
    let p256CommitCID: String
    let p256DataCID: String
    let p256Rev: String
    let p256PreviousDataCID: String
    let p256Ops: [OpJSON]
    let k256DidKey: String
    let k256CommitCID: String
    let k256DataCID: String
    let k256Rev: String
    let presentCollection: String
    let presentRkey: String
    let absentCollection: String
    let absentRkey: String
}

struct RustManifest: Codable {
    let did: String
    let p256DidKey: String
    let p256CommitCID: String
    let p256DataCID: String
    let p256Rev: String
    let p256RecordCount: Int
    let p256PreviousDataCID: String
    let p256Ops: [OpJSON]
    let k256DidKey: String
    let k256CommitCID: String
    let k256DataCID: String
    let k256Rev: String
    let k256RecordCount: Int
    let presentCollection: String
    let presentRkey: String
    let presentText: String
    let absentCollection: String
    let absentRkey: String
}

func makePost(text: String) -> PublicRecord {
    [
        "$type": .string("app.bsky.feed.post"),
        "text": .string(text),
        "createdAt": .string("2026-11-25T10:00:00.000Z"),
    ]
}

func encodeOps(_ ops: [RepositoryCommitOperation]) -> [OpJSON] {
    ops.map { op in
        switch op {
        case let .create(path, cid):
            return OpJSON(
                action: "create",
                collection: path.collection,
                rkey: path.recordKey,
                cid: cid.string,
                prev: nil
            )
        case let .update(path, cid, prev):
            return OpJSON(
                action: "update",
                collection: path.collection,
                rkey: path.recordKey,
                cid: cid.string,
                prev: prev.string
            )
        case let .delete(path, prev):
            return OpJSON(
                action: "delete",
                collection: path.collection,
                rkey: path.recordKey,
                cid: nil,
                prev: prev.string
            )
        }
    }
}

func decodeOps(_ ops: [OpJSON]) throws -> [RepositoryCommitOperation] {
    try ops.map { op in
        let path = try PublicRepositoryPath(collection: op.collection, recordKey: op.rkey)
        switch op.action {
        case "create":
            let cidStr = op.cid!
            return .create(path: path, cid: try CID.parse(cidStr))
        case "update":
            return .update(
                path: path,
                cid: try CID.parse(op.cid!),
                previous: try CID.parse(op.prev!)
            )
        case "delete":
            return .delete(path: path, previous: try CID.parse(op.prev!))
        default:
            fatalError("unknown op action: \(op.action)")
        }
    }
}

func emitFixtures(outDir: URL) async throws {
    let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    let p256 = P256Keypair.generate()
    let k256 = K256Keypair.generate()

    // P-256 repo: create genesis -> commit batch1 -> commit batch2 (create+update+delete)
    let repo0 = try await Repository.create(did: did, signer: p256)
    let p1 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj2")
    let p2 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj3")
    let p3 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj4")
    let p4 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj5")

    let res1 = try await repo0.commit(
        [
            .create(path: p1, record: makePost(text: "swift-one")),
            .create(path: p2, record: makePost(text: "swift-two")),
            .create(path: p3, record: makePost(text: "swift-three")),
        ],
        signer: p256
    )

    let res2 = try await res1.repository.commit(
        [
            .delete(path: p1, expectedRecordCID: nil),
            .update(path: p2, record: makePost(text: "swift-two-updated"), expectedRecordCID: nil),
            .create(path: p4, record: makePost(text: "swift-four")),
        ],
        signer: p256
    )

    let p256Head = res2.repository
    let p256CAR = try await p256Head.exportCAR()
    try p256CAR.write(to: outDir.appendingPathComponent("swift_p256.car"))

    let presentProof = try await p256Head.recordProof(
        collection: "app.bsky.feed.post",
        recordKey: "3lon5dzeaihj3"
    )
    try await presentProof.car().write(to: outDir.appendingPathComponent("swift_p256_proof_present.car"))

    let absentProof = try await p256Head.recordProof(
        collection: "app.bsky.feed.post",
        recordKey: "3lon5dzeaihj2"
    )
    try await absentProof.car().write(to: outDir.appendingPathComponent("swift_p256_proof_absent.car"))

    let diffCAR = try await res2.diffCAR()
    try diffCAR.write(to: outDir.appendingPathComponent("swift_p256_diff.car"))

    // K-256 repo
    let kRepo0 = try await Repository.create(did: did, signer: k256)
    let kRes = try await kRepo0.commit(
        [.create(path: p1, record: makePost(text: "swift-k256-post"))],
        signer: k256
    )
    let kHead = kRes.repository
    let kCAR = try await kHead.exportCAR()
    try kCAR.write(to: outDir.appendingPathComponent("swift_k256.car"))

    let manifest = SwiftManifest(
        did: did,
        p256DidKey: p256.publicKey.didKey,
        p256CommitCID: p256Head.commit.cid.string,
        p256DataCID: p256Head.commit.dataCID.string,
        p256Rev: p256Head.revision.value,
        p256PreviousDataCID: res2.previousDataCID.string,
        p256Ops: encodeOps(res2.operations),
        k256DidKey: k256.publicKey.didKey,
        k256CommitCID: kHead.commit.cid.string,
        k256DataCID: kHead.commit.dataCID.string,
        k256Rev: kHead.revision.value,
        presentCollection: "app.bsky.feed.post",
        presentRkey: "3lon5dzeaihj3",
        absentCollection: "app.bsky.feed.post",
        absentRkey: "3lon5dzeaihj2"
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(to: outDir.appendingPathComponent("swift_manifest.json"))
}

func verifyRustFixtures(inDir: URL) async throws {
    let manifestData = try Data(contentsOf: inDir.appendingPathComponent("rust_manifest.json"))
    let manifest = try JSONDecoder().decode(RustManifest.self, from: manifestData)

    // 1. Verify Rust-generated P-256 repository CAR in Swift
    let p256Key = try ATProtoPublicKey(didKey: manifest.p256DidKey)
    let p256CAR = try Data(contentsOf: inDir.appendingPathComponent("rust_p256.car"))
    let p256Repo = try await Repository.open(
        car: p256CAR,
        verification: .signingKey(p256Key),
        expectedDID: manifest.did
    )
    precondition(p256Repo.commit.cid.string == manifest.p256CommitCID, "P256 commit CID mismatch")
    precondition(p256Repo.commit.dataCID.string == manifest.p256DataCID, "P256 data CID mismatch")
    precondition(p256Repo.revision.value == manifest.p256Rev, "P256 rev mismatch")
    precondition(p256Repo.statistics?.recordCount == manifest.p256RecordCount, "P256 record count mismatch")

    let reexportedP256 = try await p256Repo.exportCAR()
    precondition(reexportedP256 == p256CAR, "Swift re-export of Rust P256 CAR differed bytewise!")

    let presentEntry = try await p256Repo.record(
        collection: manifest.presentCollection,
        recordKey: manifest.presentRkey
    )
    precondition(presentEntry != nil, "Expected present Rust record missing in Swift")
    let decoded = try presentEntry!.record()
    precondition(decoded.fields["text"] == .string(manifest.presentText), "Record text mismatch")

    // 2. Verify Rust-generated inclusion & exclusion proof CARs in Swift
    let presentProofCAR = try Data(contentsOf: inDir.appendingPathComponent("rust_proof_present.car"))
    let verifiedPresent = try await Repository.verifyRecordProof(
        car: presentProofCAR,
        did: manifest.did,
        collection: manifest.presentCollection,
        recordKey: manifest.presentRkey,
        verification: .signingKey(p256Key)
    )
    precondition(verifiedPresent.record?.cid == presentEntry?.cid, "Inclusion proof CID mismatch")

    let absentProofCAR = try Data(contentsOf: inDir.appendingPathComponent("rust_proof_absent.car"))
    let verifiedAbsent = try await Repository.verifyRecordProof(
        car: absentProofCAR,
        did: manifest.did,
        collection: manifest.absentCollection,
        recordKey: manifest.absentRkey,
        verification: .signingKey(p256Key)
    )
    precondition(verifiedAbsent.record == nil, "Exclusion proof unexpectedly returned record")

    // 3. Verify Rust-generated commit diff CAR in Swift
    let rustDiffCAR = try Data(contentsOf: inDir.appendingPathComponent("rust_diff.car"))
    let diffStore = InMemoryRepositoryBlockStore()
    let parsedDiff = try await PublicRepositoryCAR.load(from: DataCARByteSource(rustDiffCAR), into: diffStore)
    precondition(parsedDiff.rootCID.string == manifest.p256CommitCID, "Diff CAR root CID mismatch")
    let swiftOps = try decodeOps(manifest.p256Ops)
    _ = try await RepositoryCommitDiff.verify(
        commitCID: parsedDiff.rootCID,
        operations: swiftOps,
        previousDataCID: try CID.parse(manifest.p256PreviousDataCID),
        blocks: diffStore,
        keyResolver: FixedRepositorySigningKey(p256Key)
    )

    // 4. Verify Rust-generated K-256 repository CAR in Swift
    let k256Key = try ATProtoPublicKey(didKey: manifest.k256DidKey)
    let k256CAR = try Data(contentsOf: inDir.appendingPathComponent("rust_k256.car"))
    let k256Repo = try await Repository.open(
        car: k256CAR,
        verification: .signingKey(k256Key),
        expectedDID: manifest.did
    )
    precondition(k256Repo.commit.cid.string == manifest.k256CommitCID, "K256 commit CID mismatch")
    precondition(k256Repo.commit.dataCID.string == manifest.k256DataCID, "K256 data CID mismatch")
    precondition(k256Repo.revision.value == manifest.k256Rev, "K256 rev mismatch")
    precondition(k256Repo.statistics?.recordCount == manifest.k256RecordCount, "K256 record count mismatch")
    let reexportedK256 = try await k256Repo.exportCAR()
    precondition(reexportedK256 == k256CAR, "Swift re-export of Rust K256 CAR differed bytewise!")
}

@main
struct SwiftRepoInteropDriver {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            fatalError("usage: swift_interop_driver <emit|verify> <dir>")
        }
        let mode = args[1]
        let dir = URL(fileURLWithPath: args[2], isDirectory: true)
        switch mode {
        case "emit":
            try await emitFixtures(outDir: dir)
        case "verify":
            try await verifyRustFixtures(inDir: dir)
        default:
            fatalError("unknown mode \(mode)")
        }
    }
}
