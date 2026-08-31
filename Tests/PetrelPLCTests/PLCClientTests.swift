import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCore
import PetrelCrypto
@testable import PetrelPLC
import XCTest

final class PLCClientTests: XCTestCase {
    private let signingKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
    private let rotationKey = try! P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 9, count: 32))
    override func setUp() {
        super.setUp()
        MockPLCHTTPURLProtocol.reset()
    }

    override func tearDown() {
        MockPLCHTTPURLProtocol.reset()
        super.tearDown()
    }

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
            let client = PLCDirectoryClient(
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
            let client = PLCDirectoryClient(
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

    func testURLSessionPLCTransportCancelsOversizedStreamingResponseWithExplicitSynchronization() async throws {
        MockPLCHTTPURLProtocol.reset()
        let stopExpectation = expectation(description: "stopLoading must be called when streaming exceeds bound")
        stopExpectation.expectedFulfillmentCount = 1
        stopExpectation.assertForOverFulfill = true
        MockPLCHTTPURLProtocol.stopExpectation = stopExpectation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        var streamContinuation: AsyncStream<Data>.Continuation?
        let stream = AsyncStream<Data> { continuation in
            streamContinuation = continuation
        }

        MockPLCHTTPURLProtocol.streamHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, stream)
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/oversized-stream")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        let executeTask = Task {
            try await transport.execute(request)
        }

        await MockPLCHTTPURLProtocol.waitForStart()

        let chunk1 = Data(repeating: 0x41, count: 600)
        streamContinuation?.yield(chunk1)
        await MockPLCHTTPURLProtocol.waitForChunk(after: 0)

        let chunk2 = Data(repeating: 0x42, count: 600)
        streamContinuation?.yield(chunk2)
        await fulfillment(of: [stopExpectation], timeout: 2.0)
        XCTAssertTrue(MockPLCHTTPURLProtocol.isStopLoadingCalled)
        XCTAssertEqual(MockPLCHTTPURLProtocol.stopCallCount, 1)
        let chunk3 = Data(repeating: 0x43, count: 500)
        streamContinuation?.yield(chunk3)
        streamContinuation?.finish()

        do {
            _ = try await executeTask.value
            XCTFail("Expected execute to throw bound exceeded error")
        } catch let error as PetrelPLCError {
            guard case let .unavailable(message) = error else {
                XCTFail("Expected unavailable error, got: \(error)")
                return
            }
            XCTAssertEqual(message, "PLC HTTP response exceeded its bound")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(transport.lastAcceptedBytes, 600)
        XCTAssertEqual(MockPLCHTTPURLProtocol.chunksDeliveredAfterStop, 0)
        XCTAssertEqual(MockPLCHTTPURLProtocol.bytesDeliveredAfterStop, 0)
        XCTAssertEqual(MockPLCHTTPURLProtocol.stopCallCount, 1)
    }

    func testURLSessionPLCTransportSingleCallbackExceedingLimitRejectsWithoutBuffering() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        MockPLCHTTPURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(repeating: 0x41, count: 50_000))
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/large-single-chunk")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        do {
            _ = try await transport.execute(request)
            XCTFail("Expected execute to throw bound exceeded error")
        } catch let error as PetrelPLCError {
            guard case let .unavailable(message) = error else {
                XCTFail("Expected unavailable error, got: \(error)")
                return
            }
            XCTAssertEqual(message, "PLC HTTP response exceeded its bound")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(transport.lastAcceptedBytes, 0)
    }

    func testURLSessionPLCTransportPreCancelledTaskCompletesWithCancellationError() async throws {
        MockPLCHTTPURLProtocol.reset()
        let stopExpectation = expectation(description: "stopLoading must not be called on pre-cancelled task")
        stopExpectation.isInverted = true
        MockPLCHTTPURLProtocol.stopExpectation = stopExpectation

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        MockPLCHTTPURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"status\":\"ok\"}".utf8))
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/pre-cancelled")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.execute(request)
        }

        do {
            _ = try await task.value
            XCTFail("Expected Task execution to throw CancellationError")
        } catch is CancellationError {
            // Success
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        await fulfillment(of: [stopExpectation], timeout: 0.1)
        // Darwin's URLSession never starts (so never stops) a pre-cancelled task;
        // swift-corelibs-foundation starts it and then invokes stopLoading.
        #if canImport(Darwin)
        XCTAssertFalse(MockPLCHTTPURLProtocol.isStopLoadingCalled)
        XCTAssertEqual(MockPLCHTTPURLProtocol.stopCallCount, 0)
        #endif
        XCTAssertEqual(transport.lastAcceptedBytes, 0)
    }

    func testURLSessionPLCTransportDeinitInvalidatesSessionWithoutRetainCycle() throws {
        weak var weakTransport: URLSessionPLCTransport?
        weak var weakDelegate: AnyObject?

        try {
            let transport = try URLSessionPLCTransport(maximumTimeout: 5)
            weakTransport = transport
            weakDelegate = transport.delegate
            XCTAssertNotNil(weakTransport)
            XCTAssertNotNil(weakDelegate)
        }()

        XCTAssertNil(weakTransport, "URLSessionPLCTransport should deallocate when out of scope")
    }

    func testURLSessionPLCTransportSuccessfulRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        let testBody = Data("{\"status\":\"ok\"}".utf8)
        MockPLCHTTPURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "X-Response-Header": "header-value",
                ]
            )!
            return (response, testBody)
        }

        let request = PLCHTTPRequest(
            method: .post,
            url: URL(string: "https://mock.plc.test/status")!,
            headers: ["X-Custom-Header": "custom-value"],
            body: Data("{\"hello\":\"world\"}".utf8),
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        let response = try await transport.execute(request)
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.body, testBody)
        XCTAssertEqual(response.headers["content-type"], "application/json")
        XCTAssertEqual(response.headers["x-response-header"], "header-value")
        XCTAssertEqual(response.finalURL, URL(string: "https://mock.plc.test/status"))
        XCTAssertEqual(response.redirectCount, 0)
    }

    func testURLSessionPLCTransportDisallowsRedirects() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        MockPLCHTTPURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Location": "https://evil.plc.test/redirected",
                    "Content-Type": "text/plain",
                ]
            )!
            return (response, Data("redirect".utf8))
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/redirect")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        let response = try await transport.execute(request)
        XCTAssertEqual(response.status, 302)
        XCTAssertEqual(response.finalURL, URL(string: "https://mock.plc.test/redirect"))
        XCTAssertEqual(response.redirectCount, 0)
    }

    func testURLSessionPLCTransportPropagatesTaskCancellation() async throws {
        MockPLCHTTPURLProtocol.reset()
        let stopExpectation = expectation(description: "stopLoading must be called on in-flight cancellation")
        stopExpectation.expectedFulfillmentCount = 1
        stopExpectation.assertForOverFulfill = true
        MockPLCHTTPURLProtocol.stopExpectation = stopExpectation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        let cancelGate = CancelGate()

        MockPLCHTTPURLProtocol.handler = { request in
            await cancelGate.wait()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                ]
            )!
            return (response, Data("{\"status\":\"ok\"}".utf8))
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/cancel")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        let task = Task {
            try await transport.execute(request)
        }

        await MockPLCHTTPURLProtocol.waitForStart()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected Task execution to throw CancellationError")
        } catch is CancellationError {
            // Success
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        await fulfillment(of: [stopExpectation], timeout: 2.0)
        XCTAssertTrue(MockPLCHTTPURLProtocol.isStopLoadingCalled)
        XCTAssertEqual(MockPLCHTTPURLProtocol.stopCallCount, 1)
        XCTAssertEqual(transport.lastAcceptedBytes, 0)
    }

    func testURLSessionPLCTransportRejectsContentLengthExceedingBound() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPLCHTTPURLProtocol.self]
        let transport = try URLSessionPLCTransport(maximumTimeout: 5, configuration: configuration)

        MockPLCHTTPURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Length": "2000",
                    "Content-Type": "application/octet-stream",
                ]
            )!
            return (response, Data(repeating: 0x42, count: 2000))
        }

        let request = PLCHTTPRequest(
            method: .get,
            url: URL(string: "https://mock.plc.test/large-content-length")!,
            headers: [:],
            body: nil,
            timeout: 5,
            maximumResponseBytes: 1_000
        )

        do {
            _ = try await transport.execute(request)
            XCTFail("Expected execute to throw bound exceeded error")
        } catch let error as PetrelPLCError {
            guard case let .unavailable(message) = error else {
                XCTFail("Expected unavailable error, got: \(error)")
                return
            }
            XCTAssertEqual(message, "PLC HTTP response exceeded its bound")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testURLSessionPLCTransportValidatesRequestBounds() async throws {
        let transport = try URLSessionPLCTransport(maximumTimeout: 10)
        let validURL = URL(string: "https://plc.directory/test")!

        // Timeout <= 0
        await XCTAssertThrowsErrorAsync(try await transport.execute(PLCHTTPRequest(
            method: .get, url: validURL, headers: [:], body: nil, timeout: 0, maximumResponseBytes: 1000
        )))

        // Timeout > maximumTimeout
        await XCTAssertThrowsErrorAsync(try await transport.execute(PLCHTTPRequest(
            method: .get, url: validURL, headers: [:], body: nil, timeout: 11, maximumResponseBytes: 1000
        )))

        // maximumResponseBytes <= 0
        await XCTAssertThrowsErrorAsync(try await transport.execute(PLCHTTPRequest(
            method: .get, url: validURL, headers: [:], body: nil, timeout: 5, maximumResponseBytes: 0
        )))

        // maximumResponseBytes > 1_048_576
        await XCTAssertThrowsErrorAsync(try await transport.execute(PLCHTTPRequest(
            method: .get, url: validURL, headers: [:], body: nil, timeout: 5, maximumResponseBytes: 1_048_577
        )))

        // Body > 32KB
        await XCTAssertThrowsErrorAsync(try await transport.execute(PLCHTTPRequest(
            method: .post, url: validURL, headers: [:], body: Data(repeating: 0, count: 32 * 1024 + 1), timeout: 5, maximumResponseBytes: 1000
        )))
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

private struct UnsafeTransfer<T>: @unchecked Sendable {
    let value: T
}

private final class CancelGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isCancelled = false

    func wait() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                let alreadyCancelled = lock.withLock { () -> Bool in
                    if isCancelled {
                        return true
                    } else {
                        continuation = cont
                        return false
                    }
                }
                if alreadyCancelled {
                    cont.resume()
                }
            }
        } onCancel: {
            let cont = lock.withLock { () -> CheckedContinuation<Void, Never>? in
                isCancelled = true
                let c = continuation
                continuation = nil
                return c
            }
            cont?.resume()
        }
    }
}

