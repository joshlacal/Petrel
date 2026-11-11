import Foundation
import Petrel
import PetrelCrypto
import PetrelPLC
import PetrelPLCPDS
import Testing

/// A PDS that hosts one account and holds its rotation key, speaking the
/// four `com.atproto.identity` procedures the way the reference PDS does.
private actor StubPDS: PLCPDSIdentityAPI {
    let rotationKey: K256Keypair
    private(set) var head: PLCSignedOperation
    private(set) var calls = [String]()
    private(set) var submitted = [PLCSignedOperation]()
    private var issuedToken: String?
    var failingStatus: Int?

    init(rotationKey: K256Keypair, head: PLCSignedOperation) {
        self.rotationKey = rotationKey
        self.head = head
    }

    func fail(with status: Int?) {
        failingStatus = status
    }

    func getRecommendedDidCredentials() async throws
        -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        calls.append("getRecommendedDidCredentials")
        if let failingStatus { return (failingStatus, nil) }
        return (200, .init(
            rotationKeys: [rotationKey.didKey],
            alsoKnownAs: ["at://alice.example.com"],
            verificationMethods: .object(["atproto": .string(rotationKey.didKey)]),
            services: .object(["atproto_pds": .object([
                "type": .string("AtprotoPersonalDataServer"),
                "endpoint": .string("https://new-pds.example.com"),
            ])])
        ))
    }

    func requestPlcOperationSignature() async throws -> Int {
        calls.append("requestPlcOperationSignature")
        if let failingStatus { return failingStatus }
        issuedToken = "ABCDE-12345"
        return 200
    }

    func signPlcOperation(
        input: ComAtprotoIdentitySignPlcOperation.Input
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        calls.append("signPlcOperation")
        if let failingStatus { return (failingStatus, nil) }
        guard let issuedToken, input.token == issuedToken else { return (400, nil) }
        let unsigned = try PLCOperationCodec.update(after: head) { draft in
            if let rotationKeys = input.rotationKeys { draft.rotationKeys = rotationKeys }
            if let alsoKnownAs = input.alsoKnownAs { draft.alsoKnownAs = alsoKnownAs }
            if let methods = input.verificationMethods {
                draft.verificationMethods = try PLCPDSBridge.verificationMethods(methods)
            }
            if let services = input.services {
                draft.services = try PLCPDSBridge.services(services)
            }
        }
        let signed = try await PLCOperationCodec.sign(.regular(unsigned), with: rotationKey)
        // The PDS answers with JSON; go through its wire form.
        let wire = try JSONEncoder().encode(
            ComAtprotoIdentitySignPlcOperation.Output(operation: PLCPDSBridge.container(for: signed))
        )
        return try (200, JSONDecoder().decode(ComAtprotoIdentitySignPlcOperation.Output.self, from: wire))
    }

    func submitPlcOperation(input: ComAtprotoIdentitySubmitPlcOperation.Input) async throws -> Int {
        calls.append("submitPlcOperation")
        if let failingStatus { return failingStatus }
        // Read the operation from the request body as it goes on the wire.
        let wire = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(ComAtprotoIdentitySubmitPlcOperation.Input.self, from: wire)
        let operation = try PLCPDSBridge.operation(from: decoded.operation)
        submitted.append(operation)
        head = operation
        return 200
    }
}

@Suite("PDS-mediated PLC operations")
struct PLCPDSOperationFlowTests {
    private func hostedAccount() async throws -> (did: String, genesis: PLCSignedOperation, pds: StubPDS, recovery: P256Keypair) {
        let pdsKey = K256Keypair.generate()
        let recovery = P256Keypair.generate()
        let unsigned = try PLCATProfile.genesisOperation(
            handle: "alice.example.com",
            signingKey: K256Keypair.generate().didKey,
            rotationKeys: [pdsKey.didKey],
            pdsEndpoint: "https://pds.example.com"
        )
        let genesis = try await PLCOperationCodec.sign(.regular(unsigned), with: pdsKey)
        let did = try PLCOperationCodec.genesisDID(for: genesis)
        return (did, genesis, StubPDS(rotationKey: pdsKey, head: genesis), recovery)
    }

    @Test("request a token, have the PDS sign, verify what it signed, submit")
    func flow() async throws {
        let (did, genesis, pds, recovery) = try await hostedAccount()
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)
        try await client.submit(did: did, operation: genesis)
        let flow = PLCPDSOperationFlow(api: pds)

        // 1. The PDS emails a token.
        try await flow.requestSignatureToken()

        // 2. Ask it to add a recovery key the account holder controls, ahead
        //    of its own.
        let current = try await client.fetchVerifiedAuditLog(did: did)
        let currentKeys = try #require(current.documentData?.rotationKeys)
        let operation = try await flow.signOperation(
            token: "ABCDE-12345",
            changing: PLCPDSOperationFields(rotationKeys: [recovery.didKey] + currentKeys)
        )

