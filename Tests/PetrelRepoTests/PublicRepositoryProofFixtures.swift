// Test-support only. This target is not a package product and is never linked
// into `swan`: it deliberately constructs artifacts that production code must
// refuse, and nothing here belongs on a serving path.
//
// CAR framing follows bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/car.ts, used under the repository's MIT OR Apache-2.0
// notice policy recorded in THIRD_PARTY_NOTICES.md.

import Crypto
import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo

public enum PublicRepositoryProofFixtureError: Error, Sendable, Equatable {
    /// The generated tree put the target key in the root node, so the proof CAR
    /// would contain the whole tree and would prove nothing about tolerating
    /// absent siblings. Raised rather than silently produced.
    case proofPathTooShallow
    /// Tampering with the commit signature produced a structurally invalid
    /// signature, which would make the fixture fail the wrong check.
    case signatureTamperingChangedStructure
    case signatureNotFoundInCommitBytes
    case unexpectedMembershipResult
    case couldNotGenerateDecoyKeys
}

/// Which artifact to build. Every case but `.valid` corresponds to a row of
/// §5.7.6's resolver vector table; the comment on each names what a resolver
/// must do with it.
public enum PublicRepositoryProofFixtureVariant: Sendable, Equatable {
    /// A well-formed single-record proof CAR. Resolves.
    case valid

    /// Two CIDs in the CAR header's `roots` array. Refused at parse.
    case twoCARRoots

    /// A correctly self-signed commit from a DIFFERENT DID's repository,
    /// carrying a lexicon at the same rkey. `commitDID` is the substitute DID
    /// and `requestedDID` is the one the resolver asked for.
    ///
    /// The fixture carries two verifiers so both halves of this vector can be
    /// pinned: `documentVerifier` holds the key the requested DID's document
    /// names (signature verification fails, catching a resolver that checks
    /// signatures but not `commit.did`), and `commitVerifier` holds the key the
    /// substitute repository's own document names (signature verification
    /// SUCCEEDS, so only the `commit.did == did` equality catches it — which is
    /// the shape of a resolver that resolves the key from the response).
    case crossRepositorySubstitution

    /// One byte flipped in `commit.sig`'s `r` scalar. The signature stays
    /// structurally canonical, so this fails the cryptographic check and not a
    /// shape check.
    case flippedCommitSignatureByte

    /// A genuine, valid signature made with a key the requested DID's document
    /// does not name.
    case commitSignedWithUnnamedKey

    /// The record block is in the CAR, but the tree under `commit.data` never
    /// links it. Membership must report provable absence, not presence.
    case recordPresentButUnlinked

    /// The record at the lexicon MST key carries a different `$type`. The
    /// argument must itself be a valid collection NSID.
    case recordTypeMismatch(String)

    /// A validly signed lexicon whose `id` names a different NSID than the rkey
    /// it sits at.
    case lexiconIDMismatch(String)

    /// The deepest node on the root→key path is withheld. A membership walk
    /// must throw rather than report absence: an attacker choosing which blocks
    /// to omit must not be able to steer that distinction.
    case omittedPathNode
}

public struct PublicRepositoryProofFixture: Sendable {
    public let variant: PublicRepositoryProofFixtureVariant

    /// The DID the resolver asked for. Equal to `commitDID` except under
    /// `.crossRepositorySubstitution`.
    public let requestedDID: String
    /// The DID inside the commit the CAR actually carries.
    public let commitDID: String

    public let nsid: String
    public let collection: String
    public let recordPath: PublicRepositoryPath
    public var mstKey: String { recordPath.mstKey }

    public let carBytes: Data
    public let carRootCIDs: [CID]

    public let commitCID: CID
    public let commitBytes: Data
    /// `commit.data` — the MST root the membership walk starts from.
    public let mstRootCID: CID

    public let recordCID: CID
    public let recordBytes: Data

    /// Exactly what the CAR carries: the commit, the root→key MST path, and the
    /// record block. Every sibling subtree is absent, which is the condition the
    /// full validators cannot survive.
    public let proofBlocks: PublicRepositoryBlockMap
    /// Every MST node and every record block of the whole repository. The
    /// positive control: the full validators accept this, so their rejection of
    /// `proofBlocks` is about the missing siblings and not a malformed tree.
    public let fullRepositoryBlocks: PublicRepositoryBlockMap
    /// Root-first, in descent order.
    public let pathNodeCIDs: [CID]
    public let decoyPaths: [PublicRepositoryPath]

