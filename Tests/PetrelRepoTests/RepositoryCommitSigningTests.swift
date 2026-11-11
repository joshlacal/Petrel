import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// Commit signing and verification on both blessed curves, the nullable
/// `prev` field, and the legacy version-2 layout.
@Suite("Commit signing and verification")
struct RepositoryCommitSigningTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let revision = "3jzfcijpj2z2a"
    private let dataCID = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)

    private func keypairs() throws -> [any ATProtoKeypair] {
        [
            try K256Keypair(rawRepresentation: Data(repeating: 7, count: 32)),
            try P256Keypair(rawRepresentation: Data(repeating: 7, count: 32)),
        ]
    }

    @Test("a commit signed on either curve verifies against its public key")
    func signAndVerifyBothCurves() async throws {
        for keypair in try keypairs() {
            let prepared = try await PublicRepositoryCommitCodec.prepare(
                did: did, revision: revision, dataCID: dataCID, signer: keypair
            )
            #expect(prepared.signature.count == 64)
            #expect(prepared.signingAlgorithm.curve == keypair.curve)
            #expect(ATProtoSignature.isCanonical(prepared.signature, curve: keypair.curve))
            #expect(prepared.commitCID == CID.fromDAGCBOR(prepared.signedCommitBytes))

            let verified = try PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: prepared.commitCID,
                publicKey: keypair.publicKey
            )
            #expect(verified.descriptor == prepared.descriptor)
            #expect(verified.unsignedCommitBytes == prepared.unsignedCommitBytes)
            #expect(verified.signingAlgorithm.curve == keypair.curve)

            // The protocol-typed verifier and the did:key initializer agree.
            let viaProtocol = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: prepared.commitCID,
                verifier: try ATProtoRepositoryCommitVerifier(didKey: keypair.publicKey.didKey)
            )
            #expect(viaProtocol.commitCID == prepared.commitCID)
        }
    }

    @Test("a commit does not verify against another key, on the same or the other curve")
    func wrongKeyIsRefused() async throws {
        let all = try keypairs()
        let others: [any ATProtoKeypair] = [K256Keypair.generate(), P256Keypair.generate()]
        for keypair in all {
            let prepared = try await PublicRepositoryCommitCodec.prepare(
                did: did, revision: revision, dataCID: dataCID, signer: keypair
            )
            for wrong in others + all where wrong.publicKey != keypair.publicKey {
                #expect(throws: PublicRepositoryCommitError.invalidSignature) {
                    try PublicRepositoryCommitCodec.verify(
                        signedCommitBytes: prepared.signedCommitBytes,
                        expectedCommitCID: prepared.commitCID,
                        publicKey: wrong.publicKey
                    )
                }
            }
        }
    }

    /// Rebuilds a signed commit around a different signature, using only
    /// the public codec's pieces: the canonical key order puts `sig` third.
    private func resigned(_ prepared: PreparedPublicRepositorySignedCommit, signature: Data) throws -> Data {
        let original = prepared.signedCommitBytes
        let range = try #require(original.range(of: prepared.signature))
        var bytes = original
        bytes.replaceSubrange(range, with: signature)
        return bytes
    }

    @Test("the high-S form of a valid signature is refused on both curves")
    func highSIsRefused() async throws {
        // Group orders, big-endian.
        let orders: [ATProtoKeyCurve: [UInt8]] = [
            .k256: [
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
                0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b, 0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41,
            ],
            .p256: [
                0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84, 0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
            ],
        ]
        for keypair in try keypairs() {
            let prepared = try await PublicRepositoryCommitCodec.prepare(
                did: did, revision: revision, dataCID: dataCID, signer: keypair
            )
            // s' = n - s is the same signature mathematically, but not low-S.
            let order = try #require(orders[keypair.curve])
            let s = Array(prepared.signature.suffix(32))
            var flipped = [UInt8](repeating: 0, count: 32)
            var borrow = 0
            for index in stride(from: 31, through: 0, by: -1) {
                var difference = Int(order[index]) - Int(s[index]) - borrow
                borrow = difference < 0 ? 1 : 0
                if difference < 0 { difference += 256 }
                flipped[index] = UInt8(difference)
            }
            let highS = Data(prepared.signature.prefix(32)) + Data(flipped)
            #expect(!ATProtoSignature.isLowS(highS, curve: keypair.curve))
            // The malleable form really is a valid ECDSA signature; it is
            // refused because of its encoding.
            #expect(keypair.publicKey.isValidSignature(
                highS, for: prepared.unsignedCommitBytes, options: .allowMalleable
            ))
            let bytes = try resigned(prepared, signature: highS)
            #expect(throws: PublicRepositoryCommitError.invalidSignature) {
                try PublicRepositoryCommitCodec.verify(
                    signedCommitBytes: bytes,
                    expectedCommitCID: CID.fromDAGCBOR(bytes),
                    publicKey: keypair.publicKey
                )
            }
        }
    }

    @Test("a commit is bound to its CID, its DID and every signed field")
    func tamperingIsRefused() async throws {
        let keypair = try K256Keypair(rawRepresentation: Data(repeating: 7, count: 32))
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: revision, dataCID: dataCID, signer: keypair
        )
        #expect(throws: PublicRepositoryCommitError.invalidCommitCID) {
            try PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: dataCID,
                publicKey: keypair.publicKey
            )
        }
        // Flip one character of the revision: still a valid commit shape,
        // no longer what was signed.
        var tampered = prepared.signedCommitBytes
        let revisionRange = try #require(tampered.range(of: Data(revision.utf8)))
        tampered[revisionRange.lowerBound + 12] = UInt8(ascii: "b")
        #expect(throws: PublicRepositoryCommitError.invalidSignature) {
            try PublicRepositoryCommitCodec.verify(
                signedCommitBytes: tampered,
                expectedCommitCID: CID.fromDAGCBOR(tampered),
                publicKey: keypair.publicKey
            )
        }
    }

    // MARK: Key resolution

    private actor RotatingResolver: RepositorySigningKeyResolver {
        let stale: ATProtoPublicKey
        let current: ATProtoPublicKey
        private(set) var calls: [Bool] = []

        init(stale: ATProtoPublicKey, current: ATProtoPublicKey) {
            self.stale = stale
            self.current = current
        }

        func signingKey(for _: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
            calls.append(forceRefresh)
            return forceRefresh ? current : stale
        }
    }

    private struct FailingResolver: RepositorySigningKeyResolver {
        struct Offline: Error {}
        func signingKey(for _: String, forceRefresh _: Bool) async throws -> ATProtoPublicKey {
            throw Offline()
        }
    }

    @Test("a stale cached key is refreshed exactly once before a commit is refused")
    func resolverRefreshesOnce() async throws {
        let keypair = K256Keypair.generate()
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: revision, dataCID: dataCID, signer: keypair
        )
        let rotating = RotatingResolver(
            stale: K256Keypair.generate().publicKey, current: keypair.publicKey
        )
        _ = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: prepared.signedCommitBytes,
            expectedCommitCID: prepared.commitCID,
            keyResolver: rotating
        )
        #expect(await rotating.calls == [false, true])

        // When the refreshed key does not verify either, the commit is
        // invalid, after exactly two lookups.
        let neverRight = RotatingResolver(
            stale: K256Keypair.generate().publicKey, current: P256Keypair.generate().publicKey
        )
        await #expect(throws: PublicRepositoryCommitError.invalidSignature) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: prepared.commitCID,
                keyResolver: neverRight
            )
        }
        #expect(await neverRight.calls == [false, true])

        await #expect(throws: PublicRepositoryCommitError.signingKeyUnavailable) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: prepared.commitCID,
                keyResolver: FailingResolver()
            )
        }
        await #expect(throws: PublicRepositoryCommitError.invalidDID) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: prepared.signedCommitBytes,
                expectedCommitCID: prepared.commitCID,
                keyResolver: FixedRepositorySigningKey(keypair.publicKey),
                expectedDID: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
            )
        }
    }

    // MARK: prev and version 2

    /// Encodes a commit map from its fields in canonical key order, by hand,
    /// so these tests do not depend on the codec's own encoder.
    private func commitBytes(
        version: UInt8, revision: String?, previous: CID?, signature: Data?
    ) -> Data {
        func text(_ value: String) -> [UInt8] {
            let utf8 = Array(value.utf8)
            precondition(utf8.count < 256)
            return (utf8.count < 24 ? [0x60 + UInt8(utf8.count)] : [0x78, UInt8(utf8.count)]) + utf8
        }
        func link(_ cid: CID) -> [UInt8] {
            [0xd8, 0x2a, 0x58, 0x25, 0x00] + Array(cid.bytes)
        }
        var count: UInt8 = 4
        var body: [UInt8] = text("did") + text(did)
        if let revision {
            count += 1
            body += text("rev") + text(revision)
        }
        if let signature {
            count += 1
            body += text("sig") + [0x58, UInt8(signature.count)] + Array(signature)
        }
        body += text("data") + link(dataCID)
        body += text("prev") + (previous.map(link) ?? [0xf6])
        body += text("version") + [version]
        return Data([0xa0 + count] + body)
    }

    @Test("a version-3 commit with a non-null prev verifies and survives a re-encode")
    func nonNullPrevious() async throws {
        let previous = CID.fromDAGCBOR(Data("an earlier commit".utf8))
        for keypair in try keypairs() {
            let unsigned = commitBytes(version: 3, revision: revision, previous: previous, signature: nil)
            let signature = try await keypair.sign(unsigned)
            let signed = commitBytes(version: 3, revision: revision, previous: previous, signature: signature)
            let cid = CID.fromDAGCBOR(signed)

            let verified = try PublicRepositoryCommitCodec.verify(
                signedCommitBytes: signed, expectedCommitCID: cid, publicKey: keypair.publicKey
            )
            #expect(verified.descriptor.previousCommitCID == previous)
            // The codec's own re-encoding of what it parsed is the input.
            #expect(verified.unsignedCommitBytes == unsigned)
            #expect(verified.signedCommitBytes == signed)

            let structural = try PublicRepositoryCommitCodec.structurallyValidate(
                signedCommitBytes: signed, expectedCommitCID: cid
            )
            #expect(structural.descriptor.previousCommitCID == previous)

            // The link is signed: the same signature over a null prev fails.
            let nulled = commitBytes(version: 3, revision: revision, previous: nil, signature: signature)
            #expect(throws: PublicRepositoryCommitError.invalidSignature) {
                try PublicRepositoryCommitCodec.verify(
                    signedCommitBytes: nulled,
                    expectedCommitCID: CID.fromDAGCBOR(nulled),
                    publicKey: keypair.publicKey
                )
            }
        }
    }

    @Test("prev must be a blessed commit CID when present")
    func previousMustBeBlessed() throws {
        // A raw-codec CID in `prev`.
        let raw = CID.fromBlob(Data("blob".utf8))
        let signed = commitBytes(
            version: 3, revision: revision, previous: raw, signature: Data(repeating: 1, count: 64)
        )
        #expect(throws: PublicRepositoryCommitError.invalidPreviousCommitCID) {
            try PublicRepositoryCommitCodec.structurallyValidate(
                signedCommitBytes: signed, expectedCommitCID: CID.fromDAGCBOR(signed)
            )
        }
        #expect(throws: PublicRepositoryCommitError.invalidPreviousCommitCID) {
            try PublicRepositoryCommitDescriptor(
                did: did, revision: revision, dataCID: dataCID, previousCommitCID: raw
            )
        }
    }

    @Test("version-2 commits are readable, with and without rev, and never mistaken for version 3")
    func legacyVersion2() async throws {
        let keypair: any ATProtoKeypair = try K256Keypair(rawRepresentation: Data(repeating: 9, count: 32))
        let previous = CID.fromDAGCBOR(Data("an earlier commit".utf8))
        for legacyRevision in [revision, nil] as [String?] {
            let unsigned = commitBytes(version: 2, revision: legacyRevision, previous: previous, signature: nil)
            let signature = try await keypair.sign(unsigned)
            let signed = commitBytes(version: 2, revision: legacyRevision, previous: previous, signature: signature)
            let cid = CID.fromDAGCBOR(signed)

            #expect(try PublicRepositoryCommitCodec.commitVersion(ofSignedCommitBytes: signed) == 2)
            let decoded = try PublicRepositoryCommitCodec.decodeLegacyV2(
                signedCommitBytes: signed, expectedCommitCID: cid
            )
            #expect(decoded.did == did)
            #expect(decoded.revision == legacyRevision)
            #expect(decoded.dataCID == dataCID)
            #expect(decoded.previousCommitCID == previous)
            #expect(decoded.unsignedCommitBytes == unsigned)
            #expect(!decoded.isSignatureVerified)

            let verified = try PublicRepositoryCommitCodec.verifyLegacyV2(
                signedCommitBytes: signed, expectedCommitCID: cid, publicKey: keypair.publicKey
            )
            #expect(verified.isSignatureVerified)
            #expect(throws: PublicRepositoryCommitError.invalidSignature) {
                try PublicRepositoryCommitCodec.verifyLegacyV2(
                    signedCommitBytes: signed,
                    expectedCommitCID: cid,
                    publicKey: K256Keypair.generate().publicKey
                )
            }
            // The version-3 entry points refuse it by name.
            #expect(throws: PublicRepositoryCommitError.unsupportedVersion) {
                try PublicRepositoryCommitCodec.verify(
                    signedCommitBytes: signed, expectedCommitCID: cid, publicKey: keypair.publicKey
                )
            }
        }

        // And a version-3 commit is not a version-2 commit.
        let v3 = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: revision, dataCID: dataCID, signer: keypair
        )
        #expect(try PublicRepositoryCommitCodec.commitVersion(ofSignedCommitBytes: v3.signedCommitBytes) == 3)
        #expect(throws: PublicRepositoryCommitError.unsupportedVersion) {
            try PublicRepositoryCommitCodec.decodeLegacyV2(
                signedCommitBytes: v3.signedCommitBytes, expectedCommitCID: v3.commitCID
            )
        }
        // Version 3 requires `rev`; version 4 does not exist.
        let withoutRevision = commitBytes(
            version: 3, revision: nil, previous: nil, signature: Data(repeating: 1, count: 64)
        )
        #expect(throws: PublicRepositoryCommitError.invalidSchema) {
            try PublicRepositoryCommitCodec.commitVersion(ofSignedCommitBytes: withoutRevision)
        }
        let version4 = commitBytes(
            version: 4, revision: revision, previous: nil, signature: Data(repeating: 1, count: 64)
        )
        #expect(throws: PublicRepositoryCommitError.unsupportedVersion) {
            try PublicRepositoryCommitCodec.commitVersion(ofSignedCommitBytes: version4)
        }
    }

    @Test("an external signer (KMS, HSM) signs commits through the same path")
    func externalSigner() async throws {
        let backing = K256Keypair.generate()
        let external = ATProtoExternalSigner(publicKey: backing.publicKey) { request in
            try backing.sign(request.message)
        }
        let prepared = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: revision, dataCID: dataCID, signer: external
        )
        _ = try PublicRepositoryCommitCodec.verify(
            signedCommitBytes: prepared.signedCommitBytes,
            expectedCommitCID: prepared.commitCID,
            publicKey: backing.publicKey
        )
    }

    @Test("the two-block genesis archive is created and verified on both curves")
    func genesisOnBothCurves() async throws {
        for keypair in try keypairs() {
            let genesis = try await PublicRepositoryGenesisCodec.create(
                did: did, revision: revision, signer: keypair
            )
            let verified = try PublicRepositoryGenesisCodec.verify(car: genesis.car, publicKey: keypair.publicKey)
            #expect(verified == genesis)
            #expect(throws: PublicRepositoryGenesisError.invalidSignature) {
                try PublicRepositoryGenesisCodec.verify(
                    car: genesis.car, publicKey: K256Keypair.generate().publicKey
                )
            }
            // It is an ordinary repository archive.
            let repository = try await Repository.open(
                car: genesis.car, verification: .signingKey(keypair.publicKey), expectedDID: did
            )
            #expect(repository.commit.cid == genesis.commitCID)
            #expect(repository.statistics?.recordCount == 0)
        }
    }
}