        // 3. Verify what came back before it goes anywhere: it follows the
        //    current operation, is signed by a current rotation key, and
        //    changes what was asked and nothing else.
        #expect(try current.verifyNextOperation(operation) == 0)
        let proposed = try #require(operation.documentData(did: did))
        #expect(proposed.rotationKeys == [recovery.didKey] + currentKeys)
        #expect(proposed.alsoKnownAs == current.documentData?.alsoKnownAs)
        #expect(proposed.services == current.documentData?.services)
        #expect(proposed.verificationMethods == current.documentData?.verificationMethods)

        // 4. Submit through the PDS.
        try await flow.submit(operation)
        #expect(await pds.submitted == [operation])
        #expect(await pds.calls == ["requestPlcOperationSignature", "signPlcOperation", "submitPlcOperation"])

        // The same operation is acceptable to the directory itself, and the
        // account holder's key now outranks the PDS's.
        try await client.submit(did: did, operation: operation)
        let after = try await client.fetchState(did: did)
        #expect(after.rotationKeys.first == recovery.didKey)
        try await client.updateHandle(did: did, signer: recovery, handle: "alice.example.org")
    }

    @Test("a wrong token and failing procedures surface as typed errors")
    func failures() async throws {
        let (_, _, pds, _) = try await hostedAccount()
        let flow = PLCPDSOperationFlow(api: pds)
        try await flow.requestSignatureToken()
        await #expect(throws: PLCPDSFlowError.requestFailed(
            procedure: "com.atproto.identity.signPlcOperation", status: 400
        )) {
            try await flow.signOperation(token: "wrong", changing: .init(alsoKnownAs: ["at://x.example.com"]))
        }

        await pds.fail(with: 401)
        await #expect(throws: PLCPDSFlowError.requestFailed(
            procedure: "com.atproto.identity.requestPlcOperationSignature", status: 401
        )) { try await flow.requestSignatureToken() }
        await #expect(throws: PLCPDSFlowError.requestFailed(
            procedure: "com.atproto.identity.getRecommendedDidCredentials", status: 401
        )) { try await flow.recommendedCredentials() }
        let (_, genesis, _, _) = try await hostedAccount()
        await #expect(throws: PLCPDSFlowError.requestFailed(
            procedure: "com.atproto.identity.submitPlcOperation", status: 401
        )) { try await flow.submit(genesis) }
    }

    @Test("recommended credentials are read into typed fields")
    func recommendedCredentials() async throws {
        let (_, _, pds, _) = try await hostedAccount()
        let fields = try await PLCPDSOperationFlow(api: pds).recommendedCredentials()
        #expect(fields.rotationKeys == [pds.rotationKey.didKey])
        #expect(fields.alsoKnownAs == ["at://alice.example.com"])
        #expect(fields.verificationMethods == ["atproto": pds.rotationKey.didKey])
        #expect(fields.services == [
            "atproto_pds": PLCService(type: "AtprotoPersonalDataServer", endpoint: "https://new-pds.example.com"),
        ])
    }

    @Test("operations cross the lexicon's untyped value unchanged, null prev and real operations included")
    func bridge() async throws {
        let (_, genesis, _, _) = try await hostedAccount()
        // prev: null survives.
        let container = try PLCPDSBridge.container(for: genesis)
        guard case let .object(fields) = container, case .null? = fields["prev"] else {
            Issue.record("prev must cross as an explicit null")
            return
        }
        #expect(try PLCPDSBridge.operation(from: container) == genesis)

        // Real operations of every kind: regular, legacy create, tombstone.
        for did in [PLCVectors.Organisation.support, PLCVectors.TestIdentity.tombstoned, PLCVectors.Organisation.moderation] {
            for entry in try PLCAuditLogVerifier.decode(PLCVectors.auditLogJSON(did: did), did: did) {
                let wire = try JSONEncoder().encode(PLCPDSBridge.container(for: entry.operation))
                let decoded = try JSONDecoder().decode(ATProtocolValueContainer.self, from: wire)
                let operation = try PLCPDSBridge.operation(from: decoded)
                #expect(operation == entry.operation)
                #expect(try operation.cid.string == entry.cid)
            }
        }

        // A value that is not an operation is refused.
        #expect(throws: PetrelPLCError.self) {
            try PLCPDSBridge.operation(from: .object(["type": .string("plc_operation"), "prev": .number(1)]))
        }
        #expect(throws: PetrelPLCError.self) { try PLCPDSBridge.operation(from: .string("nope")) }
        #expect(throws: PetrelPLCError.self) { try PLCPDSBridge.services(.object(["x": .string("y")])) }
    }

    @Test("the generated com.atproto.identity namespace is the flow's API")
    func generatedNamespaceConforms() {
        // Compile-time evidence that the flow runs against the generated
        // client as it is.
        func requiresAPI(_: (some PLCPDSIdentityAPI).Type) {}
        requiresAPI(ATProtoClient.Com.Atproto.Identity.self)
    }
}