    /// The key the REQUESTED DID's document names. Build a
    /// `did:key` from it with `SwanAccounts.P256DIDKey(publicKey:)`.
    public let documentPublicKeyX963: Data
    /// The key that actually signed the commit in this CAR.
    public let commitPublicKeyX963: Data
    public let documentVerifier: P256PublicRepositoryCommitVerifier
    public let commitVerifier: P256PublicRepositoryCommitVerifier
}

public enum PublicRepositoryProofFixtureBuilder {
    public static let lexiconCollection = "com.atproto.lexicon.schema"
    public static let defaultRequestedDID = "did:plc:4bqe3ktjrmrpkjfvqrpxnpgs"
    public static let defaultSubstituteDID = "did:plc:ycluxdyq7qzjvhqhqvhthfxa"
    public static let defaultNSID = "com.example.foo.auth"

    /// Builds a proof CAR and the block sets that go with it.
    ///
    /// - Parameters:
    ///   - decoyRecordCount: how many unrelated records to put in the
    ///     repository. They exist so the tree has siblings to omit; the default
    ///     is enough to force a multi-node path.
    ///   - record: overrides the default lexicon document. `$type` still comes
    ///     from the variant.
    public static func build(
        _ variant: PublicRepositoryProofFixtureVariant = .valid,
        nsid: String = defaultNSID,
        requestedDID: String = defaultRequestedDID,
        substituteDID: String = defaultSubstituteDID,
        record: PublicRecord? = nil,
        decoyRecordCount: Int = 8,
        revision: String = "3lqxpvknsi2ca",
        limits: PublicRepositoryLimits = .standard
    ) async throws -> PublicRepositoryProofFixture {
        let lexiconPath = try PublicRepositoryPath(
            collection: lexiconCollection,
            recordKey: nsid
        )

        // --- record bytes -------------------------------------------------
        let recordType: String
        switch variant {
        case let .recordTypeMismatch(type): recordType = type
        default: recordType = lexiconCollection
        }
        let lexiconID: String
        switch variant {
        case let .lexiconIDMismatch(id): lexiconID = id
        default: lexiconID = nsid
        }
        let recordValue = record ?? defaultLexiconRecord(type: recordType, id: lexiconID)
        // `prepare` requires `$type` to equal the path's collection, so encode
        // the record under a path matching its OWN type and then link it at the
        // lexicon key. Decoupling the two is the whole point of the `$type`
        // mismatch vector.
        let encodingPath = try PublicRepositoryPath(
            collection: recordType,
            recordKey: "encoding"
        )
        let preparedRecord = try PublicRepositoryRecordCodec.prepare(
            recordValue,
            for: encodingPath,
            limits: limits
        )

        // --- keys ---------------------------------------------------------
        let documentPrivateKey = P256.Signing.PrivateKey()
        let commitPrivateKey: P256.Signing.PrivateKey
        switch variant {
        case .crossRepositorySubstitution, .commitSignedWithUnnamedKey:
            commitPrivateKey = P256.Signing.PrivateKey()
        default:
            commitPrivateKey = documentPrivateKey
        }
        let commitDID: String
        switch variant {
        case .crossRepositorySubstitution: commitDID = substituteDID
        default: commitDID = requestedDID
        }

        // --- tree ---------------------------------------------------------
        let targetDepth = RepositoryMSTCodec.keyDepth(for: lexiconPath)
        let decoyPaths = try decoyPaths(
            count: decoyRecordCount,
            sameLayerAs: targetDepth,
            higherLayerCount: 2
        )
        var decoyRecords: [PublicRepositoryPath: PreparedPublicRecord] = [:]
        var tree = try RepositoryMST.empty(limits: limits)
        for path in decoyPaths {
            let prepared = try PublicRepositoryRecordCodec.prepare(
                PublicRecord([
                    "$type": .string(path.collection),
                    "text": .string("decoy \(path.recordKey)"),
                ]),
                for: path,
                limits: limits
            )
            decoyRecords[path] = prepared
            tree = try await tree.adding(path: path, recordCID: prepared.cid)
        }
        let linksRecord: Bool
        switch variant {
        case .recordPresentButUnlinked: linksRecord = false
        default: linksRecord = true
        }
        if linksRecord {
            tree = try await tree.adding(
                path: lexiconPath,
                recordCID: preparedRecord.cid
            )
        }
        let materialized = try await tree.materialized()
        let mstRootCID = materialized.rootCID
        let mstBlocks = materialized.newBlocks

        // --- root -> key path ---------------------------------------------
        // Collected by an independent walk so the fixture never certifies
        // itself with the code it exists to test.
        let walk = try await descend(
            from: mstRootCID,
            to: Data(lexiconPath.mstKey.utf8),
            in: mstBlocks
        )
        guard walk.nodeCIDs.count >= 2 else {
            throw PublicRepositoryProofFixtureError.proofPathTooShallow
        }
        switch variant {
        case .recordPresentButUnlinked:
            guard walk.recordCID == nil else {
                throw PublicRepositoryProofFixtureError.unexpectedMembershipResult
            }
        default:
            guard walk.recordCID == preparedRecord.cid else {
                throw PublicRepositoryProofFixtureError.unexpectedMembershipResult
            }
        }

        // --- commit -------------------------------------------------------
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: commitDID,
            revision: revision,
            dataCID: mstRootCID,
            signer: P256PublicRepositoryCommitSigner(privateKey: commitPrivateKey)
        )
        var commitBytes = prepared.signedCommitBytes
        var commitCID = prepared.commitCID
        if case .flippedCommitSignatureByte = variant {
            let tampered = try tamperedCommitBytes(
                prepared.signedCommitBytes,
                signature: prepared.signature
            )
            commitBytes = tampered
            commitCID = CID.fromDAGCBOR(tampered)
        }

