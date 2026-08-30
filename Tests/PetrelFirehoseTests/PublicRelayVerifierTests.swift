import Crypto
import Foundation
import Petrel
@testable import PetrelFirehose
import PetrelRepo
import XCTest

final class PublicRelayVerifierTests: XCTestCase {
  private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  private let rev0 = "3jzfcijpj2z2a"
  private let rev1 = "3jzfcijpj2z2b"
  private let rev2 = "3jzfcijpj2z2c"
  private let time = "2026-08-08T12:00:00.000Z"

  func testDecoderAcceptsHandDerivedCanonicalIdentityFrame() throws {
    let event = try RelayFrameDecoder.decode(identityFrame(seq: 1))
    XCTAssertEqual(
      event,
      .identity(.init(seq: 1, did: did, time: time, handle: "alice.test"))
    )
  }

  func testDecoderRejectsMalformedCanonicalAndHeaderMutationMatrix() throws {
    let valid = identityFrame(seq: 1)
    let mutations: [(Data, RelayVerifierError)] = [
      (Data(), .truncatedFrame),
      (Data(valid.dropLast()), .truncatedFrame),
      (valid + Data([0xf6]), .trailingFrameBytes),
      (nonCanonicalIdentityFrame(), .nonCanonicalCBOR),
      (nonCanonicalHeaderOrderIdentityFrame(), .nonCanonicalCBOR),
      (identityFrame(seq: 1, headerType: "#unknown"), .unknownEventKind),
      (identityFrame(seq: 1, headerOp: -1), .invalidFrameHeader),
      (identityFrame(seq: 1, extraBodyEntry: ("unexpected", .null)), .invalidEventBody),
    ]
    for (candidate, expected) in mutations {
      XCTAssertThrowsError(try RelayFrameDecoder.decode(candidate)) {
        XCTAssertEqual($0 as? RelayVerifierError, expected)
      }
    }
  }

  func testDecoderRejectsBadCIDLinksSequenceBoundsAndBodyCombinations() throws {
    let cid = CID.fromDAGCBOR(Data([0xa0]))
    let validCommit = commitFrame(
      seq: 1,
      commitCID: cid,
      blocks: Data(),
      ops: [.init(action: "create", path: "app.bsky.feed.post/a", cid: cid, prev: nil)]
    )
    XCTAssertNotNil(try RelayFrameDecoder.decode(validCommit))

    let badLink = commitFrame(
      seq: 1,
      commitCIDValue: .tag(42, .bytes(Data([0x01, 0x02]))),
      blocks: Data(),
      ops: []
    )
    XCTAssertThrowsError(try RelayFrameDecoder.decode(badLink)) {
      XCTAssertEqual($0 as? RelayVerifierError, .invalidCIDLink)
    }

    for seq in [Int64(0), FirehoseFrameLimits.maximumSequence + 1] {
      XCTAssertThrowsError(try RelayFrameDecoder.decode(identityFrame(seq: seq))) {
        XCTAssertEqual($0 as? RelayVerifierError, .sequenceOutOfRange)
      }
    }
    XCTAssertNoThrow(try RelayFrameDecoder.decode(identityFrame(
      seq: FirehoseFrameLimits.maximumSequence
    )))

    let invalidAccount = accountFrame(seq: 1, active: true, status: "suspended")
    XCTAssertThrowsError(try RelayFrameDecoder.decode(invalidAccount)) {
      XCTAssertEqual($0 as? RelayVerifierError, .invalidAccountStatus)
    }

    let badOp = commitFrame(
      seq: 1,
      commitCID: cid,
      blocks: Data(),
      ops: [.init(action: "update", path: "app.bsky.feed.post/a", cid: cid, prev: nil)]
    )
    XCTAssertThrowsError(try RelayFrameDecoder.decode(badOp)) {
      XCTAssertEqual($0 as? RelayVerifierError, .invalidRepositoryOperation)
    }
  }

  func testDecoderEnforcesExactFrameBlocksAndOperationLimits() throws {
    let cid = CID.fromDAGCBOR(Data([0xa0]))
    let exactCommitBlocks = Data(repeating: 0, count: FirehoseFrameLimits.maximumCommitBlocksBytes)
    XCTAssertNoThrow(try RelayFrameDecoder.decode(commitFrame(
      seq: 1, commitCID: cid, blocks: exactCommitBlocks, ops: []
    )))
    XCTAssertThrowsError(try RelayFrameDecoder.decode(commitFrame(
      seq: 1,
      commitCID: cid,
      blocks: exactCommitBlocks + Data([0]),
      ops: []
    ))) {
      XCTAssertEqual($0 as? RelayVerifierError, .commitBlocksTooLarge)
    }

    let exactSyncBlocks = Data(repeating: 0, count: FirehoseFrameLimits.maximumSyncBlocksBytes)
    XCTAssertNoThrow(try RelayFrameDecoder.decode(syncFrame(seq: 1, blocks: exactSyncBlocks)))
    XCTAssertThrowsError(try RelayFrameDecoder.decode(syncFrame(
      seq: 1, blocks: exactSyncBlocks + Data([0])
    ))) {
      XCTAssertEqual($0 as? RelayVerifierError, .syncBlocksTooLarge)
    }

    let op = TestOp(action: "create", path: "app.bsky.feed.post/a", cid: cid, prev: nil)
    XCTAssertNoThrow(try RelayFrameDecoder.decode(commitFrame(
      seq: 1,
      commitCID: cid,
      blocks: Data(),
      ops: Array(repeating: op, count: FirehoseFrameLimits.maximumOps)
    )))
    XCTAssertThrowsError(try RelayFrameDecoder.decode(commitFrame(
      seq: 1,
      commitCID: cid,
      blocks: Data(),
      ops: Array(repeating: op, count: FirehoseFrameLimits.maximumOps + 1)
    ))) {
      XCTAssertEqual($0 as? RelayVerifierError, .tooManyOperations)
    }

    let frameOverLimit = Data(repeating: 0, count: FirehoseFrameLimits.maximumFrameBytes + 1)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(frameOverLimit)) {
      XCTAssertEqual($0 as? RelayVerifierError, .frameTooLarge)
    }