final class MockPLCHTTPURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)
    typealias StreamHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, AsyncStream<Data>)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: Handler?
    nonisolated(unsafe) private static var _streamHandler: StreamHandler?
    nonisolated(unsafe) private static var _startContinuation: CheckedContinuation<Void, Never>?
    nonisolated(unsafe) private static var _deliveredChunkCount = 0
    nonisolated(unsafe) private static var _chunkWaiters: [(targetCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
    nonisolated(unsafe) private static var _isStartLoadingCalled = false
    nonisolated(unsafe) private static var _startExpectation: XCTestExpectation?
    nonisolated(unsafe) private static var _stopExpectation: XCTestExpectation?
    nonisolated(unsafe) private static var _stopContinuation: CheckedContinuation<Void, Never>?
    nonisolated(unsafe) private static var _isStopLoadingCalled = false
    nonisolated(unsafe) private static var _stopCallCount = 0
    nonisolated(unsafe) private static var _chunksDeliveredBeforeStop = 0
    nonisolated(unsafe) private static var _chunksDeliveredAfterStop = 0
    nonisolated(unsafe) private static var _bytesDeliveredBeforeStop = 0
    nonisolated(unsafe) private static var _bytesDeliveredAfterStop = 0

    private let instanceLock = NSLock()
    private var isStopped = false
    private var loaderTask: Task<Void, Never>?

    static var handler: Handler? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    static var streamHandler: StreamHandler? {
        get { lock.withLock { _streamHandler } }
        set { lock.withLock { _streamHandler = newValue } }
    }

    static var startExpectation: XCTestExpectation? {
        get { lock.withLock { _startExpectation } }
        set { lock.withLock { _startExpectation = newValue } }
    }

    static var stopExpectation: XCTestExpectation? {
        get { lock.withLock { _stopExpectation } }
        set { lock.withLock { _stopExpectation = newValue } }
    }

    static var deliveredChunkCount: Int {
        lock.withLock { _deliveredChunkCount }
    }

    static var stopCallCount: Int {
        lock.withLock { _stopCallCount }
    }

    static var isStopLoadingCalled: Bool {
        lock.withLock { _isStopLoadingCalled }
    }

    static var chunksDeliveredBeforeStop: Int {
        lock.withLock { _chunksDeliveredBeforeStop }
    }

    static var chunksDeliveredAfterStop: Int {
        lock.withLock { _chunksDeliveredAfterStop }
    }

    static var bytesDeliveredBeforeStop: Int {
        lock.withLock { _bytesDeliveredBeforeStop }
    }

    static var bytesDeliveredAfterStop: Int {
        lock.withLock { _bytesDeliveredAfterStop }
    }

    static func reset() {
        let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            _handler = nil
            _streamHandler = nil
            _startContinuation?.resume()
            _startContinuation = nil
            let waiters = _chunkWaiters.map(\.continuation)
            _chunkWaiters.removeAll()
            _deliveredChunkCount = 0
            _isStartLoadingCalled = false
            _startExpectation = nil
            _stopExpectation = nil
            _stopContinuation?.resume()
            _stopContinuation = nil
            _isStopLoadingCalled = false
            _stopCallCount = 0
            _chunksDeliveredBeforeStop = 0
            _chunksDeliveredAfterStop = 0
            _bytesDeliveredBeforeStop = 0
            _bytesDeliveredAfterStop = 0
            return waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
    }

    static func recordStart() {
        let (cont, exp) = lock.withLock { () -> (CheckedContinuation<Void, Never>?, XCTestExpectation?) in
            _isStartLoadingCalled = true
            let c = _startContinuation
            _startContinuation = nil
            let e = _startExpectation
            return (c, e)
        }
        cont?.resume()
        exp?.fulfill()
    }

    static func waitForStart() async {
        let alreadyStarted = lock.withLock { _isStartLoadingCalled }
        if alreadyStarted { return }
        await withCheckedContinuation { continuation in
            lock.withLock {
                if _isStartLoadingCalled {
                    continuation.resume()
                } else {
                    _startContinuation = continuation
                }
            }
        }
    }

    static func recordChunkDelivered() {
        let waitersToResume = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            _deliveredChunkCount += 1
            var toResume: [CheckedContinuation<Void, Never>] = []
            _chunkWaiters.removeAll { waiter in
                if _deliveredChunkCount > waiter.targetCount {
                    toResume.append(waiter.continuation)
                    return true
                }
                return false
            }
            return toResume
        }
        for continuation in waitersToResume {
            continuation.resume()
        }
    }

    static func waitForChunk(after target: Int = 0) async {
        let alreadyDelivered = lock.withLock { _deliveredChunkCount > target }
        if alreadyDelivered { return }
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = lock.withLock { () -> Bool in
                if _deliveredChunkCount > target {
                    return true
                } else {
                    _chunkWaiters.append((targetCount: target, continuation: continuation))
                    return false
                }
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }

    static func waitForStop() async {
        let alreadyStopped = lock.withLock { _isStopLoadingCalled }
        if alreadyStopped { return }
        await withCheckedContinuation { continuation in
            lock.withLock {
                if _isStopLoadingCalled {
                    continuation.resume()
                } else {
                    _stopContinuation = continuation
                }
            }
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("mock.plc.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let (handler, streamHandler) = Self.lock.withLock {
            (Self._handler, Self._streamHandler)
        }

        guard handler != nil || streamHandler != nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let currentRequest = self.request
        let clientTransfer = UnsafeTransfer(value: self.client)
        let protoTransfer = UnsafeTransfer(value: self)

        if let streamHandler {
            do {
                let (response, stream) = try streamHandler(currentRequest)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                Self.recordStart()

                instanceLock.withLock {
                    loaderTask = Task.detached {
                        let proto = protoTransfer.value
                        for await chunk in stream {
                            let stoppedDuringStream = proto.instanceLock.withLock { proto.isStopped || Task.isCancelled }
                            guard !stoppedDuringStream else {
                                Self.lock.withLock {
                                    Self._chunksDeliveredAfterStop += 1
                                    Self._bytesDeliveredAfterStop += chunk.count
                                }
                                Self.recordChunkDelivered()
                                break
                            }
                            Self.lock.withLock {
                                Self._chunksDeliveredBeforeStop += 1
                                Self._bytesDeliveredBeforeStop += chunk.count
                            }
                            clientTransfer.value?.urlProtocol(proto, didLoad: chunk)
                            Self.recordChunkDelivered()
                        }

                        let stoppedAfterStream = proto.instanceLock.withLock { proto.isStopped || Task.isCancelled }
                        guard !stoppedAfterStream else { return }
                        clientTransfer.value?.urlProtocolDidFinishLoading(proto)
                    }
                }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        } else if let handler {
            instanceLock.withLock {
                loaderTask = Task.detached {
                    let proto = protoTransfer.value
                    do {
                        Self.recordStart()
                        let (response, data) = try await handler(currentRequest)
                        let stopped = proto.instanceLock.withLock { proto.isStopped || Task.isCancelled }
                        guard !stopped else { return }

                        clientTransfer.value?.urlProtocol(
                            proto,
                            didReceive: response,
                            cacheStoragePolicy: .notAllowed
                        )

                        let stoppedAfterResponse = proto.instanceLock.withLock { proto.isStopped || Task.isCancelled }
                        guard !stoppedAfterResponse else { return }

                        Self.lock.withLock {
                            Self._chunksDeliveredBeforeStop += 1
                            Self._bytesDeliveredBeforeStop += data.count
                        }
                        clientTransfer.value?.urlProtocol(proto, didLoad: data)
                        clientTransfer.value?.urlProtocolDidFinishLoading(proto)
                    } catch {
                        let stopped = proto.instanceLock.withLock { proto.isStopped || Task.isCancelled }
                        guard !stopped else { return }
                        clientTransfer.value?.urlProtocol(proto, didFailWithError: error)
                    }
                }
            }
        }
    }

    override func stopLoading() {
        let (exp, cont) = Self.lock.withLock { () -> (XCTestExpectation?, CheckedContinuation<Void, Never>?) in
            Self._stopCallCount += 1
            Self._isStopLoadingCalled = true
            let e = Self._stopExpectation
            let c = Self._stopContinuation
            Self._stopContinuation = nil
            return (e, c)
        }

        exp?.fulfill()
        cont?.resume()

        let taskToCancel = instanceLock.withLock { () -> Task<Void, Never>? in
            guard !isStopped else { return nil }
            isStopped = true
            let task = loaderTask
            loaderTask = nil
            return task
        }

        taskToCancel?.cancel()
    }
}