        // --- block sets and CAR -------------------------------------------
        var pathNodeCIDs = walk.nodeCIDs
        if case .omittedPathNode = variant {
            pathNodeCIDs.removeLast()
        }
        var proof: [PublicRepositoryBlock] = [
            .init(cid: commitCID, bytes: commitBytes),
        ]
        for cid in pathNodeCIDs {
            guard let bytes = try await mstBlocks.block(for: cid) else {
                throw PublicRepositoryProofFixtureError.unexpectedMembershipResult
            }
            proof.append(.init(cid: cid, bytes: bytes))
        }
        proof.append(.init(cid: preparedRecord.cid, bytes: preparedRecord.bytes))

        var roots = [commitCID]
        if case .twoCARRoots = variant {
            // A second, structurally valid commit over the same data root. The
            // vector under test is the root-count check itself, so what the
            // extra root carries is deliberately unremarkable.
            let second = try await PublicRepositoryCommitCodec.prepare(
                did: commitDID,
                revision: "3lqxpvknsi2cb",
                dataCID: mstRootCID,
                signer: P256PublicRepositoryCommitSigner(privateKey: commitPrivateKey)
            )
            roots.append(second.commitCID)
            proof.append(.init(
                cid: second.commitCID,
                bytes: second.signedCommitBytes
            ))
        }

        var full: [PublicRepositoryBlock] = [
            .init(cid: commitCID, bytes: commitBytes),
            .init(cid: preparedRecord.cid, bytes: preparedRecord.bytes),
        ]
        for cid in mstBlocks.cids {
            guard let bytes = try await mstBlocks.block(for: cid) else { continue }
            full.append(.init(cid: cid, bytes: bytes))
        }
        for prepared in decoyRecords.values {
            full.append(.init(cid: prepared.cid, bytes: prepared.bytes))
        }