    let exactFrame = infoFrame(exactByteCount: FirehoseFrameLimits.maximumFrameBytes)
    XCTAssertEqual(exactFrame.count, FirehoseFrameLimits.maximumFrameBytes)
    XCTAssertNoThrow(try RelayFrameDecoder.decode(exactFrame))
    XCTAssertThrowsError(try RelayFrameDecoder.decode(exactFrame + Data([0]))) {
      XCTAssertEqual($0 as? RelayVerifierError, .frameTooLarge)
    }
  }

  func testSequenceVerifierProvesLifecycleOfflineDeltaAndReconnectBounds() throws {
    let events: [RelayEvent] = [
      .identity(.init(seq: 10, did: did, time: time, handle: "alice.test")),
      .account(.init(seq: 11, did: did, time: time, active: true, status: nil)),
      .sync(.init(seq: 12, did: did, blocks: Data(), rev: rev0, time: time)),
    ] + (13 ... 17).map {
      .commit(.init(
        seq: Int64($0), repo: did, commitCID: sampleCID($0), rev: rev1,
        since: rev0, blocks: Data(), ops: [], prevDataCID: sampleCID(0), time: time
      ))
    }
    let result = try RelaySequenceVerifier.verify(
      events: events,
      reconnects: [.init(upstreamCursor: 120, firstDeliveredRelaySequence: 13)],
      offlineCommitRange: 13 ... 17,
      expectedOfflineCommitCount: 5
    )
    XCTAssertEqual(result.firstSequence, 10)
    XCTAssertEqual(result.lastSequence, 17)
    XCTAssertEqual(result.offlineCommitCount, 5)
  }

  func testSequenceVerifierKeepsUpstreamCursorAndRelayDeliveryDomainsSeparate() throws {
    let events: [RelayEvent] = [
      .identity(.init(seq: 10, did: did, time: time, handle: "alice.test")),
      .account(.init(seq: 11, did: did, time: time, active: true, status: nil)),
      .sync(.init(seq: 12, did: did, blocks: Data(), rev: rev0, time: time)),
      .commit(.init(
        seq: 13, repo: did, commitCID: sampleCID(13), rev: rev1,
        since: rev0, blocks: Data(), ops: [], prevDataCID: sampleCID(0), time: time
      )),
    ] + (14 ... 18).map {
      .commit(.init(
        seq: Int64($0), repo: did, commitCID: sampleCID($0), rev: rev1,
        since: rev0, blocks: Data(), ops: [], prevDataCID: sampleCID(0), time: time
      ))
    }
    XCTAssertNoThrow(try RelaySequenceVerifier.verify(
      events: events,
      reconnects: [.init(upstreamCursor: 900, firstDeliveredRelaySequence: 14)],
      offlineCommitRange: 14 ... 18,
      expectedOfflineCommitCount: 5
    ))

    let mutations: [([RelayEvent], [RelayReconnectEvidence], RelayVerifierError)] = [
      (events, [], .reconnectCursorOutOfBounds),
      (events, [.init(upstreamCursor: 900, firstDeliveredRelaySequence: 13)], .reconnectCursorOutOfBounds),
      (events, [.init(upstreamCursor: FirehoseFrameLimits.maximumSequence + 1,
                      firstDeliveredRelaySequence: 14)], .reconnectCursorOutOfBounds),
      (Array(events.prefix(4)) + [events[3]] + Array(events.dropFirst(4)),
       [.init(upstreamCursor: 900, firstDeliveredRelaySequence: 14)], .duplicateSequence),
    ]
    for (candidate, reconnects, expected) in mutations {
      XCTAssertThrowsError(try RelaySequenceVerifier.verify(
        events: candidate,
        reconnects: reconnects,
        offlineCommitRange: 14 ... 18,
        expectedOfflineCommitCount: 5
      )) {
        XCTAssertEqual($0 as? RelayVerifierError, expected)
      }
    }
  }

  func testSequenceVerifierRejectsDuplicateGapCursorAndOfflineCountMatrix() throws {
    let base = [
      RelayEvent.identity(.init(seq: 1, did: did, time: time, handle: nil)),
      .account(.init(seq: 2, did: did, time: time, active: true, status: nil)),
      .sync(.init(seq: 3, did: did, blocks: Data(), rev: rev0, time: time)),
    ]
    let cases: [([RelayEvent], [RelayReconnectEvidence], ClosedRange<Int64>?, Int, RelayVerifierError)] = [
      (base + [.sync(.init(seq: 3, did: did, blocks: Data(), rev: rev0, time: time))], [], nil, 0, .duplicateSequence),
      ([base[0], base[2]], [], nil, 0, .sequenceGap),
      (base, [.init(upstreamCursor: -1, firstDeliveredRelaySequence: 3)], nil, 0, .reconnectCursorOutOfBounds),
      (base, [.init(upstreamCursor: 4, firstDeliveredRelaySequence: 5)], nil, 0, .reconnectCursorOutOfBounds),
      (base, [], 4 ... 8, 5, .offlineCommitCountMismatch),
    ]
    for (events, reconnects, range, expectedCount, expected) in cases {
      XCTAssertThrowsError(try RelaySequenceVerifier.verify(
        events: events,
        reconnects: reconnects,
        offlineCommitRange: range,
        expectedOfflineCommitCount: expectedCount
      )) {
        XCTAssertEqual($0 as? RelayVerifierError, expected)
      }
    }
  }

  func testLifecycleVerifierRejectsWrongOrderAndDIDCrossing() throws {
    let accountFirst: [RelayEvent] = [
      .account(.init(seq: 1, did: did, time: time, active: true, status: nil)),
      .identity(.init(seq: 2, did: did, time: time, handle: nil)),
    ]
    XCTAssertThrowsError(try RelayLifecycleVerifier.verify(events: accountFirst)) {
      XCTAssertEqual($0 as? RelayVerifierError, .lifecycleOrderMismatch)
    }
    let otherDID = "did:web:other.example"
    let crossed: [RelayEvent] = [
      .identity(.init(seq: 1, did: did, time: time, handle: nil)),
      .account(.init(seq: 2, did: otherDID, time: time, active: true, status: nil)),
    ]
    XCTAssertThrowsError(try RelayLifecycleVerifier.verify(events: crossed, expectedDID: did)) {
      XCTAssertEqual($0 as? RelayVerifierError, .repositoryDIDMismatch)
    }
  }

  func testCommitSemanticVerifierAcceptsExactProjectionDelta() throws {
    let oldCID = sampleCID(1)
    let newCID = sampleCID(2)
    let previous = snapshot(rev: rev0, commit: sampleCID(10), data: sampleCID(11), records: [
      "app.bsky.feed.post/a": oldCID,
    ])
    let current = snapshot(rev: rev1, commit: sampleCID(12), data: sampleCID(13), records: [
      "app.bsky.feed.post/a": newCID,
    ])
    let event = RelayCommitEvent(
      seq: 4, repo: did, commitCID: current.commitCID, rev: rev1,
      since: rev0, blocks: Data(),
      ops: [.init(action: .update, path: "app.bsky.feed.post/a", cid: newCID, prev: oldCID)],
      prevDataCID: previous.dataCID, time: time
    )
    XCTAssertNoThrow(try RelayCommitSemanticVerifier.verify(
      event: event,
      previous: previous,
      current: current
    ))
  }

  func testCommitSemanticVerifierRejectsEveryAgreementAndDeltaMutation() throws {
    let oldCID = sampleCID(1)
    let newCID = sampleCID(2)
    let previous = snapshot(rev: rev0, commit: sampleCID(10), data: sampleCID(11), records: [
      "app.bsky.feed.post/a": oldCID,
    ])
    let current = snapshot(rev: rev1, commit: sampleCID(12), data: sampleCID(13), records: [
      "app.bsky.feed.post/a": newCID,
    ])
    let valid = RelayCommitEvent(
      seq: 4, repo: did, commitCID: current.commitCID, rev: rev1,
      since: rev0, blocks: Data(),
      ops: [.init(action: .update, path: "app.bsky.feed.post/a", cid: newCID, prev: oldCID)],
      prevDataCID: previous.dataCID, time: time
    )
    let cases: [(RelayCommitEvent, RelayRepositorySnapshot, RelayRepositorySnapshot, RelayVerifierError)] = [
      (valid.replacing(repo: "did:web:wrong.example"), previous, current, .repositoryDIDMismatch),
      (valid.replacing(rev: rev0), previous, current, .commitRevisionMismatch),
      (valid.replacing(commitCID: sampleCID(99)), previous, current, .commitCIDMismatch),
      (valid.replacing(since: .some(nil)), previous, current, .sinceRevisionMismatch),
      (valid.replacing(prevDataCID: .some(nil)), previous, current, .previousDataCIDMismatch),
      (valid.replacing(ops: [.init(action: .create, path: "app.bsky.feed.post/a", cid: newCID, prev: nil)]), previous, current, .repositoryDeltaMismatch),
      (valid.replacing(ops: [.init(action: .update, path: "app.bsky.feed.post/b", cid: newCID, prev: oldCID)]), previous, current, .repositoryDeltaMismatch),
      (valid.replacing(ops: [.init(action: .update, path: "app.bsky.feed.post/a", cid: oldCID, prev: oldCID)]), previous, current, .repositoryDeltaMismatch),
      (valid.replacing(ops: [.init(action: .update, path: "app.bsky.feed.post/a", cid: newCID, prev: newCID)]), previous, current, .repositoryDeltaMismatch),
      (valid.replacing(ops: []), previous, current, .repositoryDeltaMismatch),
    ]
    for (event, before, after, expected) in cases {
      XCTAssertThrowsError(try RelayCommitSemanticVerifier.verify(
        event: event, previous: before, current: after
      )) {
        XCTAssertEqual($0 as? RelayVerifierError, expected)
      }
    }
  }

  func testGetRepoModesFailClosedAndNeverCallFullSnapshotsDiffs() throws {
    XCTAssertEqual(
      try RelayGetRepoPolicy.verify(.init(mode: .cursorOnly)),
      .cursorOnly
    )
    XCTAssertEqual(
      try RelayGetRepoPolicy.verify(.init(mode: .sinceRejected)),
      .sinceRejected
    )
    XCTAssertThrowsError(try RelayGetRepoPolicy.verify(.init(
      mode: .sinceObserved,
      fullSnapshotAccepted: false,
      exactFinalStateProven: true
    ))) {
      XCTAssertEqual($0 as? RelayVerifierError, .sinceObservedNotProven)
    }
    XCTAssertThrowsError(try RelayGetRepoPolicy.verify(.init(
      mode: .sinceObserved,
      fullSnapshotAccepted: true,
      exactFinalStateProven: false
    ))) {
      XCTAssertEqual($0 as? RelayVerifierError, .sinceObservedNotProven)
    }
    XCTAssertEqual(
      try RelayGetRepoPolicy.verify(.init(
        mode: .sinceObserved,
        fullSnapshotAccepted: true,
        exactFinalStateProven: true
      )),
      .sinceObserved
    )
    XCTAssertEqual(RelayRepositoryPayloadKind.fullSnapshot.isDiff, false)
    XCTAssertEqual(RelayRepositoryPayloadKind.commitDiff.isDiff, true)
  }

  func testFullRepositoryVerifierChecksCARSignatureRootAndExactInputLimit() async throws {
    let key = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    let genesis = try PublicRepositoryGenesisCodec.create(
      did: did,
      revision: rev0,
      signingKey: key
    )
    let verifier = P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
    let expected = RelayRepositoryHead(
      did: did,
      revision: rev0,
      commitCID: genesis.commitCID,
      dataCID: genesis.emptyMSTCID
    )
    let storage = InMemoryRelayAcceptedHeadStorage()
    let verified = try await RelayFullRepositoryVerifier.verify(
      car: genesis.car,
      expected: expected,
      verifier: verifier,
      storage: storage,
      maximumCARBytes: genesis.car.count
    )
    XCTAssertEqual(verified.head, expected)
    XCTAssertEqual(verified.records, [:])
    let inspected = try await RelayFullRepositoryVerifier.inspect(car: genesis.car)
    XCTAssertEqual(inspected.head, expected)
    XCTAssertEqual(inspected.records, [:])
    XCTAssertEqual(inspected.mstDigest, verified.snapshot.mstDigest)

    await assertAsyncError(.repositoryCARTooLarge) {
      _ = try await RelayFullRepositoryVerifier.verify(
        car: genesis.car,
        expected: expected,
        verifier: verifier,
        storage: InMemoryRelayAcceptedHeadStorage(),
        maximumCARBytes: genesis.car.count - 1
      )
    }
    var malformed = genesis.car
    malformed.removeLast()
    await assertAsyncError(.invalidRepositoryCAR) {
      _ = try await RelayFullRepositoryVerifier.verify(
        car: malformed,
        expected: expected,
        verifier: verifier,
        storage: InMemoryRelayAcceptedHeadStorage(),
        maximumCARBytes: genesis.car.count
      )
    }
    let wrongKey = P256PublicRepositoryCommitVerifier(
      publicKey: P256.Signing.PrivateKey().publicKey
    )
    await assertAsyncError(.invalidCommitSignature) {
      _ = try await RelayFullRepositoryVerifier.verify(
        car: genesis.car,
        expected: expected,
        verifier: wrongKey,
        storage: InMemoryRelayAcceptedHeadStorage(),
        maximumCARBytes: genesis.car.count
      )
    }
    await assertAsyncError(.commitCIDMismatch) {
      _ = try await RelayFullRepositoryVerifier.verify(
        car: genesis.car,
        expected: .init(
          did: did, revision: rev0,
          commitCID: sampleCID(77), dataCID: genesis.emptyMSTCID
        ),
        verifier: verifier,
        storage: InMemoryRelayAcceptedHeadStorage(),
        maximumCARBytes: genesis.car.count
      )
    }
  }

  func testRepositoryChainVerifierAuthenticatesDiffCARAndExactMSTProjectionDelta() async throws {
    let key = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    let verifier = P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
    let genesis = try PublicRepositoryGenesisCodec.create(
      did: did,
      revision: rev0,
      signingKey: key
    )
    let initialHead = RelayRepositoryHead(
      did: did,
      revision: rev0,
      commitCID: genesis.commitCID,
      dataCID: genesis.emptyMSTCID
    )
    let storage424 = InMemoryRelayAcceptedHeadStorage()
    let initial = try await RelayRepositoryVerificationState.fullSnapshot(
      car: genesis.car,
      expected: initialHead,
      verifier: verifier,
      storage: storage424,
      maximumCARBytes: genesis.car.count
    )
    let path = try PublicRepositoryPath(
      collection: "app.bsky.feed.post",
      recordKey: "a"
    )
    let record = try PublicRepositoryRecordCodec.prepare(
      PublicRecord(["$type": .string(path.collection), "text": .string("hello")]),
      for: path
    )
    let tree = try await RepositoryMST.empty().adding(path: path, recordCID: record.cid)
    let materialized = try await tree.materialized()
    let commit = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: rev1,
      dataCID: materialized.rootCID,
      currentRevision: rev0,
      signer: P256PublicRepositoryCommitSigner(privateKey: key)
    )
    var blocks = [PublicRepositoryBlock(cid: commit.commitCID, bytes: commit.signedCommitBytes)]
    for cid in materialized.newBlocks.cids {
      let blockBytes = try await materialized.newBlocks.block(for: cid)
      blocks.append(.init(
        cid: cid,
        bytes: try XCTUnwrap(blockBytes)
      ))
    }
    blocks.append(.init(cid: record.cid, bytes: record.bytes))
    let sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(
      rootCID: commit.commitCID,
      blocks: TestCARBlockStream(blocks),
      to: sink
    )
    let diffCAR = await sink.data
    let event = RelayCommitEvent(
      seq: 4,
      repo: did,
      commitCID: commit.commitCID,
      rev: rev1,
      since: rev0,
      blocks: diffCAR,
      ops: [.init(action: .create, path: path.mstKey, cid: record.cid, prev: nil)],
      prevDataCID: genesis.emptyMSTCID,
      time: time
    )
    let current = try await initial.applying(commit: event, verifier: verifier, storage: storage424)
    XCTAssertEqual(current.snapshot.commitCID, commit.commitCID)
    XCTAssertEqual(current.snapshot.dataCID, materialized.rootCID)
    XCTAssertEqual(current.snapshot.records, [path.mstKey: record.cid])
  }

  func testIncrementalCommitAcceptsReusedRecordBlockOmittedFromDiff() async throws {
    let key = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    let verifier = P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
    let genesis = try PublicRepositoryGenesisCodec.create(
      did: did,
      revision: rev0,
      signingKey: key
    )
    let storage490 = InMemoryRelayAcceptedHeadStorage()
    var state = try await RelayRepositoryVerificationState.fullSnapshot(
      car: genesis.car,
      expected: .init(did: did, revision: rev0, commitCID: genesis.commitCID, dataCID: genesis.emptyMSTCID),
      verifier: verifier,
      storage: storage490,
      maximumCARBytes: genesis.car.count
    )
    let pathA = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "a")
    let pathB = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "b")
    let recordA = try PublicRepositoryRecordCodec.prepare(
      PublicRecord(["$type": .string(pathA.collection), "text": .string("shared")]),
      for: pathA
    )

    // Commit 1: Create pathA with recordA
    var tree = try await RepositoryMST.empty().adding(path: pathA, recordCID: recordA.cid)
    var mat = try await tree.materialized()
    var commit = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: "3jzfcijpj2z2b",
      dataCID: mat.rootCID,
      currentRevision: rev0,
      signer: P256PublicRepositoryCommitSigner(privateKey: key)
    )
    var diffBlocks = [PublicRepositoryBlock(cid: commit.commitCID, bytes: commit.signedCommitBytes)]
    for cid in mat.newBlocks.cids {
      let blockBytes = try await mat.newBlocks.block(for: cid)
      diffBlocks.append(.init(cid: cid, bytes: try XCTUnwrap(blockBytes)))
    }
    diffBlocks.append(.init(cid: recordA.cid, bytes: recordA.bytes))
    var sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: commit.commitCID, blocks: TestCARBlockStream(diffBlocks), to: sink)
    var event = RelayCommitEvent(
      seq: 4, repo: did, commitCID: commit.commitCID, rev: "3jzfcijpj2z2b", since: rev0,
      blocks: await sink.data,
      ops: [.init(action: .create, path: pathA.mstKey, cid: recordA.cid, prev: nil)],
      prevDataCID: genesis.emptyMSTCID, time: time
    )
    state = try await state.applying(commit: event, verifier: verifier, storage: storage490)

    // Commit 2: Create pathB pointing to same recordA.cid, but OMITS recordA.bytes from diffBlocks!
    let prevDataCID1 = mat.rootCID
    tree = try await tree.adding(path: pathB, recordCID: recordA.cid)
    mat = try await tree.materialized()
    commit = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: "3jzfcijpj2z2c",
      dataCID: mat.rootCID,
      currentRevision: "3jzfcijpj2z2b",
      signer: P256PublicRepositoryCommitSigner(privateKey: key)
    )
    diffBlocks = [PublicRepositoryBlock(cid: commit.commitCID, bytes: commit.signedCommitBytes)]
    for cid in mat.newBlocks.cids {
      let blockBytes = try await mat.newBlocks.block(for: cid)
      diffBlocks.append(.init(cid: cid, bytes: try XCTUnwrap(blockBytes)))
    }
    // NOTE: recordA.bytes is NOT in diffBlocks! It is reused from previous state.
    sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: commit.commitCID, blocks: TestCARBlockStream(diffBlocks), to: sink)
    event = RelayCommitEvent(
      seq: 5, repo: did, commitCID: commit.commitCID, rev: "3jzfcijpj2z2c", since: "3jzfcijpj2z2b",
      blocks: await sink.data,
      ops: [.init(action: .create, path: pathB.mstKey, cid: recordA.cid, prev: nil)],
      prevDataCID: prevDataCID1, time: time
    )
    state = try await state.applying(commit: event, verifier: verifier, storage: storage490)
    XCTAssertEqual(state.snapshot.records, [
      pathA.mstKey: recordA.cid,
      pathB.mstKey: recordA.cid,
    ])
  }
  func testRollbackAndStaleCommitRejection() async throws {
    let key1 = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    let verifier1 = P256PublicRepositoryCommitVerifier(publicKey: key1.publicKey)
    let genesis1 = try PublicRepositoryGenesisCodec.create(
      did: did,
      revision: rev0,
      signingKey: key1
    )
    let storage = InMemoryRelayAcceptedHeadStorage()
    var state1 = try await RelayRepositoryVerificationState.fullSnapshot(
      car: genesis1.car,
      expected: .init(did: did, revision: rev0, commitCID: genesis1.commitCID, dataCID: genesis1.emptyMSTCID),
      verifier: verifier1,
      storage: storage,
      maximumCARBytes: genesis1.car.count
    )

    let pathA = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "a")
    let recordA = try PublicRepositoryRecordCodec.prepare(
      PublicRecord(["$type": .string(pathA.collection), "text": .string("first")]),
      for: pathA
    )
    let tree1 = try await RepositoryMST.empty().adding(path: pathA, recordCID: recordA.cid)
    let mat1 = try await tree1.materialized()
    let commit1 = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: "3jzfcijpj2z2b",
      dataCID: mat1.rootCID,
      currentRevision: rev0,
      signer: P256PublicRepositoryCommitSigner(privateKey: key1)
    )
    var diffBlocks1 = [PublicRepositoryBlock(cid: commit1.commitCID, bytes: commit1.signedCommitBytes)]
    for cid in mat1.newBlocks.cids {
      let blockBytes = try await mat1.newBlocks.block(for: cid)
      diffBlocks1.append(.init(cid: cid, bytes: try XCTUnwrap(blockBytes)))
    }
    diffBlocks1.append(.init(cid: recordA.cid, bytes: recordA.bytes))
    var sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: commit1.commitCID, blocks: TestCARBlockStream(diffBlocks1), to: sink)
    let event1 = RelayCommitEvent(
      seq: 4, repo: did, commitCID: commit1.commitCID, rev: "3jzfcijpj2z2b", since: rev0,
      blocks: await sink.data,
      ops: [.init(action: .create, path: pathA.mstKey, cid: recordA.cid, prev: nil)],
      prevDataCID: genesis1.emptyMSTCID, time: time
    )
    state1 = try await state1.applying(commit: event1, verifier: verifier1, storage: storage)
    XCTAssertEqual(state1.snapshot.revision, "3jzfcijpj2z2b")

    // Commit 2: revision rev2 ("3jzfcijpj2z2c")
    let pathB = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "b")
    let recordB = try PublicRepositoryRecordCodec.prepare(
      PublicRecord(["$type": .string(pathB.collection), "text": .string("second")]),
      for: pathB
    )
    let tree2 = try await tree1.adding(path: pathB, recordCID: recordB.cid)
    let mat2 = try await tree2.materialized()
    let commit2 = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: "3jzfcijpj2z2c",
      dataCID: mat2.rootCID,
      currentRevision: "3jzfcijpj2z2b",
      signer: P256PublicRepositoryCommitSigner(privateKey: key1)
    )
    var diffBlocks2 = [PublicRepositoryBlock(cid: commit2.commitCID, bytes: commit2.signedCommitBytes)]
    for cid in mat2.newBlocks.cids {
      let blockBytes = try await mat2.newBlocks.block(for: cid)
      diffBlocks2.append(.init(cid: cid, bytes: try XCTUnwrap(blockBytes)))
    }
    diffBlocks2.append(.init(cid: recordB.cid, bytes: recordB.bytes))
    sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: commit2.commitCID, blocks: TestCARBlockStream(diffBlocks2), to: sink)
    let event2 = RelayCommitEvent(
      seq: 5, repo: did, commitCID: commit2.commitCID, rev: "3jzfcijpj2z2c", since: "3jzfcijpj2z2b",
      blocks: await sink.data,
      ops: [.init(action: .create, path: pathB.mstKey, cid: recordB.cid, prev: nil)],
      prevDataCID: mat1.rootCID, time: time
    )
    state1 = try await state1.applying(commit: event2, verifier: verifier1, storage: storage)
    XCTAssertEqual(state1.snapshot.revision, "3jzfcijpj2z2c")

    // Case 1: Replay older valid signed commit1 (rev1 < rev2) -> reject with revisionRollback
    await assertAsyncError(.revisionRollback) {
      _ = try await state1.applying(commit: event1, verifier: verifier1, storage: storage)
    }

    // Case 2: Replay equal valid signed commit2 (rev2 == rev2) -> reject with revisionRollback
    await assertAsyncError(.revisionRollback) {
      _ = try await state1.applying(commit: event2, verifier: verifier1, storage: storage)
    }

    // Case 3: Reverse delta with older/equal revision -> reject with revisionRollback
    let reverseCommit = try await PublicRepositoryCommitCodec.prepare(
      did: did,
      revision: "3jzfcijpj2z2b",
      dataCID: mat1.rootCID,
      currentRevision: rev0,
      signer: P256PublicRepositoryCommitSigner(privateKey: key1)
    )
    let reverseBlocks = [PublicRepositoryBlock(cid: reverseCommit.commitCID, bytes: reverseCommit.signedCommitBytes)]
    sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: reverseCommit.commitCID, blocks: TestCARBlockStream(reverseBlocks), to: sink)
    let reverseEvent = RelayCommitEvent(
      seq: 6, repo: did, commitCID: reverseCommit.commitCID, rev: "3jzfcijpj2z2b", since: "3jzfcijpj2z2c",
      blocks: await sink.data,
      ops: [.init(action: .delete, path: pathB.mstKey, cid: nil, prev: recordB.cid)],
      prevDataCID: mat2.rootCID, time: time
    )
    await assertAsyncError(.revisionRollback) {
      _ = try await state1.applying(commit: reverseEvent, verifier: verifier1, storage: storage)
    }

    // Case 4: Process restart (fresh state, same persistent storage) -> rejects stale commit1
    let restartedState = try await RelayRepositoryVerificationState.fullSnapshot(
      car: genesis1.car,
      expected: .init(did: did, revision: rev0, commitCID: genesis1.commitCID, dataCID: genesis1.emptyMSTCID),
      verifier: verifier1,
      storage: InMemoryRelayAcceptedHeadStorage(),
      maximumCARBytes: genesis1.car.count
    )
    await assertAsyncError(.revisionRollback) {
      _ = try await restartedState.applying(commit: event1, verifier: verifier1, storage: storage)
    }

    // Case 5: Two DIDs isolation
    let did2 = "did:plc:otheruser12345678901234"
    let key2 = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 2, count: 32))
    let verifier2 = P256PublicRepositoryCommitVerifier(publicKey: key2.publicKey)
    let genesis2 = try PublicRepositoryGenesisCodec.create(
      did: did2,
      revision: rev0,
      signingKey: key2
    )
    var state2 = try await RelayRepositoryVerificationState.fullSnapshot(
      car: genesis2.car,
      expected: .init(did: did2, revision: rev0, commitCID: genesis2.commitCID, dataCID: genesis2.emptyMSTCID),
      verifier: verifier2,
      storage: storage,
      maximumCARBytes: genesis2.car.count
    )
    // DID 2 can advance to rev1 ("3jzfcijpj2z2b") because DID 2's accepted head is rev0
    let commit2_did2 = try await PublicRepositoryCommitCodec.prepare(
      did: did2,
      revision: "3jzfcijpj2z2b",
      dataCID: mat1.rootCID,
      currentRevision: rev0,
      signer: P256PublicRepositoryCommitSigner(privateKey: key2)
    )
    var diffBlocks2_did2 = [PublicRepositoryBlock(cid: commit2_did2.commitCID, bytes: commit2_did2.signedCommitBytes)]
    for cid in mat1.newBlocks.cids {
      let blockBytes = try await mat1.newBlocks.block(for: cid)
      diffBlocks2_did2.append(.init(cid: cid, bytes: try XCTUnwrap(blockBytes)))
    }
    diffBlocks2_did2.append(.init(cid: recordA.cid, bytes: recordA.bytes))
    sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(rootCID: commit2_did2.commitCID, blocks: TestCARBlockStream(diffBlocks2_did2), to: sink)
    let event2_did2 = RelayCommitEvent(
      seq: 7, repo: did2, commitCID: commit2_did2.commitCID, rev: "3jzfcijpj2z2b", since: rev0,
      blocks: await sink.data,
      ops: [.init(action: .create, path: pathA.mstKey, cid: recordA.cid, prev: nil)],
      prevDataCID: genesis2.emptyMSTCID, time: time
    )
    state2 = try await state2.applying(commit: event2_did2, verifier: verifier2, storage: storage)
    XCTAssertEqual(state2.snapshot.revision, "3jzfcijpj2z2b")

    // Case 6: Storage failure fails closed
    let failingStorage = FailingRelayAcceptedHeadStorage()
    await assertAsyncError(.storageFailure) {
      _ = try await state1.applying(commit: event1, verifier: verifier1, storage: failingStorage)
    }
  }

  func testFrameBudgetLimitsAndChargeBeforeAllocation() throws {
    // 5,000,001 bytes frame -> frameTooLarge
    let overLimitFrame = Data(repeating: 0, count: FirehoseFrameLimits.maximumFrameBytes + 1)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(overLimitFrame)) {
      XCTAssertEqual($0 as? RelayVerifierError, .frameTooLarge)
    }

    // 5,000,000 bytes frame -> accepting boundary (does not throw frameTooLarge)
    // Construct a valid info frame of exactly 5,000,000 bytes
    let exactFrame = infoFrame(exactByteCount: FirehoseFrameLimits.maximumFrameBytes)
    XCTAssertEqual(exactFrame.count, FirehoseFrameLimits.maximumFrameBytes)
    XCTAssertNoThrow(try RelayFrameDecoder.decode(exactFrame))

    // Compact million-count array in body with trailing bytes: major type 4 (0x80 | 26 = 0x9a), count 1,000,000 = 0x000f4240, with 5 trailing bytes
    // Pre-fix decoder passed count <= 1_000_000 and allocated ~1M elements before failing on truncated element.
    // Post-fix charge-before-allocation check (argument <= remainingBytes) must reject immediately with truncatedFrame before allocation.
    let validHeader = encode(.map([("op", .unsigned(1)), ("t", .text("#identity"))]))
    let compactMillionArrayBody: [UInt8] = [0x9a, 0x00, 0x0f, 0x42, 0x40, 0x01, 0x02, 0x03, 0x04, 0x05] // array of 1,000,000 with 5 trailing bytes
    let attackFrame1 = validHeader + Data(compactMillionArrayBody)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(attackFrame1)) {
      XCTAssertEqual($0 as? RelayVerifierError, .truncatedFrame)
    }

    // Truncated input: array claiming 10 elements with 0 bytes remaining
    let truncatedArrayBody: [UInt8] = [0x8a] // array(10), 0 remaining bytes
    let attackFrame2 = validHeader + Data(truncatedArrayBody)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(attackFrame2)) {
      XCTAssertEqual($0 as? RelayVerifierError, .truncatedFrame)
    }

    // Depth 64 (accepting boundary) vs Depth 65 (rejection boundary)
    var depth64Bytes = [UInt8]()
    for _ in 0 ..< 64 { depth64Bytes.append(0x81) }
    depth64Bytes.append(0x00)
    var depth64Reader = CanonicalRelayCBORReader(Data(depth64Bytes))
    XCTAssertNoThrow(try depth64Reader.read())

    var depth65Bytes = [UInt8]()
    for _ in 0 ..< 65 { depth65Bytes.append(0x81) }
    depth65Bytes.append(0x00)
    var depth65Reader = CanonicalRelayCBORReader(Data(depth65Bytes))
    XCTAssertThrowsError(try depth65Reader.read()) {
      XCTAssertEqual($0 as? RelayCBORReaderError, .invalid)
    }
    let attackFrameDepth65 = validHeader + Data(depth65Bytes)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(attackFrameDepth65)) {
      XCTAssertEqual($0 as? RelayVerifierError, .invalidCBOR)
    }

    // Aggregate node limit: 10,000 aggregate nodes (accepting boundary) vs 10,001 (rejection boundary)
    // Array of 9,999 1-byte integers = 1 root array node + 9,999 item nodes = 10,000 nodes
    var nodes10000 = [UInt8]()
    nodes10000.append(contentsOf: [0x99, 0x27, 0x0f]) // array(9999) in CBOR
    nodes10000.append(contentsOf: repeatElement(UInt8(0x00), count: 9999))
    var reader10000 = CanonicalRelayCBORReader(Data(nodes10000))
    XCTAssertNoThrow(try reader10000.read())

    // 1 root array node + 10,000 item nodes = 10,001 nodes (rejection boundary)
    var nodes10001 = [UInt8]()
    nodes10001.append(contentsOf: [0x99, 0x27, 0x10]) // array(10000) in CBOR
    nodes10001.append(contentsOf: repeatElement(UInt8(0x00), count: 10000))
    var reader10001 = CanonicalRelayCBORReader(Data(nodes10001))
    XCTAssertThrowsError(try reader10001.read()) {
      XCTAssertEqual($0 as? RelayCBORReaderError, .invalid)
    }
    let attackFrameNodes10001 = validHeader + Data(nodes10001)
    XCTAssertThrowsError(try RelayFrameDecoder.decode(attackFrameNodes10001)) {
      XCTAssertEqual($0 as? RelayVerifierError, .invalidCBOR)
    }
  }

  func testSyncVerifierTreatsCommitOnlyCARAsAnnouncementNotDiffOrSnapshot() async throws {
    let key = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 1, count: 32))
    let verifier = P256PublicRepositoryCommitVerifier(publicKey: key.publicKey)
    let genesis = try PublicRepositoryGenesisCodec.create(
      did: did,
      revision: rev0,
      signingKey: key
    )
    let sink = TestCARSink()
    _ = try await PublicRepositoryCAR.write(
      rootCID: genesis.commitCID,
      blocks: TestCARBlockStream([
        .init(cid: genesis.commitCID, bytes: genesis.signedCommit),
      ]),
      to: sink
    )
    let commitOnly = await sink.data
    let sync = RelaySyncEvent(
      seq: 3,
      did: did,
      blocks: commitOnly,
      rev: rev0,
      time: time
    )
    let syncStorage = InMemoryRelayAcceptedHeadStorage()
    let activated = try await RelayRepositoryVerificationState.activationSync(
      sync,
      verifier: verifier,
      storage: syncStorage
    )
    XCTAssertEqual(activated.payloadKind, .commitAnnouncement)
    XCTAssertFalse(activated.payloadKind.isDiff)
    XCTAssertEqual(activated.snapshot.records, [:])
    let manual = try await activated.synchronizing(sync, verifier: verifier, storage: syncStorage)
    XCTAssertEqual(manual.snapshot, activated.snapshot)
    XCTAssertEqual(manual.payloadKind, .commitAnnouncement)

    // Replaying an older sync event against the populated syncStorage (where rev0 is accepted) must fail with revisionRollback
    let olderSync = RelaySyncEvent(
      seq: 2,
      did: did,
      blocks: commitOnly,
      rev: "3jzfaaaaaaa2a",
      time: time
    )
    await assertAsyncError(.revisionRollback) {
      _ = try await activated.synchronizing(olderSync, verifier: verifier, storage: syncStorage)
    }
  }

  func testConcurrentInterleavedApplyingCannotRegressAcceptedHead() async throws {
    let storage = InMemoryRelayAcceptedHeadStorage()
    let head1 = RelayRepositoryHead(did: did, revision: rev1, commitCID: sampleCID(1), dataCID: sampleCID(2))
    let head2 = RelayRepositoryHead(did: did, revision: rev2, commitCID: sampleCID(3), dataCID: sampleCID(4))

    // First, head2 (newer revision) is saved
    try await storage.saveAcceptedHead(head2)
    let current = try await storage.loadAcceptedHead(for: did)
    XCTAssertEqual(current?.revision, rev2)

    // A racing stale task attempting to save head1 (older revision) must be rejected with revisionRollback
    await assertAsyncError(.revisionRollback) {
      try await storage.saveAcceptedHead(head1)
    }

    // Persisted head remains head2
    let afterRace = try await storage.loadAcceptedHead(for: did)
    XCTAssertEqual(afterRace?.revision, rev2)
  }

  func testFinalStateComparisonRejectsRevisionCommitDataProjectionAndMSTMutations() throws {
    let relay = snapshot(
      rev: rev1,
      commit: sampleCID(1),
      data: sampleCID(2),
      records: ["app.bsky.feed.post/a": sampleCID(3)],
      mstDigest: "mst-a"
    )
    XCTAssertNoThrow(try RelayFinalStateVerifier.verify(relay: relay, swan: relay))
    let cases: [(RelayRepositorySnapshot, RelayVerifierError)] = [
      (relay.replacing(revision: rev0), .finalRevisionMismatch),
      (relay.replacing(commitCID: sampleCID(4)), .finalCommitCIDMismatch),
      (relay.replacing(dataCID: sampleCID(5)), .finalDataCIDMismatch),
      (relay.replacing(records: [:]), .finalProjectionMismatch),
      (relay.replacing(mstDigest: "mst-b"), .finalMSTMismatch),
    ]
    for (swan, expected) in cases {
      XCTAssertThrowsError(try RelayFinalStateVerifier.verify(relay: relay, swan: swan)) {
        XCTAssertEqual($0 as? RelayVerifierError, expected)
      }
    }
  }

  func testAggregateJSONContainsOnlyTypedOutcomesDigestsAndIdentifiers() throws {
    let aggregate = RelayVerificationAggregate(
      did: did,
      firstSequence: 1,
      lastSequence: 8,
      frameCount: 8,
      finalRevision: rev1,
      finalCommitCID: sampleCID(1).string,
      finalDataCID: sampleCID(2).string,
      projectionDigest: "sha256:abc",
      checks: [
        .init(name: .canonicalFrames, outcome: .passed),
        .init(name: .finalMSTEquality, outcome: .passed),
      ]
    )
    let encoded = try JSONEncoder().encode(aggregate)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertNil(object["frames"])
    XCTAssertNil(object["car"])
    XCTAssertNil(object["records"])
    XCTAssertNil(object["token"])
    XCTAssertNil(object["proof"])
    XCTAssertEqual(object["did"] as? String, did)
  }

  // MARK: - Independent frame fixtures

  private func identityFrame(
    seq: Int64,
    headerType: String = "#identity",
    headerOp: Int64 = 1,
    extraBodyEntry: (String, TestCBOR)? = nil
  ) -> Data {
    var body: [(String, TestCBOR)] = [
      ("seq", integer(seq)),
      ("did", .text(did)),
      ("time", .text(time)),
      ("handle", .text("alice.test")),
    ]
    if let extraBodyEntry { body.append(extraBodyEntry) }
    return frame(
      header: [("op", integer(headerOp)), ("t", .text(headerType))],
      body: body
    )
  }

  private func nonCanonicalIdentityFrame() -> Data {
    let header = encode(.map([("t", .text("#identity")), ("op", .unsigned(1))]))
    var body = encode(.map([
      ("did", .text(did)),
      ("seq", .unsigned(1)),
      ("time", .text(time)),
      ("handle", .text("alice.test")),
    ]))
    let index = body.firstIndex(of: 0x01)!
    body.replaceSubrange(index ... index, with: [0x18, 0x01])
    return header + body
  }

  private func nonCanonicalHeaderOrderIdentityFrame() -> Data {
    var header = argument(major: 5, value: 2)
    header.append(encode(.text("op")))
    header.append(encode(.unsigned(1)))
    header.append(encode(.text("t")))
    header.append(encode(.text("#identity")))
    let canonical = identityFrame(seq: 1)
    let canonicalHeaderCount = encode(.map([
      ("op", .unsigned(1)), ("t", .text("#identity")),
    ])).count
    return header + canonical.dropFirst(canonicalHeaderCount)
  }

  private func infoFrame(exactByteCount: Int) -> Data {
    var nameByteCount = max(1, exactByteCount - 64)
    for _ in 0 ..< 4 {
      let candidate = frame(
        header: [("op", .unsigned(1)), ("t", .text("#info"))],
        body: [("name", .text(String(repeating: "a", count: nameByteCount)))]
      )
      if candidate.count == exactByteCount { return candidate }
      nameByteCount += exactByteCount - candidate.count
    }
    return Data()
  }

  private func accountFrame(seq: Int64, active: Bool, status: String?) -> Data {
    var body: [(String, TestCBOR)] = [
      ("seq", integer(seq)), ("did", .text(did)), ("time", .text(time)),
      ("active", .boolean(active)),
    ]
    if let status { body.append(("status", .text(status))) }
    return frame(
      header: [("op", .unsigned(1)), ("t", .text("#account"))],
      body: body
    )
  }

  private func syncFrame(seq: Int64, blocks: Data) -> Data {
    frame(
      header: [("op", .unsigned(1)), ("t", .text("#sync"))],
      body: [
        ("seq", integer(seq)), ("did", .text(did)), ("blocks", .bytes(blocks)),
        ("rev", .text(rev0)), ("time", .text(time)),
      ]
    )
  }

  private struct TestOp {
    let action: String
    let path: String
    let cid: CID?
    let prev: CID?
  }

  private func commitFrame(
    seq: Int64,
    commitCID: CID,
    blocks: Data,
    ops: [TestOp]
  ) -> Data {
    commitFrame(
      seq: seq,
      commitCIDValue: link(commitCID),
      blocks: blocks,
      ops: ops
    )
  }

  private func commitFrame(
    seq: Int64,
    commitCIDValue: TestCBOR,
    blocks: Data,
    ops: [TestOp]
  ) -> Data {
    let opValues: [TestCBOR] = ops.map { op in
      var entries: [(String, TestCBOR)] = [
        ("cid", op.cid.map(link) ?? .null),
        ("path", .text(op.path)),
        ("action", .text(op.action)),
      ]
      if let prev = op.prev { entries.append(("prev", link(prev))) }
      return .map(entries)
    }
    return frame(
      header: [("op", .unsigned(1)), ("t", .text("#commit"))],
      body: [
        ("seq", integer(seq)), ("rebase", .boolean(false)),
        ("tooBig", .boolean(false)), ("repo", .text(did)),
        ("commit", commitCIDValue), ("rev", .text(rev1)),
        ("since", .text(rev0)), ("blocks", .bytes(blocks)),
        ("ops", .array(opValues)), ("blobs", .array([])),
        ("prevData", link(sampleCID(0))), ("time", .text(time)),
      ]
    )
  }

  private func frame(
    header: [(String, TestCBOR)],
    body: [(String, TestCBOR)]
  ) -> Data {
    encode(.map(header)) + encode(.map(body))
  }

  private indirect enum TestCBOR {
    case unsigned(UInt64)
    case negative(Int64)
    case text(String)
    case bytes(Data)
    case boolean(Bool)
    case null
    case array([TestCBOR])
    case map([(String, TestCBOR)])
    case tag(UInt64, TestCBOR)
  }

  private func integer(_ value: Int64) -> TestCBOR {
    value >= 0 ? .unsigned(UInt64(value)) : .negative(value)
  }

  private func link(_ cid: CID) -> TestCBOR {
    .tag(42, .bytes(Data([0]) + cid.bytes))
  }

  private func encode(_ value: TestCBOR) -> Data {
    switch value {
    case let .unsigned(value): return argument(major: 0, value: value)
    case let .negative(value): return argument(major: 1, value: UInt64(-1 - value))
    case let .text(value):
      let bytes = Data(value.utf8)
      return argument(major: 3, value: UInt64(bytes.count)) + bytes
    case let .bytes(value):
      return argument(major: 2, value: UInt64(value.count)) + value
    case let .boolean(value): return Data([value ? 0xf5 : 0xf4])
    case .null: return Data([0xf6])
    case let .array(values):
      return values.reduce(into: argument(major: 4, value: UInt64(values.count))) {
        $0.append(encode($1))
      }
    case let .map(entries):
      let sorted = entries.sorted {
        let left = Data($0.0.utf8)
        let right = Data($1.0.utf8)
        return left.count == right.count
          ? left.lexicographicallyPrecedes(right)
          : left.count < right.count
      }
      return sorted.reduce(into: argument(major: 5, value: UInt64(sorted.count))) {
        $0.append(encode(.text($1.0)))
        $0.append(encode($1.1))
      }
    case let .tag(tag, wrapped):
      return argument(major: 6, value: tag) + encode(wrapped)
    }
  }

  private func argument(major: UInt8, value: UInt64) -> Data {
    let prefix = major << 5
    switch value {
    case 0 ... 23: return Data([prefix | UInt8(value)])
    case 24 ... UInt64(UInt8.max): return Data([prefix | 24, UInt8(value)])
    case 256 ... UInt64(UInt16.max):
      return Data([
        prefix | 25,
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value),
      ])
    case 65_536 ... UInt64(UInt32.max):
      return Data([prefix | 26]) + bigEndian(value, count: 4)
    default: return Data([prefix | 27]) + bigEndian(value, count: 8)
    }
  }

  private func bigEndian(_ value: UInt64, count: Int) -> Data {
    Data((0 ..< count).map {
      UInt8(truncatingIfNeeded: value >> UInt64((count - $0 - 1) * 8))
    })
  }

  private func sampleCID(_ seed: Int) -> CID {
    CID.fromDAGCBOR(Data([0xa1, 0x61, 0x78, UInt8(truncatingIfNeeded: seed)]))
  }

  private func snapshot(
    rev: String,
    commit: CID,
    data: CID,
    records: [String: CID],
    mstDigest: String = "mst"
  ) -> RelayRepositorySnapshot {
    RelayRepositorySnapshot(
      did: did,
      revision: rev,
      commitCID: commit,
      dataCID: data,
      records: records,
      mstDigest: mstDigest
    )
  }

  private func assertAsyncError(
    _ expected: RelayVerifierError,
    operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      XCTFail("expected \(expected)")
    } catch {
      XCTAssertEqual(error as? RelayVerifierError, expected)
    }
  }
}

