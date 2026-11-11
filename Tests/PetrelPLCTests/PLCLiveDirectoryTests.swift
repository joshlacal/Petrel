import Foundation
import PetrelPLC
import Testing

/// Read-only checks against the real directory at `https://plc.directory`.
///
/// Disabled unless `PETREL_PLC_LIVE=1`: the test suite does not depend on
/// the network. Only `GET` requests are made; nothing is ever submitted.
@Suite(
    "PLC live directory (read-only)",
    .enabled(if: ProcessInfo.processInfo.environment["PETREL_PLC_LIVE"] == "1")
)
struct PLCLiveDirectoryTests {
    private func client() throws -> PLCDirectoryClient {
        try PLCDirectoryClient(configuration: .production(timeout: 30))
    }

    @Test("every read endpoint answers for a legacy-genesis identity, and the log verifies")
    func readsAndVerifies() async throws {
        let client = try client()
        // support.bsky.team: legacy `create` genesis.
        let did = "did:plc:oc6vwdlmk2kqyida5i74d3p5"

        let document = try await client.getDocument(did: did)
        let data = try await client.getDocumentData(did: did)
        let operations = try await client.getOperationLog(did: did)
        let audit = try await client.getAuditLog(did: did)
        let last = try await client.getLastOperation(did: did)

        #expect(document.id == did)
        #expect(document.handle == data.handle)
        #expect(document.pdsEndpoint == data.pdsEndpoint)
        #expect(operations.first?.legacyCreate != nil)
        #expect(operations.last == last)
        #expect(audit.count >= operations.count)

        let log = try PLCAuditLogVerifier.verify(audit, did: did)
        #expect(log.documentData == data)
        #expect(log.head.operation == last)
        #expect(try PLCAuditLogVerifier.validateOperationLog(operations, did: did) == data)
        #expect(try await client.fetchState(did: did) == data)
    }

    @Test("an unregistered DID is .notFound and a tombstoned one is .tombstoned")
    func typedErrors() async throws {
        let client = try client()
        let unknown = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
        await #expect(throws: PetrelPLCError.notFound(did: unknown)) {
            try await client.getDocument(did: unknown)
        }
        #expect(try await client.fetchAuditIfPresent(did: unknown) == nil)

        let tombstoned = "did:plc:5qepwfemd2p3ts3phpzjvmsi"
        await #expect(throws: PetrelPLCError.tombstoned(did: tombstoned)) {
            try await client.getDocument(did: tombstoned)
        }
        await #expect(throws: PetrelPLCError.tombstoned(did: tombstoned)) {
            try await client.getDocumentData(did: tombstoned)
        }
        #expect(try await client.fetchVerifiedAuditLog(did: tombstoned).isTombstoned)
    }

    @Test("the export pages in both formats and the sequence follows the cursor")
    func export() async throws {
        let client = try client()
        let legacy = try await client.export(count: 5)
        #expect(legacy.count == 5)
        #expect(legacy.allSatisfy { $0.nullified != nil && $0.sequence == nil })

        var sequences = [UInt64]()
        for try await entry in client.exportSequence(after: .sequence(0), pageSize: 100) {
            sequences.append(try #require(entry.sequence))
            if sequences.count == 250 { break }
        }
        #expect(sequences.count == 250)
        #expect(sequences.first == 1)
        #expect(zip(sequences, sequences.dropFirst()).allSatisfy { $0 < $1 })
    }
}