        return PublicRepositoryProofFixture(
            variant: variant,
            requestedDID: requestedDID,
            commitDID: commitDID,
            nsid: nsid,
            collection: lexiconCollection,
            recordPath: lexiconPath,
            carBytes: try encodeCAR(roots: roots, blocks: proof),
            carRootCIDs: roots,
            commitCID: commitCID,
            commitBytes: commitBytes,
            mstRootCID: mstRootCID,
            recordCID: preparedRecord.cid,
            recordBytes: preparedRecord.bytes,
            proofBlocks: try PublicRepositoryBlockMap(blocks: proof),
            fullRepositoryBlocks: try PublicRepositoryBlockMap(blocks: full),
            pathNodeCIDs: pathNodeCIDs,
            decoyPaths: decoyPaths,
            documentPublicKeyX963: documentPrivateKey.publicKey.x963Representation,
            commitPublicKeyX963: commitPrivateKey.publicKey.x963Representation,
            documentVerifier: P256PublicRepositoryCommitVerifier(
                publicKey: documentPrivateKey.publicKey
            ),
            commitVerifier: P256PublicRepositoryCommitVerifier(
                publicKey: commitPrivateKey.publicKey
            )
        )
    }

    /// Frames blocks into a CARv1 with an arbitrary root count.
    ///
    /// `PublicRepositoryCAR.write` cannot be reused here: it re-derives every
    /// CID from its bytes and emits exactly one root, so it refuses by
    /// construction to produce most of the artifacts above.
    public static func encodeCAR(
        roots: [CID],
        blocks: [PublicRepositoryBlock]
    ) throws -> Data {
        let header = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "roots", value: roots.map { ATProtoLink(cid: $0) }),
            (key: "version", value: 1),
        ]))
        var car = PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(header.count))
        car.append(header)
        for block in blocks {
            let frameLength = block.cid.bytes.count + block.bytes.count
            car.append(PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(frameLength)))
            car.append(block.cid.bytes)
            car.append(block.bytes)
        }
        return car
    }

    /// The default `com.atproto.lexicon.schema` document: a permission set
    /// naming one repo permission, which is the smallest thing §5.7.3 expansion
    /// has anything to say about.
    public static func defaultLexiconRecord(
        type: String = lexiconCollection,
        id: String = defaultNSID
    ) -> PublicRecord {
        PublicRecord([
            "$type": .string(type),
            "lexicon": .integer(1),
            "id": .string(id),
            "defs": .object([
                "main": .object([
                    "type": .string("permission-set"),
                    "permissions": .array([
                        .object([
                            "type": .string("permission"),
                            "resource": .string("repo"),
                            "collection": .array([.string("com.example.foo.item")]),
                        ]),
                    ]),
                ]),
            ]),
        ])
    }

    // MARK: - internals

    private struct Descent {
        let nodeCIDs: [CID]
        let recordCID: CID?
    }

    /// Root-first descent to `targetKey`, recording every node it touches.
    /// Deliberately not `RepositoryMSTProof.membership`.
    private static func descend(
        from rootCID: CID,
        to targetKey: Data,
        in blocks: PublicRepositoryBlockMap
    ) async throws -> Descent {
        var nodeCIDs: [CID] = []
        var cursor = rootCID
        while true {
            guard let bytes = try await blocks.block(for: cursor) else {
                throw PublicRepositoryProofFixtureError.unexpectedMembershipResult
            }
            nodeCIDs.append(cursor)
            let node = try RepositoryMSTCodec.decode(bytes)
            let leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node)
            let keys = leaves.map { Data($0.path.mstKey.utf8) }
            var index = 0
            while index < keys.count, keys[index].lexicographicallyPrecedes(targetKey) {
                index += 1
            }
            if index < keys.count, keys[index] == targetKey {
                return Descent(nodeCIDs: nodeCIDs, recordCID: leaves[index].recordCID)
            }
            let next = index == 0 ? node.leftTreeCID : leaves[index - 1].rightTreeCID
            guard let next else {
                return Descent(nodeCIDs: nodeCIDs, recordCID: nil)
            }
            cursor = next
        }
    }

    /// Picks record paths by MST layer so the target key cannot end up in the
    /// root node. `higherLayerCount` keys one layer above the target force a
    /// root that only holds them, putting the target in a child subtree whose
    /// siblings the proof CAR can then omit.
    private static func decoyPaths(
        count: Int,
        sameLayerAs targetLayer: Int,
        higherLayerCount: Int
    ) throws -> [PublicRepositoryPath] {
        let collection = "app.bsky.feed.post"
        var sameLayer: [PublicRepositoryPath] = []
        var higherLayer: [PublicRepositoryPath] = []
        var index = 0
        // Layer depth is 2 bits of a SHA-256 digest per layer, so a key one
        // layer up appears roughly every four candidates.
        while index < 20_000,
              sameLayer.count < count || higherLayer.count < higherLayerCount {
            defer { index += 1 }
            let path = try PublicRepositoryPath(
                collection: collection,
                recordKey: "decoy\(index)"
            )
            let depth = RepositoryMSTCodec.keyDepth(for: path)
            if depth == targetLayer + 1, higherLayer.count < higherLayerCount {
                higherLayer.append(path)
            } else if depth == targetLayer, sameLayer.count < count {
                sameLayer.append(path)
            }
        }
        guard sameLayer.count == count, higherLayer.count == higherLayerCount else {
            throw PublicRepositoryProofFixtureError.couldNotGenerateDecoyKeys
        }
        return sameLayer + higherLayer
    }

    /// Flips a bit in the signature's `r` scalar. `s` is left alone so the
    /// result stays low-S canonical and the fixture fails the cryptographic
    /// check rather than a structural one.
    private static func tamperedCommitBytes(
        _ commitBytes: Data,
        signature: Data
    ) throws -> Data {
        guard let range = commitBytes.range(of: signature) else {
            throw PublicRepositoryProofFixtureError.signatureNotFoundInCommitBytes
        }
        var tampered = signature
        tampered[tampered.startIndex + 31] ^= 0x01
        guard P256WireSignature.isCanonicalLowS(tampered) else {
            throw PublicRepositoryProofFixtureError.signatureTamperingChangedStructure
        }
        var result = commitBytes
        result.replaceSubrange(range, with: tampered)
        return result
    }
}
