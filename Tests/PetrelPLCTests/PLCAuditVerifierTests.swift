import Foundation
import PetrelCrypto
@testable import PetrelPLC
import Testing

/// Chain verification against logs built here with K-256 and P-256 keys.
/// Real-world logs are covered by `PLCCorpusTests`; these tests reach the
/// branches the public directory rarely exhibits: recovery, the 72-hour
/// window, and everything that must be refused.
@Suite("PLC audit log verification")
struct PLCAuditVerifierTests {
    /// Rotation keys in descending authority: a K-256 key, then a P-256 key.
    let high = K256Keypair.generate()
    let low = P256Keypair.generate()
    let outsider = K256Keypair.generate()

    private func genesis(rotationKeys: [String]? = nil) async throws -> (did: String, operation: PLCSignedOperation) {
        let unsigned = try PLCATProfile.genesisOperation(
            handle: "alice.example.com",
            signingKey: K256Keypair.generate().didKey,
            rotationKeys: rotationKeys ?? [high.didKey, low.didKey],
            pdsEndpoint: "https://pds.example.com"
        )
        let operation = try await PLCOperationCodec.sign(.regular(unsigned), with: high)
        return try (PLCOperationCodec.genesisDID(for: operation), operation)
    }

    private func update(
        after previous: PLCSignedOperation,
        pds: String,
        signer: any ATProtoSigner
    ) async throws -> PLCSignedOperation {
        try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.updatePDS(after: previous, endpoint: pds)), with: signer
        )
    }

    private func tombstone(
        after previous: PLCSignedOperation,
        signer: any ATProtoSigner
    ) async throws -> PLCSignedOperation {
        try await PLCOperationCodec.sign(.tombstone(PLCOperationCodec.tombstone(after: previous)), with: signer)
    }

    private func hour(_ offset: Double) -> String {
        // 2026-03-01T00:00:00.000Z
        plcTestTimestamp(milliseconds: 1_772_323_200_000 + Int64(offset * 3_600_000))
    }

    @Test("a linear log signed alternately with K-256 and P-256 keys verifies")
    func linearLogBothCurves() async throws {
        let (did, first) = try await genesis()
        let second = try await update(after: first, pds: "https://two.example.com", signer: low)
        let third = try await update(after: second, pds: "https://three.example.com", signer: high)
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (second, hour(1)), (third, hour(2))]),
            did: did
        )
        #expect(log.entries.map(\.nullified) == [false, false, false])
        #expect(log.signers == [high.didKey, low.didKey, high.didKey])
        #expect(try log.head.cid == third.cid.string)
        #expect(log.documentData?.pdsEndpoint == "https://three.example.com")
        #expect(!log.isTombstoned)
        #expect(try PLCAuditLogVerifier.validateOperationLog([first, second, third], did: did) == log.documentData)
    }

    @Test("a higher-authority key nullifies a lower-authority operation within 72 hours")
    func recovery() async throws {
        let (did, first) = try await genesis()
        let hijack = try await update(after: first, pds: "https://attacker.example.com", signer: low)
        let hijackFollowUp = try await update(after: hijack, pds: "https://attacker2.example.com", signer: low)
        let recovery = try await update(after: first, pds: "https://recovered.example.com", signer: high)

        // The directory's flags are claims; here they are all false.
        let log = try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [
            (first, hour(0)), (hijack, hour(1)), (hijackFollowUp, hour(2)), (recovery, hour(73)),
        ]), did: did)
        // Both operations after the fork point are nullified, not just one.
        #expect(log.entries.map(\.nullified) == [false, true, true, false])
        #expect(log.activeEntries.count == 2)
        #expect(try log.head.cid == recovery.cid.string)
        #expect(log.documentData?.pdsEndpoint == "https://recovered.example.com")
        #expect(log.signers == [high.didKey, low.didKey, low.didKey, high.didKey])
    }

    @Test("the 72-hour window is measured from the first displaced operation and is inclusive")
    func recoveryWindow() async throws {
        let (did, first) = try await genesis()
        let disputed = try await update(after: first, pds: "https://disputed.example.com", signer: low)
        let recovery = try await update(after: first, pds: "https://recovered.example.com", signer: high)

        // Exactly 72 hours after the disputed operation: accepted.
        let onTime = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (disputed, hour(10)), (recovery, hour(82))]), did: did
        )
        #expect(onTime.entries.map(\.nullified) == [false, true, false])

        // One millisecond later: refused.
        let late = plcTestTimestamp(milliseconds: 1_772_323_200_000 + 82 * 3_600_000 + 1)
        #expect(throws: PetrelPLCError.unauthorized("PLC recovery exceeds the 72-hour window")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (disputed, hour(10)), (recovery, late)]), did: did
            )
        }
    }

    @Test("a lower- or equal-authority key cannot nullify")
    func recoveryNeedsHigherAuthority() async throws {
        let (did, first) = try await genesis()
        let byHigh = try await update(after: first, pds: "https://high.example.com", signer: high)
        let byLow = try await update(after: first, pds: "https://low.example.com", signer: low)
        let byHighAgain = try await update(after: first, pds: "https://again.example.com", signer: high)
        let byLowAgain = try await update(after: first, pds: "https://low-again.example.com", signer: low)

        // Low tries to displace high.
        #expect(throws: PetrelPLCError.unauthorized("PLC recovery cannot supersede an equal-authority operation")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (byHigh, hour(1)), (byLow, hour(2))]), did: did
            )
        }
        // High tries to displace its own earlier operation.
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (byHigh, hour(1)), (byHighAgain, hour(2))]), did: did
            )
        }
        // Low tries to displace its own earlier operation.
        #expect(throws: PetrelPLCError.unauthorized("PLC operation signature is invalid")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (byLow, hour(1)), (byLowAgain, hour(2))]), did: did
            )
        }
    }

    @Test("prev must name an operation that is still valid")
    func prevMustBeActive() async throws {
        let (did, first) = try await genesis()
        let (_, unrelated) = try await genesis()
        let disputed = try await update(after: first, pds: "https://disputed.example.com", signer: low)
        let recovery = try await update(after: first, pds: "https://recovered.example.com", signer: high)

        // prev → an operation that is not in this log at all.
        let dangling = try await update(after: unrelated, pds: "https://dangling.example.com", signer: high)
        #expect(throws: PetrelPLCError.unauthorized("PLC audit operation prev is not active")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (dangling, hour(1))]), did: did
            )
        }

        // prev → an operation that has been nullified.
        let onNullified = try await update(after: disputed, pds: "https://stale.example.com", signer: high)
        #expect(throws: PetrelPLCError.unauthorized("PLC audit operation prev is not active")) {
            try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [
                (first, hour(0)), (disputed, hour(1)), (recovery, hour(2)), (onNullified, hour(3)),
            ]), did: did)
        }

        // A second genesis operation in the same log.
        #expect(throws: PetrelPLCError.unauthorized("PLC audit contains multiple genesis operations")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (unrelated, hour(1))]), did: did
            )
        }

        // A log that does not start with the genesis of this DID.
        #expect(throws: PetrelPLCError.unauthorized("PLC genesis DID does not match operation")) {
            try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [(unrelated, hour(0))]), did: did)
        }
        #expect(throws: PetrelPLCError.unauthorized("PLC audit does not start with genesis")) {
            try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [(disputed, hour(0))]), did: did)
        }
    }

    @Test("an operation must be signed by a rotation key of its predecessor")
    func signerMustBeAuthorized() async throws {
        let (did, first) = try await genesis()
        let rotated = try await PLCOperationCodec.sign(.regular(
            PLCOperationCodec.updateRotationKeys(after: first, rotationKeys: [low.didKey])
        ), with: high)
        // `high` was removed by `rotated`, so it can no longer sign.
        let stale = try await update(after: rotated, pds: "https://stale.example.com", signer: high)
        #expect(throws: PetrelPLCError.unauthorized("PLC operation signature is invalid")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (rotated, hour(1)), (stale, hour(2))]), did: did
            )
        }
        // The key that is now listed can.
        let current = try await update(after: rotated, pds: "https://current.example.com", signer: low)
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (rotated, hour(1)), (current, hour(2))]), did: did
        )
        #expect(log.documentData?.rotationKeys == [low.didKey])
        // A key that was never listed cannot.
        let foreign = try await update(after: first, pds: "https://foreign.example.com", signer: outsider)
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(plcAuditEntries(did: did, [(first, hour(0)), (foreign, hour(1))]), did: did)
        }
    }

    @Test("a tombstone ends the log, and nothing may follow it")
    func tombstones() async throws {
        let (did, first) = try await genesis()
        let dead = try await tombstone(after: first, signer: low)
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (dead, hour(1))]), did: did
        )
        #expect(log.isTombstoned)
        #expect(log.documentData == nil)
        #expect(log.entries.map(\.nullified) == [false, false])
        #expect(try PLCAuditLogVerifier.validateOperationLog([first, dead], did: did) == nil)

        // An operation whose prev is the tombstone. It cannot be built with
        // the update helpers, so assemble it by hand.
        let afterDeath = try await PLCOperationCodec.sign(.regular(PLCUnsignedRegularOperation(
            rotationKeys: [high.didKey],
            verificationMethods: [:],
            alsoKnownAs: [],
            services: [:],
            prev: dead.cid.string
        )), with: high)
        #expect(throws: PetrelPLCError.unauthorized("PLC audit operation follows a tombstone")) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (dead, hour(1)), (afterDeath, hour(2))]), did: did
            )
        }
        #expect(throws: PetrelPLCError.unauthorized("PLC operation follows a tombstone")) {
            try PLCAuditLogVerifier.validateOperationLog([first, dead, afterDeath], did: did)
        }
        #expect(throws: PetrelPLCError.tombstoned(did: did)) {
            try log.verifyNextOperation(afterDeath)
        }
    }

    @Test("a tombstone by a lower-authority key can be nullified by a recovery")
    func tombstoneRecovered() async throws {
        let (did, first) = try await genesis()
        let dead = try await tombstone(after: first, signer: low)
        let recovery = try await update(after: first, pds: "https://alive.example.com", signer: high)
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (dead, hour(1)), (recovery, hour(48))]), did: did
        )
        #expect(log.entries.map(\.nullified) == [false, true, false])
        #expect(!log.isTombstoned)
        #expect(log.documentData?.pdsEndpoint == "https://alive.example.com")

        // A tombstone by the highest-authority key cannot be undone.
        let final = try await tombstone(after: first, signer: high)
        let attempt = try await update(after: first, pds: "https://undo.example.com", signer: high)
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(first, hour(0)), (final, hour(1)), (attempt, hour(2))]), did: did
            )
        }
    }

    @Test("rotation keys listed twice are read, and authority follows the first position")
    func duplicateRotationKeysInHistory() async throws {
        // Such an operation cannot be built through the write path, so make
        // the JSON by hand and sign its bytes.
        let signingKey = K256Keypair.generate().didKey
        func json(sig: String?) throws -> [String: Any] {
            var object: [String: Any] = [
                "type": "plc_operation",
                "rotationKeys": [low.didKey, high.didKey, low.didKey],
                "verificationMethods": ["atproto": signingKey],
                "alsoKnownAs": ["at://alice.example.com"],
                "services": [String: Any](),
                "prev": NSNull(),
            ]
            object["sig"] = sig
            return object
        }
        // Sign the DAG-CBOR of the object without `sig`. A placeholder
        // signature lets the codec produce those bytes.
        let placeholder = try JWTBase64URL.encode(high.sign(Data("placeholder".utf8)))
        let draft = try PLCOperationCodec.decodeSigned(jsonObject: json(sig: placeholder))
        let signature = try JWTBase64URL.encode(high.sign(draft.signingDAGCBOR))
        let genesis = try PLCOperationCodec.decodeSigned(jsonObject: json(sig: signature))
        let did = try PLCOperationCodec.genesisDID(for: genesis)

        #expect(try PLCOperationCodec.verify(genesis, authorizedRotationKeys: genesis.rotationKeys ?? []) == 1)
        // An update is a write, so the duplicate is not carried forward: the
        // draft keeps each key at its first, authoritative, position.
        #expect(
            try PLCOperationCodec.updatePDS(after: genesis, endpoint: "https://low.example.com").rotationKeys
                == [low.didKey, high.didKey]
        )
        func deduplicatingUpdate(pds: String, signer: any ATProtoSigner) async throws -> PLCSignedOperation {
            try await PLCOperationCodec.sign(.regular(PLCOperationCodec.update(after: genesis) { draft in
                draft.rotationKeys = [low.didKey, high.didKey]
                try draft.setPDS(endpoint: pds)
            }), with: signer)
        }
        let byLow = try await deduplicatingUpdate(pds: "https://low.example.com", signer: low)
        // `low` appears at index 0 and 2; its authority is index 0.
        #expect(try PLCOperationCodec.verify(byLow, authorizedRotationKeys: genesis.rotationKeys ?? []) == 0)
        // So `high` (index 1) cannot displace it.
        let byHigh = try await deduplicatingUpdate(pds: "https://high.example.com", signer: high)
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(
                plcAuditEntries(did: did, [(genesis, hour(0)), (byLow, hour(1)), (byHigh, hour(2))]), did: did
            )
        }
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(genesis, hour(0)), (byLow, hour(1))]), did: did
        )
        #expect(log.signers == [high.didKey, low.didKey])
    }

    @Test("log structure: DIDs, CIDs, timestamps and order are checked")
    func structure() async throws {
        let (did, first) = try await genesis()
        let second = try await update(after: first, pds: "https://two.example.com", signer: high)
        let good = try plcAuditEntries(did: did, [(first, hour(0)), (second, hour(1))])
        _ = try PLCAuditLogVerifier.verify(good, did: did)

        func replacing(_ index: Int, _ transform: (PLCAuditEntry) -> PLCAuditEntry) -> [PLCAuditEntry] {
            var copy = good
            copy[index] = transform(copy[index])
            return copy
        }
        // An entry for another DID.
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(replacing(1) {
                PLCAuditEntry(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", operation: $0.operation, cid: $0.cid, nullified: false, createdAt: $0.createdAt)
            }, did: did)
        }
        // A CID that is not the operation's hash.
        #expect(throws: PetrelPLCError.unauthorized("PLC audit operation CID is invalid")) {
            try PLCAuditLogVerifier.verify(replacing(1) {
                PLCAuditEntry(did: $0.did, operation: $0.operation, cid: good[0].cid, nullified: false, createdAt: $0.createdAt)
            }, did: did)
        }
        // A timestamp in another format, and one that goes backwards.
        for createdAt in ["2026-03-01T01:00:00Z", "2026-03-01 01:00:00.000Z", "2026-02-30T01:00:00.000Z", hour(-1)] {
            #expect(throws: PetrelPLCError.malformed("PLC audit entry is malformed"), "\(createdAt)") {
                try PLCAuditLogVerifier.verify(replacing(1) {
                    PLCAuditEntry(did: $0.did, operation: $0.operation, cid: $0.cid, nullified: false, createdAt: createdAt)
                }, did: did)
            }
        }
        // The same operation twice.
        #expect(throws: PetrelPLCError.self) {
            try PLCAuditLogVerifier.verify(good + [good[1]], did: did)
        }
        // An empty log, and a DID that is not a did:plc.
        #expect(throws: PetrelPLCError.self) { try PLCAuditLogVerifier.verify([], did: did) }
        #expect(throws: PetrelPLCError.self) { try PLCAuditLogVerifier.verify(good, did: "did:web:example.com") }

        // validateOperationLog: a broken link.
        let third = try await update(after: second, pds: "https://three.example.com", signer: high)
        #expect(throws: PetrelPLCError.unauthorized("PLC operation prev does not match the log")) {
            try PLCAuditLogVerifier.validateOperationLog([first, third], did: did)
        }
    }

    @Test("verifyNextOperation accepts exactly what the directory would accept next")
    func verifyNextOperation() async throws {
        let (did, first) = try await genesis()
        let second = try await update(after: first, pds: "https://two.example.com", signer: high)
        let log = try PLCAuditLogVerifier.verify(
            plcAuditEntries(did: did, [(first, hour(0)), (second, hour(1))]), did: did
        )
        let next = try await update(after: second, pds: "https://three.example.com", signer: low)
        #expect(try log.verifyNextOperation(next) == 1)

        let fork = try await update(after: first, pds: "https://fork.example.com", signer: high)
        #expect(throws: PetrelPLCError.self) { try log.verifyNextOperation(fork) }
        let foreign = try await update(after: second, pds: "https://foreign.example.com", signer: outsider)
        #expect(throws: PetrelPLCError.unauthorized("PLC operation signature is invalid")) {
            try log.verifyNextOperation(foreign)
        }
    }

    @Test("directory timestamps parse to exact milliseconds")
    func timestamps() {
        #expect(plcTimestampMilliseconds("1970-01-01T00:00:00.000Z") == 0)
        #expect(plcTimestampMilliseconds("2022-11-17T00:35:16.391Z") == 1_668_645_316_391)
        #expect(plcTimestampMilliseconds("2024-02-29T23:59:59.999Z") == 1_709_251_199_999)
        #expect(plcTimestampMilliseconds("2026-03-01T00:00:00.000Z") == 1_772_323_200_000)
        for invalid in [
            "2023-02-29T00:00:00.000Z", "2024-13-01T00:00:00.000Z", "2024-01-01T24:00:00.000Z",
            "2024-01-01T00:60:00.000Z", "2024-01-01T00:00:00.000+00:00", "2024-01-01T00:00:00Z",
            "2024-01-01t00:00:00.000z", "", "２０２４-01-01T00:00:00.000Z",
        ] {
            #expect(plcTimestampMilliseconds(invalid) == nil, "\(invalid)")
        }
        #expect(plcTestTimestamp(milliseconds: 1_668_645_316_391) == "2022-11-17T00:35:16.391Z")
    }
}
