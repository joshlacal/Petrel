import Foundation
import Petrel
import PetrelCrypto
import PetrelPLC
import PetrelPLCPDS
import Testing

/// The code in `Sources/PetrelPLC/PetrelPLC.docc/DirectoryOperations.md`,
/// compiled and run. Each test body is the article's snippet with the
/// client pointed at an in-memory directory; keep the two in step.
@Suite("PetrelPLC documentation examples")
struct PLCDocumentationExampleTests {
    private func directoryWithRealIdentity() async throws -> (PLCDirectoryClient, String) {
        let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        return try (plcTestClient(directory), did)
    }

    private func directoryWithOwnedIdentity() async throws
        -> (client: PLCDirectoryClient, directory: FakePLCDirectory, did: String, rotationKey: K256Keypair) {
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)
        let rotationKey = K256Keypair.generate()
        let created = try await client.createDID(
            handle: "alice.example.com",
            signingKey: K256Keypair.generate().didKey,
            rotationKeys: [rotationKey.didKey],
            pdsEndpoint: "https://pds.example.com",
            signer: rotationKey
        )
        return (client, directory, created.did, rotationKey)
    }

    @Test("Overview: clients for the public directory and for a mirror")
    func overview() throws {
        // `PLCDirectoryClient()` is the same client with the default
        // configuration; constructing it opens no connection.
        let client = try PLCDirectoryClient()
        #expect(client.configuration.origin.absoluteString == "https://plc.directory")

        let mirror = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.org")!)
        )
        #expect(mirror.configuration.origin.absoluteString == "https://plc.example.org")
    }

    @Test("Read a DID's history")
    func readHistory() async throws {
        let (client, did) = try await directoryWithRealIdentity()

        let entries = try await client.getAuditLog(did: did)
        var handles = [String]()
        for entry in entries {
            switch entry.operation {
            case let .regularOperation(operation):
                // rotationKeys, verificationMethods, alsoKnownAs, services, prev
                handles += operation.alsoKnownAs
            case let .legacyCreateOperation(operation):
                // The pre-2023 genesis format: signingKey, recoveryKey, handle, service
                handles.append(operation.handle)
            case .tombstoneOperation:
                // The identity was deactivated here
                break
            }
            _ = (entry.cid, entry.createdAt, entry.nullified)
        }
        #expect(entries.count == 3)
        #expect(handles == ["at://atprotocol.bsky.social", "at://atproto.com", "at://atproto.com"])

        let document = try await client.getDocument(did: did) // GET /:did
        let data = try await client.getDocumentData(did: did) // GET /:did/data
        let operations = try await client.getOperationLog(did: did) // GET /:did/log
        let last = try await client.getLastOperation(did: did) // GET /:did/log/last
        #expect(document.handle == "atproto.com")
        #expect(data.handle == "atproto.com")
        #expect(operations.last == last)

        await #expect(throws: PetrelPLCError.notFound(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")) {
            try await client.getDocument(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")
        }
    }

    @Test("Verify it")
    func verify() async throws {
        let (client, did) = try await directoryWithRealIdentity()
        let entries = try await client.getAuditLog(did: did)

        let log = try PLCAuditLogVerifier.verify(entries, did: did)

        let current = log.head // the operation that defines the identity now
        let state = log.documentData // rotation keys, handle, PDS; nil if tombstoned
        let signers = log.signers // which rotation key signed each operation
        let nullified = log.entries.filter(\.nullified)

        #expect(current.cid == entries.last?.cid)
        #expect(state?.pdsEndpoint == "https://enoki.us-east.host.bsky.network")
        #expect(signers.count == 3)
        #expect(nullified.isEmpty)

        let verified = try await client.fetchVerifiedAuditLog(did: did)
        let provenState = try await client.fetchState(did: did)
        #expect(verified == log)
        #expect(provenState == state)
    }

    @Test("Rotate a key, then make the other updates")
    func rotateKey() async throws {
        let (client, _, did, rotationKey) = try await directoryWithOwnedIdentity()
        let storedPrivateKeyHex = try rotationKey.exportHex()
        let repositoryKey = K256Keypair.generate()

        let currentRotationKey = try K256Keypair(hex: storedPrivateKeyHex)
        let newRotationKey = P256Keypair.generate()

        var rotationKeys = try await client.fetchState(did: did).rotationKeys
        rotationKeys.insert(newRotationKey.didKey, at: 0)

        let operation = try await client.updateRotationKeys(
            did: did,
            signer: currentRotationKey,
            rotationKeys: rotationKeys
        )
        #expect(operation.regular?.rotationKeys == [newRotationKey.didKey, rotationKey.didKey])
        #expect(try await client.fetchState(did: did).rotationKeys.first == newRotationKey.didKey)

        try await client.updateHandle(did: did, signer: newRotationKey, handle: "alice.example.com")
        try await client.updatePDS(did: did, signer: newRotationKey, endpoint: "https://pds.example.com")
        try await client.updateAtprotoKey(did: did, signer: newRotationKey, signingKey: repositoryKey.didKey)
        try await client.update(did: did, signer: newRotationKey) { draft in
            draft.alsoKnownAs.append("https://alice.example.com")
        }
        let state = try await client.fetchState(did: did)
        #expect(state.atprotoSigningKey == repositoryKey.didKey)
        #expect(state.alsoKnownAs == ["at://alice.example.com", "https://alice.example.com"])
    }

    @Test("Recover from an unwanted operation")
    func recover() async throws {
        let (client, _, did, rotationKey) = try await directoryWithOwnedIdentity()
        // The identity has a higher-authority key that stayed offline…
        let newRotationKey = P256Keypair.generate()
        try await client.updateRotationKeys(
            did: did, signer: rotationKey, rotationKeys: [newRotationKey.didKey, rotationKey.didKey]
        )
        // …and the lower-authority key makes an unwanted change.
        try await client.updatePDS(did: did, signer: rotationKey, endpoint: "https://unwanted.example.com")

        let history = try await client.fetchVerifiedAuditLog(did: did)
        let lastGood = history.activeEntries[history.activeEntries.count - 2].operation

        let recovery = try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.update(after: lastGood) { _ in }),
            with: newRotationKey
        )
        try await client.submit(did: did, operation: recovery)

        let after = try await client.fetchVerifiedAuditLog(did: did)
        #expect(after.entries.map(\.nullified) == [false, false, true, false])
        #expect(after.documentData?.pdsEndpoint == "https://pds.example.com")
    }

    @Test("Create and deactivate")
    func createAndDeactivate() async throws {
        let client = try plcTestClient(FakePLCDirectory())

        let repositoryKey = K256Keypair.generate()
        let rotationKey = K256Keypair.generate()

        let created = try await client.createDID(
            handle: "alice.example.com",
            signingKey: repositoryKey.didKey,
            rotationKeys: [rotationKey.didKey],
            pdsEndpoint: "https://pds.example.com",
            signer: rotationKey
        )
        // created.did is derived from the signed genesis operation.
        #expect(try created.did == PLCOperationCodec.genesisDID(for: created.operation))

        try await client.tombstone(did: created.did, signer: rotationKey)
        #expect(try await client.fetchVerifiedAuditLog(did: created.did).isTombstoned)
    }

    @Test("Sign somewhere else")
    func signElsewhere() async throws {
        let (client, _, did, rotationKey) = try await directoryWithOwnedIdentity()
        let current = try await client.fetchVerifiedAuditLog(did: did).head
        let offlineSigner: (Data) throws -> Data = { try rotationKey.sign($0) }

        let unsigned = try PLCUnsignedOperation.regular(
            PLCOperationCodec.updateHandle(after: current.operation, handle: "alice.example.org")
        )
        let bytesToSign = try unsigned.signingDAGCBOR
        let signature = try offlineSigner(bytesToSign) // 64 bytes r || s, low-S
        let signed = try PLCOperationCodec.attach(signature: signature, to: unsigned)
        try await client.submit(did: did, operation: signed)

        #expect(try await client.fetchState(did: did).handle == "alice.example.org")
    }

    @Test("Follow the whole directory")
    func followDirectory() async throws {
        let directory = FakePLCDirectory()
        for did in ["did:plc:ewvi7nxzyoun6zhxrhs64oiz", "did:plc:z72i7hdynmk6r22z27h6tvur"] {
            try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        }
        let client = try plcTestClient(directory)
        var seen = 0

        var cursor = PLCExportCursor.sequence(0)
        for try await entry in client.exportSequence(after: cursor) {
            // entry.did, entry.operation, entry.cid, entry.createdAt, entry.sequence
            cursor = entry.cursor
            seen += 1
        }
        // Reached the newest operation. Resume later from `cursor`.
        #expect(seen == 7)
        #expect(cursor == .sequence(7))
    }

    @Test("PetrelPLCPDS: the flow in the module's landing page")
    func pdsFlow() async throws {
        let (directory, _, did, pdsRotationKey) = try await directoryWithOwnedIdentity()
        let head = try await directory.fetchVerifiedAuditLog(did: did).head.operation
        let pds = DocumentationPDS(rotationKey: pdsRotationKey, head: head)
        let myRecoveryKey = P256Keypair.generate()
        let tokenFromEmail = "token"

        let flow = PLCPDSOperationFlow(api: pds)

        // 1. The PDS emails the account holder a token.
        try await flow.requestSignatureToken()

        // 2. Ask the PDS to sign an operation that puts a key you hold first.
        let current = try await directory.fetchVerifiedAuditLog(did: did)
        let currentKeys = current.documentData?.rotationKeys ?? []
        let operation = try await flow.signOperation(
            token: tokenFromEmail,
            changing: PLCPDSOperationFields(rotationKeys: [myRecoveryKey.didKey] + currentKeys)
        )

        // 3. Check what was signed against the verified log.
        try current.verifyNextOperation(operation)

        // 4. Submit it through the PDS.
        try await flow.submit(operation)

        #expect(operation.regular?.rotationKeys == [myRecoveryKey.didKey, pdsRotationKey.didKey])
        #expect(await pds.submitted == operation)
    }
}

/// The smallest PDS that can play its part in the documented flow.
private actor DocumentationPDS: PLCPDSIdentityAPI {
    let rotationKey: K256Keypair
    let head: PLCSignedOperation
    private(set) var submitted: PLCSignedOperation?

    init(rotationKey: K256Keypair, head: PLCSignedOperation) {
        self.rotationKey = rotationKey
        self.head = head
    }

    func getRecommendedDidCredentials() async throws
        -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        (200, .init())
    }

    func requestPlcOperationSignature() async throws -> Int { 200 }

    func signPlcOperation(
        input: ComAtprotoIdentitySignPlcOperation.Input
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        let unsigned = try PLCOperationCodec.update(after: head) { draft in
            if let rotationKeys = input.rotationKeys { draft.rotationKeys = rotationKeys }
        }
        let signed = try await PLCOperationCodec.sign(.regular(unsigned), with: rotationKey)
        return try (200, .init(operation: PLCPDSBridge.container(for: signed)))
    }

    func submitPlcOperation(input: ComAtprotoIdentitySubmitPlcOperation.Input) async throws -> Int {
        submitted = try PLCPDSBridge.operation(from: input.operation)
        return 200
    }
}
