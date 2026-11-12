import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCrypto
@testable import PetrelPLC
import Testing

/// Every directory route, driven through `PLCDirectoryClient` against an
/// in-memory directory that answers in the reference server's shapes.
/// Nothing here opens a socket.
@Suite("PLC directory endpoints")
struct PLCDirectoryEndpointTests {
    private func jsonResponse(_ status: Int, _ object: Any, headers: [String: String] = [:]) throws -> PLCHTTPResponse {
        try PLCHTTPResponse(
            status: status,
            headers: ["content-type": "application/json; charset=utf-8"].merging(headers) { $1 },
            body: JSONSerialization.data(withJSONObject: object)
        )
    }

    // MARK: Reads

    @Test("GET /:did, /data, /log, /log/audit and /log/last use the exact routes and decode real logs")
    func readEndpoints() async throws {
        // support.bsky.team: a legacy `create` genesis and three updates.
        let did = PLCVectors.Organisation.support
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        let client = try plcTestClient(directory)

        let document = try await client.getDocument(did: did)
        let data = try await client.getDocumentData(did: did)
        let operations = try await client.getOperationLog(did: did)
        let audit = try await client.getAuditLog(did: did)
        let last = try await client.getLastOperation(did: did)

        let requests = await directory.requests
        #expect(requests.map(\.method) == Array(repeating: .get, count: 5))
        #expect(requests.map(\.url.absoluteString) == [
            "https://plc.test/\(did)",
            "https://plc.test/\(did)/data",
            "https://plc.test/\(did)/log",
            "https://plc.test/\(did)/log/audit",
            "https://plc.test/\(did)/log/last",
        ])
        #expect(requests.allSatisfy { $0.body == nil })
        #expect(requests[0].headers["accept"]?.contains("application/did+ld+json") == true)

        // The document is the rendering of the data.
        #expect(document == PLCDIDDocument(data: data))
        #expect(document.id == did)
        #expect(data.did == did)
        #expect(operations.count == 4)
        #expect(operations.first?.legacyCreate != nil)
        #expect(audit.count == 4)
        #expect(audit.map(\.operation) == operations)
        #expect(last == operations.last)
        #expect(try last.cid.string == audit.last?.cid)

        // The unverified reads agree with the verified ones.
        #expect(try PLCAuditLogVerifier.validateOperationLog(operations, did: did) == data)
        #expect(try await client.fetchState(did: did) == data)
        #expect(try await client.fetchVerifiedAuditLog(did: did).head.operation == last)
        #expect(try await client.fetchAudit(did: did) == audit)
    }

    @Test("an unregistered DID is .notFound on every read route")
    func notRegistered() async throws {
        let did = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
        let client = try plcTestClient(FakePLCDirectory())
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.getDocument(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.getDocumentData(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.getOperationLog(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.getAuditLog(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.getLastOperation(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.fetchAudit(did: did) }
        await #expect(throws: PetrelPLCError.notFound(did: did)) { try await client.fetchState(did: did) }
        #expect(try await client.fetchAuditIfPresent(did: did) == nil)

        // A DID that is not a did:plc never reaches the network.
        let directory = FakePLCDirectory()
        let offline = try plcTestClient(directory)
        await #expect(throws: PetrelPLCError.invalidIdentifier("canonical did:plc")) {
            try await offline.getDocument(did: "did:web:example.com")
        }
        await #expect(throws: PetrelPLCError.self) {
            try await offline.getAuditLog(did: "did:plc:AAAAAAAAAAAAAAAAAAAAAAAA")
        }
        #expect(await directory.requests.isEmpty)
    }

    @Test("a tombstoned DID is .tombstoned for its document and data, and its log is still readable")
    func tombstoned() async throws {
        let did = PLCVectors.TestIdentity.tombstoned
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        let client = try plcTestClient(directory)

        // The reference server answers 404 "DID not available".
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) { try await client.getDocument(did: did) }
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) { try await client.getDocumentData(did: did) }
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) { try await client.fetchState(did: did) }

        #expect(try await client.getLastOperation(did: did).isTombstone)
        #expect(try await client.getOperationLog(did: did).count == 2)
        let log = try await client.fetchVerifiedAuditLog(did: did)
        #expect(log.isTombstoned)

        // 410 Gone means the same thing.
        try await directory.inject(jsonResponse(410, ["message": "gone"]), forPath: "/\(did)")
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) { try await client.getDocument(did: did) }

        // Updating it is refused before anything is signed or sent.
        let before = await directory.postCount
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) {
            try await client.updateHandle(did: did, signer: K256Keypair.generate(), handle: "x.example.com")
        }
        #expect(await directory.postCount == before)
    }

    @Test("error statuses map to typed errors")
    func errorMapping() async throws {
        let did = PLCVectors.Organisation.support
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        let client = try plcTestClient(directory)
        let path = "/\(did)/log/audit"

        try await directory.inject(jsonResponse(429, ["message": "slow down"], headers: ["retry-after": "17"]), forPath: path)
        await #expect(throws: PetrelPLCError.rateLimited(retryAfterSeconds: 17)) { try await client.getAuditLog(did: did) }

        try await directory.inject(jsonResponse(429, ["message": "slow down"]), forPath: path)
        await #expect(throws: PetrelPLCError.rateLimited(retryAfterSeconds: nil)) { try await client.getAuditLog(did: did) }

        try await directory.inject(jsonResponse(400, ["message": "Invalid count parameter"]), forPath: path)
        await #expect(throws: PetrelPLCError.rejected(status: 400, message: "Invalid count parameter")) {
            try await client.getAuditLog(did: did)
        }

        try await directory.inject(jsonResponse(503, ["error": "Service Unavailable"]), forPath: path)
        await #expect(throws: PetrelPLCError.unavailable("PLC directory returned HTTP 503")) {
            try await client.getAuditLog(did: did)
        }

        // A 4xx whose body is not the directory's JSON still maps, with no message.
        await directory.inject(
            PLCHTTPResponse(status: 403, headers: ["content-type": "text/html"], body: Data("<html>".utf8)),
            forPath: path
        )
        await #expect(throws: PetrelPLCError.rejected(status: 403, message: "")) { try await client.getAuditLog(did: did) }

        // Redirects, foreign final URLs and unexpected content types are refused.
        await directory.inject(
            PLCHTTPResponse(status: 200, headers: ["content-type": "application/json"], body: Data("[]".utf8), redirectCount: 1),
            forPath: path
        )
        await #expect(throws: PetrelPLCError.unauthorized("PLC directory redirects are forbidden")) {
            try await client.getAuditLog(did: did)
        }
        await directory.inject(
            PLCHTTPResponse(
                status: 200, headers: ["content-type": "application/json"], body: Data("[]".utf8),
                finalURL: URL(string: "https://evil.example/\(did)/log/audit")
            ),
            forPath: path
        )
        await #expect(throws: PetrelPLCError.unauthorized("PLC directory redirects are forbidden")) {
            try await client.getAuditLog(did: did)
        }
        await directory.inject(
            PLCHTTPResponse(status: 200, headers: ["content-type": "text/html"], body: Data("[]".utf8)),
            forPath: path
        )
        await #expect(throws: PetrelPLCError.malformed("PLC directory response has an unexpected content type")) {
            try await client.getAuditLog(did: did)
        }

        // A log whose signatures do not verify is unauthorized, not malformed.
        var tampered = try #require(
            JSONSerialization.jsonObject(with: PLCVectors.auditLogJSON(did: did)) as? [[String: Any]]
        )
        tampered.remove(at: 1)
        try await directory.inject(jsonResponse(200, tampered), forPath: path)
        await #expect(throws: PetrelPLCError.unauthorized("PLC audit operation prev is not active")) {
            try await client.fetchVerifiedAuditLog(did: did)
        }
        // …and the unverified read returns it as it is.
        try await directory.inject(jsonResponse(200, tampered), forPath: path)
        #expect(try await client.getAuditLog(did: did).count == 3)
    }

    @Test("fetchState refuses data that the verified log does not prove")
    func fetchStateRequiresProof() async throws {
        let did = PLCVectors.Organisation.atprotoCom
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        let client = try plcTestClient(directory)
        let honest = try await client.fetchState(did: did)
        #expect(honest.handle == "atproto.com")

        try await directory.inject(jsonResponse(200, [
            "did": did,
            "rotationKeys": ["did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc"],
            "verificationMethods": honest.verificationMethods,
            "alsoKnownAs": honest.alsoKnownAs,
            "services": honest.services.mapValues { ["type": $0.type, "endpoint": $0.endpoint] },
        ]), forPath: "/\(did)/data")
        await #expect(throws: PetrelPLCError.unauthorized("PLC document data does not match its audit log")) {
            try await client.fetchState(did: did)
        }
    }

    // MARK: Configuration

    @Test("the directory URL is configurable")
    func configurableDirectory() async throws {
        let did = PLCVectors.Organisation.atprotoCom
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))

        #expect(try PLCClientConfiguration.production().origin.absoluteString == "https://plc.directory")
        let mirror = try PLCDirectoryClient(
            configuration: .production(
                origin: URL(string: "https://plc-mirror.example.org:8443/")!,
                allowsNonDefaultPort: true
            ),
            transport: directory
        )
        _ = try await mirror.getDocumentData(did: did)
        #expect(await directory.requests.last?.url.absoluteString == "https://plc-mirror.example.org:8443/\(did)/data")

        let laboratory = try PLCDirectoryClient(
            configuration: .laboratory(origin: URL(string: "http://127.0.0.1:2582")!),
            transport: directory
        )
        _ = try await laboratory.getLastOperation(did: did)
        #expect(await directory.requests.last?.url.absoluteString == "http://127.0.0.1:2582/\(did)/log/last")

        // A non-default port is opt-in; plain HTTP is laboratory-only.
        #expect(throws: PetrelPLCError.self) {
            try PLCClientConfiguration.production(origin: URL(string: "https://plc-mirror.example.org:8443")!)
        }
        #expect(throws: PetrelPLCError.self) {
            try PLCClientConfiguration.production(origin: URL(string: "http://plc-mirror.example.org")!, allowsNonDefaultPort: true)
        }
        #expect(throws: PetrelPLCError.self) {
            try PLCClientConfiguration.production(maximumExportBytes: 65 * 1_024 * 1_024)
        }
    }

    // MARK: Export

    @Test("GET /export pages are requested with count and after, in both formats")
    func exportPages() async throws {
        let directory = FakePLCDirectory()
        // 4 + 3 + 2 operations.
        for did in [PLCVectors.Organisation.support, PLCVectors.Organisation.atprotoCom, PLCVectors.TestIdentity.tombstoned] {
            try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        }
        let client = try plcTestClient(directory)

        // Sequenced format.
        let firstPage = try await client.export(after: .sequence(0), count: 4)
        #expect(firstPage.map(\.sequence) == [1, 2, 3, 4])
        #expect(firstPage.allSatisfy { $0.nullified == nil })
        #expect(await directory.requests.last?.url.absoluteString == "https://plc.test/export?count=4&after=0")
        #expect(await directory.requests.last?.headers["accept"]?.contains("application/jsonlines") == true)

        let secondPage = try await client.export(after: #require(firstPage.last).cursor, count: 4)
        #expect(secondPage.map(\.sequence) == [5, 6, 7, 8])
        #expect(await directory.requests.last?.url.absoluteString == "https://plc.test/export?count=4&after=4")

        // Legacy format: no cursor, then a timestamp cursor, percent-encoded.
        let legacy = try await client.export(count: 3)
        #expect(legacy.count == 3)
        #expect(legacy.allSatisfy { $0.sequence == nil && $0.nullified == false })
        #expect(await directory.requests.last?.url.absoluteString == "https://plc.test/export?count=3")
        let later = try await client.export(after: .timestamp("2023-06-01T00:00:00.000Z"), count: 1_000)
        #expect(later.allSatisfy { $0.createdAt > "2023-06-01T00:00:00.000Z" })
        #expect(await directory.requests.last?.url.absoluteString
            == "https://plc.test/export?count=1000&after=2023-06-01T00%3A00%3A00.000Z")

        // Past the end: an empty body is an empty page.
        #expect(try await client.export(after: .sequence(1_000_000)).isEmpty)

        // Arguments are checked before anything is sent.
        let sent = await directory.requests.count
        await #expect(throws: PetrelPLCError.self) { try await client.export(count: 0) }
        await #expect(throws: PetrelPLCError.self) { try await client.export(count: 1_001) }
        await #expect(throws: PetrelPLCError.self) { try await client.export(after: .timestamp("yesterday")) }
        #expect(await directory.requests.count == sent)
    }

    @Test("exportSequence walks every page lazily and stops at the newest operation")
    func exportSequence() async throws {
        let directory = FakePLCDirectory()
        let dids = [
            PLCVectors.Organisation.support, PLCVectors.Organisation.atprotoCom,
            PLCVectors.TestIdentity.tombstoned, PLCVectors.Organisation.bskyApp,
            PLCVectors.Organisation.moderation, PLCVectors.Organisation.status,
        ]
        var expected = [String]()
        for did in dids {
            try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
            expected += await directory.entries(did: did).map(\.cid)
        }
        #expect(expected.count == 19)
        let client = try plcTestClient(directory)

        var seen = [PLCExportEntry]()
        var requestsAfterFirstElement = 0
        for try await entry in client.exportSequence(pageSize: 5) {
            if seen.isEmpty { requestsAfterFirstElement = await directory.requests.count }
            seen.append(entry)
        }
        // Pages are fetched on demand: one request served the first element.
        #expect(requestsAfterFirstElement == 1)
        #expect(seen.map(\.cid) == expected)
        #expect(seen.map(\.sequence) == (1 ... 19).map { UInt64($0) })
        // 19 operations in pages of 5: four requests, the last one short.
        #expect(await directory.requests.map(\.url.query) == [
            "count=5&after=0", "count=5&after=5", "count=5&after=10", "count=5&after=15",
        ])

        // Resuming from a saved cursor.
        var resumed = [UInt64?]()
        for try await entry in client.exportSequence(after: .sequence(17), pageSize: 5) {
            resumed.append(entry.sequence)
        }
        #expect(resumed == [18, 19])

        // An exact multiple of the page size costs one more, empty, request.
        var count = 0
        for try await _ in client.exportSequence(after: .sequence(9), pageSize: 5) {
            count += 1
        }
        #expect(count == 10)

        // An error surfaces through iteration.
        try await directory.inject(jsonResponse(500, ["message": "boom"]), forPath: "/export")
        await #expect(throws: PetrelPLCError.unavailable("PLC directory returned HTTP 500")) {
            for try await _ in client.exportSequence() {}
        }
    }

    @Test("an export line whose CID does not match its operation is refused")
    func exportIntegrity() async throws {
        let lines = try PLCVectors.data("export-sequenced.jsonl")
            .split(separator: UInt8(ascii: "\n")).map { Data($0) }
        var first = try #require(JSONSerialization.jsonObject(with: lines[0]) as? [String: Any])
        let second = try #require(JSONSerialization.jsonObject(with: lines[1]) as? [String: Any])
        _ = try PLCExportEntry(jsonLine: lines[0])

        first["cid"] = second["cid"]
        #expect(throws: PetrelPLCError.unauthorized("PLC export operation CID is invalid")) {
            try PLCExportEntry(jsonLine: JSONSerialization.data(withJSONObject: first))
        }
        first = try #require(JSONSerialization.jsonObject(with: lines[0]) as? [String: Any])
        first["seq"] = true
        #expect(throws: PetrelPLCError.malformed("PLC export entry is malformed")) {
            try PLCExportEntry(jsonLine: JSONSerialization.data(withJSONObject: first))
        }
        first["seq"] = -1
        #expect(throws: PetrelPLCError.self) {
            try PLCExportEntry(jsonLine: JSONSerialization.data(withJSONObject: first))
        }
        first["seq"] = 1
        first["type"] = "something_else"
        #expect(throws: PetrelPLCError.malformed("PLC export entry type is unsupported")) {
            try PLCExportEntry(jsonLine: JSONSerialization.data(withJSONObject: first))
        }

        let directory = FakePLCDirectory()
        await directory.inject(
            PLCHTTPResponse(status: 200, headers: ["content-type": "application/jsonlines"], body: lines[0] + Data("\n{".utf8)),
            forPath: "/export"
        )
        await #expect(throws: PetrelPLCError.self) { try await plcTestClient(directory).export(after: .sequence(0)) }
    }

    // MARK: Writes

    @Test("create, update handle, PDS, signing key and rotation keys, then tombstone — K-256 and P-256 signers")
    func writeLifecycle() async throws {
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)
        let identity = PLCTestIdentity()

        // Create, signed with the K-256 rotation key.
        let created = try await client.createDID(
            handle: "alice.example.com",
            signingKey: identity.signingKey.didKey,
            rotationKeys: identity.rotationKeys,
            pdsEndpoint: "https://pds.example.com",
            signer: identity.primaryRotationKey
        )
        let did = created.did
        #expect(try PLCOperationCodec.genesisDID(for: created.operation) == did)
        // POST /:did with the operation as JSON, then the confirming read.
        var requests = await directory.requests
        #expect(requests.count == 2)
        #expect(requests[0].method == .post)
        #expect(requests[0].url.absoluteString == "https://plc.test/\(did)")
        #expect(requests[0].headers["content-type"] == "application/json")
        #expect(try requests[0].body == created.operation.canonicalJSON)
        #expect(requests[1].url.absoluteString == "https://plc.test/\(did)/log/audit")
        var state = try await client.fetchState(did: did)
        #expect(state.handle == "alice.example.com")
        #expect(state.rotationKeys == identity.rotationKeys)

        // Update the handle, signed with the P-256 rotation key.
        let handleUpdate = try await client.updateHandle(
            did: did, signer: identity.secondaryRotationKey, handle: "alice.example.org"
        )
        #expect(try handleUpdate.prev == created.operation.cid.string)
        #expect(try PLCOperationCodec.verify(handleUpdate, authorizedRotationKeys: identity.rotationKeys) == 1)

        // Move to another PDS.
        try await client.updatePDS(did: did, signer: identity.primaryRotationKey, endpoint: "https://pds2.example.com")

        // Replace the repository signing key.
        let newSigningKey = P256Keypair.generate()
        try await client.updateAtprotoKey(did: did, signer: identity.primaryRotationKey, signingKey: newSigningKey.didKey)

        state = try await client.fetchState(did: did)
        #expect(state.handle == "alice.example.org")
        #expect(state.pdsEndpoint == "https://pds2.example.com")
        #expect(state.atprotoSigningKey == newSigningKey.didKey)
        #expect(state.rotationKeys == identity.rotationKeys)

        // Rotate: a new key takes over, the old primary is dropped.
        let newRotationKey = P256Keypair.generate()
        let rotation = try await client.updateRotationKeys(
            did: did,
            signer: identity.primaryRotationKey,
            rotationKeys: [newRotationKey.didKey, identity.secondaryRotationKey.didKey]
        )
        #expect(rotation.regular?.rotationKeys == [newRotationKey.didKey, identity.secondaryRotationKey.didKey])

        // The dropped key is refused locally, before signing or sending.
        let postsBefore = await directory.postCount
        await #expect(throws: PetrelPLCError.self) {
            try await client.updateHandle(did: did, signer: identity.primaryRotationKey, handle: "mallory.example.com")
        }
        #expect(await directory.postCount == postsBefore)

        // A general update through the draft.
        try await client.update(did: did, signer: newRotationKey) { draft in
            draft.services["bsky_fg"] = PLCService(type: "BskyFeedGenerator", endpoint: "https://feed.example.com")
            draft.alsoKnownAs.append("https://alice.example.org")
        }
        state = try await client.fetchState(did: did)
        #expect(state.services.count == 2)
        #expect(state.alsoKnownAs == ["at://alice.example.org", "https://alice.example.org"])

        // The verified log shows all six operations and who signed them.
        var log = try await client.fetchVerifiedAuditLog(did: did)
        #expect(log.entries.count == 6)
        #expect(log.signers == [
            identity.primaryRotationKey.didKey, identity.secondaryRotationKey.didKey,
            identity.primaryRotationKey.didKey, identity.primaryRotationKey.didKey,
            identity.primaryRotationKey.didKey, newRotationKey.didKey,
        ])

        // Tombstone.
        let tombstone = try await client.tombstone(did: did, signer: newRotationKey)
        #expect(tombstone.isTombstone)
        log = try await client.fetchVerifiedAuditLog(did: did)
        #expect(log.isTombstoned)
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) { try await client.getDocument(did: did) }
        await #expect(throws: PetrelPLCError.tombstoned(did: did)) {
            try await client.updateHandle(did: did, signer: newRotationKey, handle: "back.example.com")
        }

        // Every POST went to /:did and nowhere else.
        requests = await directory.requests
        #expect(requests.filter { $0.method == .post }.count == 7)
        #expect(requests.filter { $0.method == .post }.allSatisfy { $0.url.absoluteString == "https://plc.test/\(did)" })
    }

    @Test("a recovery submitted through the client nullifies the hijacking operation")
    func recoveryThroughClient() async throws {
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)
        let identity = PLCTestIdentity()
        let (did, genesis) = try await identity.genesis()
        try await client.submit(did: did, operation: genesis)

        // The lower-authority key moves the account away.
        try await client.updatePDS(did: did, signer: identity.secondaryRotationKey, endpoint: "https://attacker.example.com")
        await directory.advance(hours: 24)

        // The higher-authority key forks from the genesis operation.
        let recovery = try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.updatePDS(after: genesis, endpoint: "https://safe.example.com")),
            with: identity.primaryRotationKey
        )
        try await client.submit(did: did, operation: recovery)

        let log = try await client.fetchVerifiedAuditLog(did: did)
        #expect(log.entries.map(\.nullified) == [false, true, false])
        #expect(try await client.fetchState(did: did).pdsEndpoint == "https://safe.example.com")
        // GET /:did/log lists only what is still valid.
        #expect(try await client.getOperationLog(did: did) == [genesis, recovery])

        // After 72 hours the same move is refused by the directory, and the
        // refusal carries its message.
        try await client.updatePDS(did: did, signer: identity.secondaryRotationKey, endpoint: "https://attacker2.example.com")
        await directory.advance(hours: 73)
        let late = try await PLCOperationCodec.sign(
            .regular(PLCOperationCodec.updatePDS(after: recovery, endpoint: "https://too-late.example.com")),
            with: identity.primaryRotationKey
        )
        let refusal = await plcError { try await client.submit(did: did, operation: late) }
        guard case let .rejected(status, message)? = refusal else {
            Issue.record("expected a typed rejection, got \(String(describing: refusal))")
            return
        }
        #expect(status == 400)
        #expect(message.contains("72-hour"))
    }

    @Test("submit applies the write rules before anything is sent")
    func submitValidatesBeforeSending() async throws {
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)

        // A legacy create operation, straight from the directory.
        let legacyDID = PLCVectors.Organisation.support
        let legacy = try PLCAuditLogVerifier.decode(PLCVectors.auditLogJSON(did: legacyDID), did: legacyDID)[0].operation
        await #expect(throws: PetrelPLCError.self) { try await client.submit(did: legacyDID, operation: legacy) }

        // An operation with duplicate rotation keys: readable, as such
        // operations exist in the directory, but not submittable.
        let key = K256Keypair.generate().didKey
        let duplicate = try PLCOperationCodec.decodeSignedJSON(JSONSerialization.data(withJSONObject: [
            "type": "plc_operation",
            "rotationKeys": [key, key],
            "verificationMethods": ["atproto": key],
            "alsoKnownAs": ["at://alice.example.com"],
            "services": [String: Any](),
            "prev": NSNull(),
            "sig": legacy.signature,
        ] as [String: Any]))
        await #expect(throws: PetrelPLCError.malformed("PLC operation must contain 1...5 unique rotation keys")) {
            try await client.submit(did: PLCOperationCodec.genesisDID(for: duplicate), operation: duplicate)
        }

        // A genesis operation submitted under the wrong DID.
        let (did, genesis) = try await PLCTestIdentity().genesis()
        await #expect(throws: PetrelPLCError.unauthorized("PLC genesis DID does not match operation")) {
            try await client.submit(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa", operation: genesis)
        }

        // An operation within the specification but over the reference
        // server's limits, with a client configured to hold to those.
        let strict = try plcTestClient(directory, limits: .referenceDirectory)
        let rotation = K256Keypair.generate()
        let large = try await PLCOperationCodec.sign(.regular(PLCUnsignedRegularOperation(
            rotationKeys: [rotation.didKey],
            verificationMethods: [:],
            alsoKnownAs: (0 ..< 11).map { "at://h\($0).example.com" },
            services: [:],
            prev: nil
        )), with: rotation)
        await #expect(throws: PetrelPLCError.self) {
            try await strict.submit(did: PLCOperationCodec.genesisDID(for: large), operation: large)
        }
        #expect(await directory.requests.isEmpty)

        // With the default limits the same operation is sent, and the
        // directory's refusal comes back typed.
        let refusal = await plcError {
            try await client.submit(did: PLCOperationCodec.genesisDID(for: large), operation: large)
        }
        guard case let .rejected(status, message)? = refusal else {
            Issue.record("expected a typed rejection, got \(String(describing: refusal))")
            return
        }
        #expect(status == 400)
        #expect(message.hasPrefix("Not a valid operation"))
        #expect(await directory.postCount == 1)

        try await client.submit(did: did, operation: genesis)
        #expect(await directory.entries(did: did).count == 1)
    }

    @Test("a submit the directory accepted but that cannot be confirmed is reported as such")
    func submittedButUnconfirmed() async throws {
        let directory = FakePLCDirectory()
        let client = try plcTestClient(directory)
        let (did, genesis) = try await PLCTestIdentity().genesis()

        try await directory.inject(jsonResponse(503, ["message": "unavailable"]), forPath: "/\(did)/log/audit")
        let unconfirmed = await plcError { try await client.submit(did: did, operation: genesis) }
        guard case let .submittedButUnconfirmed(cid, reason)? = unconfirmed else {
            Issue.record("expected submittedButUnconfirmed, got \(String(describing: unconfirmed))")
            return
        }
        #expect(try cid == genesis.cid.string)
        #expect(reason.contains("503"))
        // The operation is in fact registered.
        #expect(await directory.entries(did: did).map(\.operation) == [genesis])
        #expect(try await client.fetchVerifiedAuditLog(did: did).head.operation == genesis)

        // A directory that claims success without recording anything.
        let (otherDID, otherGenesis) = try await PLCTestIdentity().genesis()
        await directory.inject(
            PLCHTTPResponse(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("OK".utf8)),
            forPath: "/\(otherDID)"
        )
        let unrecorded = await plcError { try await client.submit(did: otherDID, operation: otherGenesis) }
        guard case let .submittedButUnconfirmed(_, unrecordedReason)? = unrecorded else {
            Issue.record("expected submittedButUnconfirmed, got \(String(describing: unrecorded))")
            return
        }
        #expect(unrecordedReason.contains("DID not registered"))
    }

    @Test("the URLSession transport serves the client over a stubbed HTTP exchange")
    func urlSessionTransport() async throws {
        // `StubPLCURLProtocol` answers inside URLSession, so the shipping
        // `URLSessionPLCTransport`, its redirect policy and its response
        // bounds are in the path.
        let did = PLCVectors.Organisation.atprotoCom
        let directory = FakePLCDirectory()
        try await directory.seed(did: did, auditLogJSON: PLCVectors.auditLogJSON(did: did))
        StubPLCURLProtocol.directory.withLock { $0 = directory }
        defer { StubPLCURLProtocol.directory.withLock { $0 = nil } }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubPLCURLProtocol.self]
        let client = try PLCDirectoryClient(
            configuration: .stubbedProduction(origin: URL(string: "https://plc.test")!, timeout: stubbedExchangeTimeout),
            transport: stubbedURLSessionTransport(configuration: configuration)
        )
        let log = try await client.fetchVerifiedAuditLog(did: did)
        #expect(log.entries.count == 3)
        #expect(try await client.getDocument(did: did).handle == "atproto.com")
        #expect(try await client.export(after: .sequence(0), count: 2).count == 2)
        await #expect(throws: PetrelPLCError.notFound(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")) {
            try await client.getDocumentData(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")
        }
    }
}

/// Answers `URLSession` requests from a `FakePLCDirectory`.
final class StubPLCURLProtocol: URLProtocol, @unchecked Sendable {
    static let directory = PLCTestLock<FakePLCDirectory?>(nil)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let directory = Self.directory.withLock({ $0 }), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let plcRequest = PLCHTTPRequest(
            method: request.httpMethod == "POST" ? .post : .get,
            url: url,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: stubbedExchangeTimeout,
            maximumResponseBytes: 1_048_576
        )
        let box = PLCTestUnchecked(self)
        Task {
            let this = box.value
            do {
                let response = try await directory.execute(plcRequest)
                guard let http = HTTPURLResponse(
                    url: url, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers
                ) else {
                    throw URLError(.badServerResponse)
                }
                this.client?.urlProtocol(this, didReceive: http, cacheStoragePolicy: .notAllowed)
                this.client?.urlProtocol(this, didLoad: response.body)
                this.client?.urlProtocolDidFinishLoading(this)
            } catch {
                this.client?.urlProtocol(this, didFailWithError: error)
            }
        }
    }
}

final class PLCTestLock<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

struct PLCTestUnchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
