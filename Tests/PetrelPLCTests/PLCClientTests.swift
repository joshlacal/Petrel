import Crypto
import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelPLC
import XCTest

final class PLCClientTests: XCTestCase {
    private let signingKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
    private let rotationKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 9, count: 32))

    func testConfigurationRejectsNonOriginUnsafePortAndRequiresExplicitLiteralLoopbackLabMode() throws {
        XCTAssertNoThrow(try PLCClientConfiguration.production())
        XCTAssertNoThrow(try PLCClientConfiguration.production(origin: URL(string: "https://plc.example.com")!))
        XCTAssertNoThrow(try PLCClientConfiguration.laboratory(origin: URL(string: "http://127.0.0.1:2582")!))
        XCTAssertNoThrow(try PLCClientConfiguration.laboratory(origin: URL(string: "http://[::1]:2582")!))

        for invalid in [
            "http://plc.example.com", "https://plc.example.com:8443",
            "https://plc.example.com/path", "https://user@plc.example.com",
            "http://localhost:2582", "http://192.168.1.2:2582",
        ] {
            XCTAssertThrowsError(try PLCClientConfiguration.production(origin: URL(string: invalid)!))
        }
        XCTAssertThrowsError(try PLCClientConfiguration.laboratory(origin: URL(string: "http://192.168.1.2:2582")!))
    }
    func testPLCHTTPResponseNormalizesHeaderNamesToLowercase() {
        let response = PLCHTTPResponse(
            status: 200,
            headers: ["Content-Type": "application/json", "X-Custom-Header": "Value"],
            body: Data(),
            finalURL: nil,
            redirectCount: 0
        )
        XCTAssertEqual(response.headers["content-type"], "application/json")
        XCTAssertEqual(response.headers["x-custom-header"], "Value")
    }

    func testSubmitUsesExactEscapedRouteMethodAndCanonicalJSON() async throws {
        let fixture = try operationFixture()
        let transport = RecordingPLCTransport(responses: [
            .init(status: 200, headers: [:], body: Data(), finalURL: nil, redirectCount: 0),
            jsonResponse(try auditJSON(did: fixture.did, operation: fixture.operation)),
        ])
        let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
        try await client.submit(did: fixture.did, operation: fixture.operation)

        let recorded = await transport.requests
        // The second request is the confirmation read the production contract
        // requires; state that dependence rather than leaving it incidental.
        XCTAssertEqual(recorded.count, 2)
        let request = try XCTUnwrap(recorded.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url.absoluteString, "https://plc.example.com/\(fixture.did)")
        XCTAssertEqual(request.headers["content-type"], "application/json")
        XCTAssertEqual(request.body, try fixture.operation.canonicalJSON)
        XCTAssertEqual(request.maximumResponseBytes, 64 * 1_024)
    }

    func testPinnedReferenceSubmitResponseRequiresExplicitLaboratoryCompatibility() async throws {
        let fixture = try operationFixture()
        let response = PLCHTTPResponse(
            status: 200,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: Data([0x4f, 0x4b]),
            finalURL: nil,
            redirectCount: 0
        )

        for configuration in [
            try PLCClientConfiguration.production(
                origin: URL(string: "https://plc.example.com")!
            ),
            try PLCClientConfiguration.laboratory(
                origin: URL(string: "http://127.0.0.1:2582")!
            ),
        ] {
            let client = try PLCDirectoryClient(
                configuration: configuration,
                transport: RecordingPLCTransport(responses: [response])
            )
            await XCTAssertThrowsErrorAsync(
                try await client.submit(did: fixture.did, operation: fixture.operation)
            )
        }

        let compatible = try PLCDirectoryClient(
            configuration: .laboratory(
                origin: URL(string: "http://127.0.0.1:2582")!,
                submitSuccessResponsePolicy: .didPLCServer001
            ),
            transport: RecordingPLCTransport(responses: [response])
        )
        try await compatible.submit(did: fixture.did, operation: fixture.operation)
    }

    func testPinnedReferenceSubmitResponseRejectsEveryNonExactShape() async throws {
        let fixture = try operationFixture()
        let requested = URL(string: "http://127.0.0.1:2582/\(fixture.did)")!
        let cases: [PLCHTTPResponse] = [
            .init(status: 201, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("OK".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 204, headers: [:], body: Data(), finalURL: nil, redirectCount: 0),
            .init(status: 202, headers: ["content-type": "application/json"], body: Data("{}".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("ok".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("OK\n".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain"], body: Data("OK".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=UTF-8"], body: Data("OK".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8; version=1"], body: Data("OK".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "application/json"], body: Data("OK".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("OK".utf8), finalURL: nil, redirectCount: 1),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data("OK".utf8), finalURL: URL(string: "http://127.0.0.1:2582/elsewhere"), redirectCount: 0),
            .init(status: 200, headers: ["content-type": "text/plain; charset=utf-8"], body: Data(repeating: 0x4f, count: 65), finalURL: nil, redirectCount: 0),
        ]

        for response in cases {
            let configuration = try PLCClientConfiguration.laboratory(
                origin: URL(string: "http://127.0.0.1:2582")!,
                submitSuccessResponsePolicy: .didPLCServer001,
                maximumSubmitResponseBytes: 64
            )
            let transport = RecordingPLCTransport(responses: [response])
            let client = try PLCDirectoryClient(
                configuration: configuration,
                transport: transport
            )
            await XCTAssertThrowsErrorAsync(
                try await client.submit(did: fixture.did, operation: fixture.operation)
            )
        }
        XCTAssertEqual(requested.path, "/\(fixture.did)")
    }

    func testStrictProductionSubmitConfirmsGenericTwoXXEmptyAndJSONResponses() async throws {
        let fixture = try operationFixture()
        let responses: [PLCHTTPResponse] = [
            .init(
                status: 204,
                headers: [:],
                body: Data(),
                finalURL: nil,
                redirectCount: 0
            ),
            .init(
                status: 202,
                headers: ["content-type": "application/json"],
                body: Data("{}".utf8),
                finalURL: nil,
                redirectCount: 0
            ),
        ]

        for response in responses {
            let transport = RecordingPLCTransport(responses: [
                response,
                jsonResponse(try auditJSON(did: fixture.did, operation: fixture.operation)),
            ])
            let client = try PLCDirectoryClient(
                configuration: .production(
                    origin: URL(string: "https://plc.example.com")!
                ),
                transport: transport
            )
            try await client.submit(did: fixture.did, operation: fixture.operation)

            let recorded = await transport.requests
            XCTAssertEqual(recorded.count, 2)
            XCTAssertEqual(recorded[1].method, .get)
        }
    }

    func testStrictProductionSubmitRejectsAuditWhoseTerminalIsNotTheSubmittedOperation() async throws {
        let fixture = try operationFixture()
        let successor = try update(
            previous: fixture.operation,
            signer: rotationKey,
            rotationKeys: [rotationKey],
            pdsOrigin: "https://pds2.example.com"
        )
        let transport = RecordingPLCTransport(responses: [
            .init(
                status: 200,
                headers: ["content-type": "text/plain; charset=utf-8"],
                body: Data([0x4F, 0x4B]),
                finalURL: nil,
                redirectCount: 0
            ),
            jsonResponse(
                try auditJSON(did: fixture.did, operations: [fixture.operation, successor])
            ),
        ])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        await XCTAssertThrowsErrorAsync(
            try await client.submit(did: fixture.did, operation: fixture.operation)
        )
    }

    func testStrictProductionSubmitAcceptsAuditWhoseTerminalIsTheSubmittedOperation() async throws {
        let fixture = try operationFixture()
        let successor = try update(
            previous: fixture.operation,
            signer: rotationKey,
            rotationKeys: [rotationKey],
            pdsOrigin: "https://pds2.example.com"
        )
        let transport = RecordingPLCTransport(responses: [
            .init(
                status: 200,
                headers: ["content-type": "text/plain; charset=utf-8"],
                body: Data([0x4F, 0x4B]),
                finalURL: nil,
                redirectCount: 0
            ),
            jsonResponse(
                try auditJSON(did: fixture.did, operations: [fixture.operation, successor])
            ),
        ])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        try await client.submit(did: fixture.did, operation: successor)
    }

    func testStrictProductionSubmitConfirmsUnverifiableSuccessAgainstAuditTerminal() async throws {
        let fixture = try operationFixture()
        let transport = RecordingPLCTransport(responses: [
            .init(
                status: 200,
                headers: ["content-type": "text/plain; charset=utf-8"],
                body: Data([0x4F, 0x4B]),
                finalURL: nil,
                redirectCount: 0
            ),
            jsonResponse(try auditJSON(did: fixture.did, operation: fixture.operation)),
        ])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        try await client.submit(did: fixture.did, operation: fixture.operation)

        let recorded = await transport.requests
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded[0].method, .post)
        XCTAssertEqual(recorded[1].method, .get)
        XCTAssertEqual(
            recorded[1].url.absoluteString,
            "https://plc.example.com/\(fixture.did)/log/audit"
        )
    }

    func testStrictProductionSubmitRejectsUnverifiableSuccessWithoutMatchingAuditTerminal() async throws {
        let fixture = try operationFixture()
        let other = try operationFixture(rotationKeys: [signingKey])
        let unverifiable = PLCHTTPResponse(
            status: 200,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: Data([0x4F, 0x4B]),
            finalURL: nil,
            redirectCount: 0
        )
        let confirmations: [PLCHTTPResponse] = [
            jsonResponse(try auditJSON(did: other.did, operation: other.operation)),
            jsonResponse(Data("[]".utf8)),
            .init(status: 500, headers: [:], body: Data(), finalURL: nil, redirectCount: 0),
        ]

        for confirmation in confirmations {
            let client = try PLCDirectoryClient(
                configuration: .production(origin: URL(string: "https://plc.example.com")!),
                transport: RecordingPLCTransport(responses: [unverifiable, confirmation])
            )
            await XCTAssertThrowsErrorAsync(
                try await client.submit(did: fixture.did, operation: fixture.operation)
            )
        }
    }

    func testStrictLaboratorySubmitRejectsPlainTextWithoutConfirming() async throws {
        let fixture = try operationFixture()
        let transport = RecordingPLCTransport(responses: [
            .init(
                status: 200,
                headers: ["content-type": "text/plain; charset=utf-8"],
                body: Data([0x4F, 0x4B]),
                finalURL: nil,
                redirectCount: 0
            ),
            jsonResponse(try auditJSON(did: fixture.did, operation: fixture.operation)),
        ])
        let client = try PLCDirectoryClient(
            configuration: .laboratory(origin: URL(string: "http://127.0.0.1:2582")!),
            transport: transport
        )

        await XCTAssertThrowsErrorAsync(
            try await client.submit(did: fixture.did, operation: fixture.operation)
        )
        let recorded = await transport.requests
        XCTAssertEqual(recorded.count, 1)
    }

    func testStrictProductionSubmitStillRejectsNonSuccessStatusWithoutConfirming() async throws {
        let fixture = try operationFixture()
        let transport = RecordingPLCTransport(responses: [
            .init(
                status: 400,
                headers: ["content-type": "text/plain; charset=utf-8"],
                body: Data([0x4F, 0x4B]),
                finalURL: nil,
                redirectCount: 0
            ),
            jsonResponse(try auditJSON(did: fixture.did, operation: fixture.operation)),
        ])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        await XCTAssertThrowsErrorAsync(
            try await client.submit(did: fixture.did, operation: fixture.operation)
        )
        let recorded = await transport.requests
        XCTAssertEqual(recorded.count, 1)
    }

    func testFetchAuditUsesExactRouteAndVerifiesOperationCIDSignatureAndDID() async throws {
        let fixture = try operationFixture()
        let audit = try auditJSON(did: fixture.did, operation: fixture.operation)
        let transport = RecordingPLCTransport(responses: [
            jsonResponse(audit),
        ])
        let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
        let entries = try await client.fetchAudit(did: fixture.did)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].cid, try fixture.operation.cid.string)
        let recorded = await transport.requests
        let request = try XCTUnwrap(recorded.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url.absoluteString, "https://plc.example.com/\(fixture.did)/log/audit")
        XCTAssertNil(request.body)
    }

    func testFetchStateAuthenticatesDataAgainstAuditTerminalOperation() async throws {
        let fixture = try operationFixture()
        let data = try documentDataJSON(did: fixture.did, operation: fixture.operation)
        let audit = try auditJSON(did: fixture.did, operation: fixture.operation)
        let transport = RecordingPLCTransport(responses: [jsonResponse(data), jsonResponse(audit)])
        let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
        let state = try await client.fetchState(did: fixture.did)

        XCTAssertEqual(state.did, fixture.did)
        XCTAssertEqual(state.rotationKeys, [P256DIDKey(publicKey: rotationKey.publicKey).value])
        let requests = await transport.requests
        XCTAssertEqual(requests.map(\.url.path), ["/\(fixture.did)/data", "/\(fixture.did)/log/audit"])
    }

    func testResponsePolicyRejectsErrorsRedirectsTypesOversizeAndFinalURLMismatch() async throws {
        let fixture = try operationFixture()
        let validAudit = try auditJSON(did: fixture.did, operation: fixture.operation)
        let cases: [PLCHTTPResponse] = [
            .init(status: 500, headers: ["content-type": "application/json"], body: Data("{}".utf8), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "application/json"], body: validAudit, finalURL: nil, redirectCount: 1),
            .init(status: 200, headers: ["content-type": "text/html"], body: validAudit, finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "application/json"], body: Data(repeating: 0x20, count: 512 * 1_024 + 1), finalURL: nil, redirectCount: 0),
            .init(status: 200, headers: ["content-type": "application/json"], body: validAudit, finalURL: URL(string: "https://evil.example/\(fixture.did)/log/audit"), redirectCount: 0),
        ]
        for response in cases {
            let transport = RecordingPLCTransport(responses: [response])
            let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
            await XCTAssertThrowsErrorAsync(try await client.fetchAudit(did: fixture.did))
        }
    }

    func testAuditRejectsMismatchedDIDMalformedUnsignedInvalidAndTamperedOperations() async throws {
        let fixture = try operationFixture()
        let valid = try XCTUnwrap(JSONSerialization.jsonObject(with: try auditJSON(did: fixture.did, operation: fixture.operation)) as? [[String: Any]])
        var cases = [[String: Any]]()

        var mismatch = valid[0]
        mismatch["did"] = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
        cases.append(mismatch)

        var wrongCID = valid[0]
        wrongCID["cid"] = CID.fromBlob(Data("wrong".utf8)).string
        cases.append(wrongCID)

        var unsigned = valid[0]
        var unsignedOp = unsigned["operation"] as! [String: Any]
        unsignedOp.removeValue(forKey: "sig")
        unsigned["operation"] = unsignedOp
        cases.append(unsigned)

        var tampered = valid[0]
        var tamperedOp = tampered["operation"] as! [String: Any]
        tamperedOp["alsoKnownAs"] = ["at://mallory.example.com"]
        tampered["operation"] = tamperedOp
        cases.append(tampered)

        for entry in cases {
            let body = try JSONSerialization.data(withJSONObject: [entry], options: [.sortedKeys])
            let transport = RecordingPLCTransport(responses: [jsonResponse(body)])
            let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
            await XCTAssertThrowsErrorAsync(try await client.fetchAudit(did: fixture.did))
        }
    }

    func testAuditRejectsBrokenUpdatePrevAndSignatureAuthorization() async throws {
        let fixture = try operationFixture()
        let attacker = P256.Signing.PrivateKey()
        let update = try PLCATProfile.regularOperation(
            handle: "alice.example.com",
            signingPublicKey: signingKey.publicKey,
            rotationPublicKeys: [rotationKey.publicKey],
            pdsOrigin: URL(string: "https://next.example.com")!,
            prev: fixture.operation.cid.string
        )
        let attackerSigned = try PLCOperationCodec.sign(.regular(update), using: attacker)
        let body = try auditJSON(did: fixture.did, operations: [fixture.operation, attackerSigned])
        let transport = RecordingPLCTransport(responses: [jsonResponse(body)])
        let client = try PLCDirectoryClient(configuration: .production(origin: URL(string: "https://plc.example.com")!), transport: transport)
        await XCTAssertThrowsErrorAsync(try await client.fetchAudit(did: fixture.did))
    }

    func testAuditReconstructsHigherPriorityRecoveryWithoutTrustingNullifiedFlags() async throws {
        let highAuthority = rotationKey
        let lowAuthority = try P256.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 10, count: 32)
        )
        let fixture = try operationFixture(rotationKeys: [highAuthority, lowAuthority])
        let disputed = try update(
            previous: fixture.operation,
            signer: lowAuthority,
            rotationKeys: [lowAuthority],
            pdsOrigin: "https://disputed.example.com"
        )
        let recovered = try update(
            previous: fixture.operation,
            signer: highAuthority,
            rotationKeys: [highAuthority],
            pdsOrigin: "https://recovered.example.com"
        )
        let audit = try auditJSON(
            did: fixture.did,
            operations: [fixture.operation, disputed, recovered],
            timestamps: [
                "2026-07-20T12:00:00.000Z",
                "2026-07-27T12:00:00.000Z",
                "2026-07-27T13:00:00.000Z",
            ],
            claimedNullified: [true, false, true]
        )
        let stateData = try documentDataJSON(did: fixture.did, operation: recovered)
        let transport = RecordingPLCTransport(responses: [
            jsonResponse(audit),
            jsonResponse(stateData), jsonResponse(audit),
        ])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        let entries = try await client.fetchAudit(did: fixture.did)
        XCTAssertEqual(entries.map(\.nullified), [false, true, false])
        let state = try await client.fetchState(did: fixture.did)
        XCTAssertEqual(
            state.services["atproto_pds"]?.endpoint,
            "https://recovered.example.com"
        )
    }

    func testAuditRejectsLowerPriorityForkEvenWhenDirectoryFlagsItCurrent() async throws {
        let highAuthority = rotationKey
        let lowAuthority = try P256.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 10, count: 32)
        )
        let fixture = try operationFixture(rotationKeys: [highAuthority, lowAuthority])
        let highUpdate = try update(
            previous: fixture.operation,
            signer: highAuthority,
            rotationKeys: [highAuthority],
            pdsOrigin: "https://authoritative.example.com"
        )
        let lowerFork = try update(
            previous: fixture.operation,
            signer: lowAuthority,
            rotationKeys: [lowAuthority],
            pdsOrigin: "https://lower.example.com"
        )
        let audit = try auditJSON(
            did: fixture.did,
            operations: [fixture.operation, highUpdate, lowerFork],
            timestamps: [
                "2026-07-20T12:00:00.000Z",
                "2026-07-27T12:00:00.000Z",
                "2026-07-27T13:00:00.000Z",
            ],
            claimedNullified: [false, true, false]
        )
        let transport = RecordingPLCTransport(responses: [jsonResponse(audit)])
        let client = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: transport
        )

        await XCTAssertThrowsErrorAsync(try await client.fetchAudit(did: fixture.did))
    }

    func testAuditEnforcesRecoveryWindowExactTimestampsAndMonotonicOrder() async throws {
        let highAuthority = rotationKey
        let lowAuthority = try P256.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 10, count: 32)
        )
        let fixture = try operationFixture(rotationKeys: [highAuthority, lowAuthority])
        let disputed = try update(
            previous: fixture.operation,
            signer: lowAuthority,
            rotationKeys: [lowAuthority],
            pdsOrigin: "https://disputed.example.com"
        )
        let recovered = try update(
            previous: fixture.operation,
            signer: highAuthority,
            rotationKeys: [highAuthority],
            pdsOrigin: "https://recovered.example.com"
        )
        let boundaryAudit = try auditJSON(
            did: fixture.did,
            operations: [fixture.operation, disputed, recovered],
            timestamps: [
                "2026-07-20T12:00:00.000Z",
                "2026-07-23T12:00:00.000Z",
                "2026-07-26T12:00:00.000Z",
            ]
        )
        let boundaryTransport = RecordingPLCTransport(responses: [
            jsonResponse(boundaryAudit),
        ])
        let boundaryClient = try PLCDirectoryClient(
            configuration: .production(origin: URL(string: "https://plc.example.com")!),
            transport: boundaryTransport
        )
        let boundaryEntries = try await boundaryClient.fetchAudit(did: fixture.did)
        XCTAssertEqual(boundaryEntries.map(\.nullified), [false, true, false])

        let invalidTimestamps = [
            [
                "2026-07-20T12:00:00.000Z",
                "2026-07-23T12:00:00.000Z",
                "2026-07-26T12:00:00.001Z",
            ],
            [
                "2026-07-20T12:00:00.000Z",
                "2026-07-23T12:00:00Z",
                "2026-07-23T13:00:00.000Z",
            ],
            [
                "2026-07-20T12:00:00.000Z",
                "2026-07-23T12:00:01.000Z",
                "2026-07-23T12:00:00.000Z",
            ],
        ]
        for timestamps in invalidTimestamps {
            let audit = try auditJSON(
                did: fixture.did,
                operations: [fixture.operation, disputed, recovered],
                timestamps: timestamps
            )
            let transport = RecordingPLCTransport(responses: [jsonResponse(audit)])
            let client = try PLCDirectoryClient(
                configuration: .production(origin: URL(string: "https://plc.example.com")!),
                transport: transport
            )
            await XCTAssertThrowsErrorAsync(try await client.fetchAudit(did: fixture.did))
        }
    }

    private func operationFixture(
        rotationKeys: [P256.Signing.PrivateKey]? = nil
    ) throws -> (did: String, operation: PLCSignedOperation) {
        let rotationKeys = rotationKeys ?? [rotationKey]
        let unsigned = try PLCATProfile.regularOperation(
            handle: "alice.example.com",
            signingPublicKey: signingKey.publicKey,
            rotationPublicKeys: rotationKeys.map(\.publicKey),
            pdsOrigin: URL(string: "https://pds.example.com")!,
            prev: nil
        )
        let signed = try PLCOperationCodec.sign(.regular(unsigned), using: rotationKeys[0])
        return (try PLCOperationCodec.genesisDID(for: signed), signed)
    }

    private func update(
        previous: PLCSignedOperation,
        signer: P256.Signing.PrivateKey,
        rotationKeys: [P256.Signing.PrivateKey],
        pdsOrigin: String
    ) throws -> PLCSignedOperation {
        let unsigned = try PLCATProfile.regularOperation(
            handle: "alice.example.com",
            signingPublicKey: signingKey.publicKey,
            rotationPublicKeys: rotationKeys.map(\.publicKey),
            pdsOrigin: URL(string: pdsOrigin)!,
            prev: previous.cid.string
        )
        return try PLCOperationCodec.sign(.regular(unsigned), using: signer)
    }

    private func auditJSON(did: String, operation: PLCSignedOperation) throws -> Data {
        try auditJSON(did: did, operations: [operation])
    }

    private func auditJSON(
        did: String,
        operations: [PLCSignedOperation],
        timestamps: [String]? = nil,
        claimedNullified: [Bool]? = nil
    ) throws -> Data {
        if let timestamps {
            XCTAssertEqual(timestamps.count, operations.count)
        }
        if let claimedNullified {
            XCTAssertEqual(claimedNullified.count, operations.count)
        }
        let entries = try operations.enumerated().map { index, operation -> [String: Any] in
            [
                "did": did,
                "operation": try JSONSerialization.jsonObject(with: operation.canonicalJSON),
                "cid": try operation.cid.string,
                "nullified": claimedNullified?[index] ?? false,
                "createdAt": timestamps?[index] ?? "2026-07-27T12:00:0\(index).000Z",
            ]
        }
        return try JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys])
    }

    private func documentDataJSON(did: String, operation: PLCSignedOperation) throws -> Data {
        let regular = try XCTUnwrap(operation.regular)
        return try JSONSerialization.data(withJSONObject: [
            "did": did,
            "rotationKeys": regular.rotationKeys,
            "verificationMethods": regular.verificationMethods,
            "alsoKnownAs": regular.alsoKnownAs,
            "services": regular.services.mapValues { ["type": $0.type, "endpoint": $0.endpoint] },
        ], options: [.sortedKeys])
    }

    private func jsonResponse(_ body: Data) -> PLCHTTPResponse {
        .init(status: 200, headers: ["content-type": "application/json; charset=utf-8"], body: body, finalURL: nil, redirectCount: 0)
    }
}

private actor RecordingPLCTransport: PLCHTTPTransport {
    private(set) var requests = [PLCHTTPRequest]()
    private var responses: [PLCHTTPResponse]

    init(responses: [PLCHTTPResponse]) {
        self.responses = responses
    }

    func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw TestFailure.noResponse }
        var response = responses.removeFirst()
        if response.finalURL == nil {
            response = .init(
                status: response.status,
                headers: response.headers,
                body: response.body,
                finalURL: request.url,
                redirectCount: response.redirectCount
            )
        }
        return response
    }

    enum TestFailure: Error { case noResponse }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected error", file: file, line: line)
    } catch {}
}
