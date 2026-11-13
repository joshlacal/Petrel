import Foundation
import PetrelCrypto
@testable import PetrelPLC
import Testing

/// The one-call update helpers start from whatever the directory accepted, which is looser than
/// what Petrel writes. They must still work for those identities.
@Suite("PLC updates after read-lenient heads")
struct PLCLenientHeadUpdateTests {
    private static let rotationA = K256Keypair.generate().publicKey.didKey
    private static let rotationB = K256Keypair.generate().publicKey.didKey
    private static let signing = P256Keypair.generate().publicKey.didKey

    /// An operation as the directory serves it, built from JSON so it can break write rules.
    private static func head(rotationKeys: [String], alsoKnownAs: [String]) throws -> PLCSignedOperation {
        let signature = try PLCVectors.exportEntries("export-legacy.jsonl")[0].operation.signature
        return try PLCOperationCodec.decodeSignedJSON(JSONSerialization.data(withJSONObject: [
            "type": "plc_operation",
            "rotationKeys": rotationKeys,
            "verificationMethods": ["atproto": signing],
            "alsoKnownAs": alsoKnownAs,
            "services": ["atproto_pds": ["type": "AtprotoPersonalDataServer", "endpoint": "https://pds.example.com"]],
            "prev": NSNull(),
            "sig": signature,
        ]))
    }

    @Test("a legacy genesis whose recovery key equals its signing key can be updated")
    func legacyEqualKeys() throws {
        // A real legacy `create` from plc.directory whose recoveryKey == signingKey.
        let entry = try PLCVectors.exportEntries("export-legacy.jsonl")[32]
        guard case let .legacyCreateOperation(legacy) = entry.operation else {
            Issue.record("vector 32 is no longer a legacy create")
            return
        }
        #expect(legacy.recoveryKey == legacy.signingKey)

        let update = try PLCOperationCodec.updateHandle(after: entry.operation, handle: "renamed.example.com")
        #expect(update.rotationKeys == [legacy.signingKey])
        #expect(update.alsoKnownAs.first == "at://renamed.example.com")
        let headCID = try entry.operation.cid.string
        #expect(update.prev == headCID)
    }

    @Test("later duplicates of a rotation key are dropped; the first keeps its authority")
    func duplicateRotationKeys() throws {
        let head = try Self.head(
            rotationKeys: [Self.rotationA, Self.rotationB, Self.rotationA],
            alsoKnownAs: ["at://alice.example.com", "at://alice.example.com"]
        )
        let update = try PLCOperationCodec.updatePDS(after: head, endpoint: "https://other.example.com")
        #expect(update.rotationKeys == [Self.rotationA, Self.rotationB])
        #expect(update.alsoKnownAs == ["at://alice.example.com"])
        #expect(update.services["atproto_pds"]?.endpoint == "https://other.example.com")
    }

    @Test("an alias longer than the write limit is refused with an error naming the limit")
    func oversizedAlias() throws {
        let longAlias = "https://example.com/" + String(repeating: "a", count: 2_100)
        let head = try Self.head(rotationKeys: [Self.rotationA], alsoKnownAs: ["at://alice.example.com", longAlias])
        do {
            _ = try PLCOperationCodec.updateHandle(after: head, handle: "bob.example.com")
            Issue.record("expected the oversized alias to be refused")
        } catch let PetrelPLCError.malformed(message) {
            #expect(message.contains("2048"), "\(message)")
            #expect(message.contains("alsoKnownAs"), "\(message)")
        }
    }
}

@Suite("PLC production configuration")
struct PLCProductionLimitsTests {
    @Test("the production configuration refuses locally what plc.directory would refuse")
    func productionDefaultsToReferenceDirectoryLimits() throws {
        #expect(try PLCClientConfiguration.production().operationLimits == .referenceDirectory)
        let custom = try PLCClientConfiguration.production(
            origin: URL(string: "https://plc.example.org")!,
            operationLimits: .specification
        )
        #expect(custom.operationLimits == .specification)
    }
}