private actor TestCARBlockStream: PublicRepositoryCARBlockStream {
  private let blocks: [PublicRepositoryBlock]
  private var index = 0

  init(_ blocks: [PublicRepositoryBlock]) {
    self.blocks = blocks
  }

  func nextBlock() async throws -> PublicRepositoryBlock? {
    guard index < blocks.count else { return nil }
    defer { index += 1 }
    return blocks[index]
  }
}

private actor TestCARSink: PublicRepositoryCARByteSink {
  private(set) var data = Data()

  func write(_ bytes: Data) async throws {
    data.append(bytes)
  }
}

private extension RelayCommitEvent {
  func replacing(
    repo: String? = nil,
    commitCID: CID? = nil,
    rev: String? = nil,
    since: String?? = nil,
    ops: [RelayRepoOp]? = nil,
    prevDataCID: CID?? = nil
  ) -> RelayCommitEvent {
    RelayCommitEvent(
      seq: seq,
      repo: repo ?? self.repo,
      commitCID: commitCID ?? self.commitCID,
      rev: rev ?? self.rev,
      since: since ?? self.since,
      blocks: blocks,
      ops: ops ?? self.ops,
      prevDataCID: prevDataCID ?? self.prevDataCID,
      time: time
    )
  }
}

private extension RelayRepositorySnapshot {
  func replacing(
    revision: String? = nil,
    commitCID: CID? = nil,
    dataCID: CID? = nil,
    records: [String: CID]? = nil,
    mstDigest: String? = nil
  ) -> RelayRepositorySnapshot {
    RelayRepositorySnapshot(
      did: did,
      revision: revision ?? self.revision,
      commitCID: commitCID ?? self.commitCID,
      dataCID: dataCID ?? self.dataCID,
      records: records ?? self.records,
      mstDigest: mstDigest ?? self.mstDigest
    )
  }
}

private actor FailingRelayAcceptedHeadStorage: RelayAcceptedHeadStorage {
  struct Boom: Error, Equatable {}
  func loadAcceptedHead(for did: String) async throws -> RelayRepositoryHead? { throw Boom() }
  func saveAcceptedHead(_ head: RelayRepositoryHead) async throws { throw Boom() }
}
