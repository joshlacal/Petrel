import Foundation
@testable import Petrel
import Testing

/// Handle resolution per the handle specification, against a mocked DNS resolver and a mocked
/// HTTP transport. Nothing here touches the network or process-wide state.
@Suite("IdentityResolver: handle resolution")
struct DIDResolutionHandleTests {
    private let alice = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let bob = "did:plc:7iza6de2dwap2sbkpav7c6c6"
    private let handle = "alice.example.com"

    private func fixtures() -> (MockIdentityHTTP, MockIdentityDNS) {
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: [handle]))
        http.on("plc.directory/\(bob)", body: IdentityFixtures.document(did: bob, handles: [handle]))
        // Unless a test says otherwise, the handle's web server has no well-known file.
        http.on("\(handle)/.well-known/atproto-did", status: 404, body: "not found")
        return (http, dns)
    }

    // MARK: DNS TXT

    @Test("A did= TXT record at _atproto.<handle> resolves the handle")
    func dnsTXTResolves() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let did = try await resolver.resolveHandle(handle)

        #expect(did.didString() == alice)
        #expect(dns.queries == ["_atproto.\(handle)"])
    }

    @Test("Letter case is normalized before the DNS name is built")
    func handleIsLowercased() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let did = try await resolver.resolveHandle("Alice.Example.COM")

        #expect(did.didString() == alice)
        #expect(dns.queries == ["_atproto.\(handle)"])
    }

    @Test("TXT values that do not start with did= are ignored")
    func txtWithoutPrefixIsIgnored() async throws {
        let (http, dns) = fixtures()
        // A bare DID and unrelated records must not count; the HTTPS method answers instead.
        dns.set("_atproto.\(handle)", [bob, "v=spf1 -all", "did:\(bob)"])
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let did = try await resolver.resolveHandle(handle)

        #expect(did.didString() == alice)
    }

    @Test("Several did= records naming different DIDs fail resolution, even when HTTPS would answer")
    func conflictingTXTRecordsFail() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)", "did=\(bob)"])
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.handleAmbiguous(handle: handle, dids: [alice, bob])) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("The same did= record published twice is one answer")
    func repeatedTXTRecordIsNotAConflict() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)", "did=\(alice)"])
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveHandle(handle).didString() == alice)
    }

    @Test("A handle too long for a DNS query is resolved over HTTPS only")
    func longHandleSkipsDNS() async throws {
        let long = "shoooort" + String(repeating: ".loooooooooooooooooooooooooong", count: 7) + ".a-longer-handle-host.example.com"
        #expect(long.utf8.count <= 253)
        #expect("_atproto.\(long)".utf8.count > 253)
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        http.on("\(long)/.well-known/atproto-did", body: alice)
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: [long]))
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveHandle(long).didString() == alice)
        #expect(dns.queries.isEmpty)
    }

    // MARK: HTTPS well-known

    @Test("GET https://<handle>/.well-known/atproto-did resolves the handle")
    func wellKnownResolves() async throws {
        let (http, dns) = fixtures()
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveHandle(handle).didString() == alice)

        let request = try #require(http.requests.first { $0.url.path == "/.well-known/atproto-did" })
        #expect(request.url.absoluteString == "https://\(handle)/.well-known/atproto-did")
        #expect(request.followsRedirects, "the handle specification allows redirects for this method")
        #expect(request.maximumResponseBytes <= 4096)
        #expect(request.timeout == 5)
    }

    @Test("The well-known body is the DID alone; any 2xx is accepted and surrounding whitespace is stripped")
    func wellKnownBodies() async throws {
        let cases: [(status: Int, body: String, resolves: Bool)] = [
            (200, alice, true),
            (200, "  \(alice)\r\n", true),
            (203, "\(alice)\n", true),
            // A fragment or query would be dropped by the directory request and so pass the
            // bidirectional check with a string that is not a DID.
            (200, "\(alice)#atproto", false),
            (200, "\(alice)?x=1", false),
            (200, "\(alice)\n\(bob)", false),
            (200, "did=\(alice)", false),
            (200, "<html>hello</html>", false),
            (200, "", false),
            (404, alice, false),
            (403, alice, false),
        ]
        for testCase in cases {
            let (http, dns) = fixtures()
            http.on("\(handle)/.well-known/atproto-did", status: testCase.status, body: testCase.body)
            let resolver = IdentityResolver.forTesting(http: http, dns: dns)
            let label = "\(testCase.status) \(testCase.body.debugDescription)"

            if testCase.resolves {
                #expect(try await resolver.resolveHandle(handle).didString() == alice, "\(label)")
            } else {
                await #expect(throws: IdentityError.handleNotFound(handle), "\(label)") {
                    try await resolver.resolveHandle(handle)
                }
            }
        }
    }

    // MARK: Both methods

    @Test("When DNS and HTTPS name different DIDs, DNS is preferred")
    func dnsIsPreferredOnConflict() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(bob)"])
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveHandle(handle).didString() == bob)
    }

    @Test("With the reject policy, DNS and HTTPS naming different DIDs is an ambiguous handle")
    func conflictCanBeRejected() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(bob)"])
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(handleConflictPolicy: .reject)
        )

        await #expect(throws: IdentityError.handleAmbiguous(handle: handle, dids: [bob, alice])) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("With the reject policy, DNS and HTTPS that agree resolve")
    func agreementUnderRejectPolicy() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(handleConflictPolicy: .reject)
        )

        #expect(try await resolver.resolveHandle(handle).didString() == alice)
    }

    @Test("No record and no well-known file is a handle that does not exist")
    func notFound() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.handleNotFound(handle)) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("A lookup that failed in transit is reported as a failure, not as a missing handle")
    func transientFailureIsNotNotFound() async throws {
        let (http, dns) = fixtures()
        dns.fail("_atproto.\(handle)")
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        do {
            _ = try await resolver.resolveHandle(handle)
            Issue.record("Expected a lookup failure")
        } catch let IdentityError.handleLookupFailed(failedHandle, _) {
            #expect(failedHandle == handle)
        }

        // The same for an HTTPS failure while DNS has no record.
        let (http2, dns2) = fixtures()
        http2.fail("\(handle)/.well-known/atproto-did")
        let resolver2 = IdentityResolver.forTesting(http: http2, dns: dns2)
        do {
            _ = try await resolver2.resolveHandle(handle)
            Issue.record("Expected a lookup failure")
        } catch let IdentityError.handleLookupFailed(failedHandle, _) {
            #expect(failedHandle == handle)
        }

        // And for a server error from the handle's web server.
        let (http3, dns3) = fixtures()
        http3.on("\(handle)/.well-known/atproto-did", status: 503, body: "")
        let resolver3 = IdentityResolver.forTesting(http: http3, dns: dns3)
        do {
            _ = try await resolver3.resolveHandle(handle)
            Issue.record("Expected a lookup failure")
        } catch let IdentityError.handleLookupFailed(failedHandle, _) {
            #expect(failedHandle == handle)
        }
    }

    @Test("A DNS failure does not stop the HTTPS method from answering")
    func httpsAnswersWhenDNSFails() async throws {
        let (http, dns) = fixtures()
        dns.fail("_atproto.\(handle)")
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveHandle(handle).didString() == alice)
    }

    // No wall-clock bound: under CI load a fixed elapsed limit flakes. The DNS query never
    // answers on its own, so resolution can only return once the deadline abandons it; the
    // assertion is that it was cancelled and HTTPS supplied the answer. The time limit only
    // stops a regression from hanging the run.
    @Test(
        "A DNS query that never answers is abandoned at the timeout and HTTPS answers",
        .timeLimit(.minutes(1))
    )
    func dnsTimeoutDoesNotBlockResolution() async throws {
        let (http, dns) = fixtures()
        dns.hang("_atproto.\(handle)")
        http.on("\(handle)/.well-known/atproto-did", body: alice)
        let resolver = IdentityResolver.forTesting(http: http, dns: dns, options: .init(timeout: 0.2))

        let did = try await resolver.resolveHandle(handle)

        #expect(did.didString() == alice)
        #expect(dns.queries == ["_atproto.\(handle)"])
        #expect(http.requestCount(containing: "\(handle)/.well-known/atproto-did") == 1)
        // The deadline cancels the abandoned query rather than leaving it running.
        try await dns.waitUntilCancelled("_atproto.\(handle)")
        #expect(dns.cancelledQueries == ["_atproto.\(handle)"])
    }

    // MARK: Restrictions that apply before any request

    @Test(
        "Reserved top-level domains fail immediately, without any DNS or HTTP request",
        arguments: [
            "blah.arpa", "handle.invalid", "dev.localhost", "john.test", "expyuzz4wqqyqhjn.onion",
            "laptop.local", "service.internal", "user.example", "name.alt", "LAPTOP.LOCAL",
        ]
    )
    func reservedTLDsFailImmediately(reserved: String) async throws {
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.reservedHandleTLD(reserved.lowercased())) {
            try await resolver.resolveHandle(reserved)
        }
        await #expect(throws: IdentityError.reservedHandleTLD(reserved.lowercased())) {
            try await resolver.resolveIdentity(reserved)
        }
        #expect(dns.queries.isEmpty)
        #expect(http.requests.isEmpty)
    }

    @Test(".test handles resolve only when development identifiers are allowed")
    func testTLDNeedsDevelopmentMode() async throws {
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        dns.set("_atproto.john.test", ["did=\(alice)"])
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: ["john.test"]))
        http.on("john.test/.well-known/atproto-did", status: 404, body: "")
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(allowsDevelopmentIdentifiers: true)
        )

        #expect(try await resolver.resolveHandle("john.test").didString() == alice)

        // Development mode does not lift the reserved domains.
        await #expect(throws: IdentityError.reservedHandleTLD("laptop.local")) {
            try await resolver.resolveHandle("laptop.local")
        }
    }

    @Test("Every invalid handle in the interop vectors is rejected as invalid syntax without a request")
    func invalidHandleVectors() async throws {
        let vectors = try IdentityFixtures.vectorLines("handle_syntax_invalid")
        #expect(vectors.count >= 40)
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        for vector in vectors {
            await #expect(throws: IdentityError.invalidHandleSyntax(vector), "\(vector.debugDescription)") {
                try await resolver.resolveHandle(vector)
            }
        }
        #expect(dns.queries.isEmpty)
        #expect(http.requests.isEmpty)
    }

    @Test("Every valid handle in the interop vectors passes syntax and reaches the TLD check or a lookup")
    func validHandleVectors() async throws {
        let vectors = try IdentityFixtures.vectorLines("handle_syntax_valid")
        #expect(vectors.count >= 60)
        let reserved = [".alt", ".arpa", ".example", ".internal", ".invalid", ".local", ".localhost", ".onion", ".test"]
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        for vector in vectors {
            let normalized = vector.lowercased()
            let isReserved = reserved.contains { normalized.hasSuffix($0) }
            do {
                _ = try await resolver.resolveHandle(vector)
                Issue.record("\(vector) resolved against empty test doubles")
            } catch let error as IdentityError {
                if isReserved {
                    #expect(error == .reservedHandleTLD(normalized), "\(vector)")
                } else if case .handleLookupFailed = error {
                    // Syntax and TLD checks passed and a lookup was attempted.
                } else {
                    Issue.record("\(vector): unexpected \(error)")
                }
            }
        }
    }

    // MARK: Bidirectional verification

    @Test("A handle that points at a DID whose document does not claim it is not resolved")
    func handleNotClaimedByDocument() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: []))
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: alice)) {
            try await resolver.resolveHandle(handle)
        }
        // The rejection is not a cache artefact: asking again rejects again.
        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: alice)) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("A failed verification is not cached: the next attempt sees corrected records")
    func failedVerificationIsNotCached() async throws {
        let (http, dns) = fixtures()
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: ["other.example.com"]))
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: alice)) {
            try await resolver.resolveHandle(handle)
        }

        // The owner points the record at the DID that does claim the handle.
        dns.set("_atproto.\(handle)", ["did=\(bob)"])
        #expect(try await resolver.resolveHandle(handle).didString() == bob)
        #expect(dns.queries.count == 2)
    }

    @Test("Only the first valid handle in alsoKnownAs is the claimed handle")
    func onlyFirstHandleCounts() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        http.on(
            "plc.directory/\(alice)",
            body: IdentityFixtures.document(did: alice, handles: ["primary.example.com", handle])
        )
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: alice)) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("A handle whose DID cannot be resolved does not resolve")
    func handleWithUnresolvableDID() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=did:plc:doesnotexist"])
        http.on("plc.directory/did:plc:doesnotexist", status: 404, body: "")
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.didNotFound("did:plc:doesnotexist")) {
            try await resolver.resolveHandle(handle)
        }
    }

    // MARK: Delegated lookup

    @Test("The xrpc strategy asks com.atproto.identity.resolveHandle and still verifies the answer")
    func xrpcStrategy() async throws {
        let (http, dns) = fixtures()
        http.on("resolver.example.net/xrpc/com.atproto.identity.resolveHandle", body: #"{"did":"\#(alice)"}"#)
        let service = try #require(URL(string: "https://resolver.example.net"))
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(handleStrategy: .xrpc(service: service, fallbackToDirect: false))
        )

        #expect(try await resolver.resolveHandle(handle).didString() == alice)

        let request = try #require(http.requests.first { $0.url.host == "resolver.example.net" })
        #expect(
            request.url.absoluteString
                == "https://resolver.example.net/xrpc/com.atproto.identity.resolveHandle?handle=\(handle)"
        )
        #expect(!request.followsRedirects)
        #expect(dns.queries.isEmpty)
        #expect(http.requestCount(containing: ".well-known/atproto-did") == 0)

        // The service's word is not enough: the DID document must claim the handle.
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: ["someone-else.example.com"]))
        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: alice)) {
            try await resolver.resolveHandle(handle, forceRefresh: true)
        }
    }

    @Test("The xrpc strategy reports an unknown handle, or falls back to the handle's domain when asked to")
    func xrpcStrategyFallback() async throws {
        let (http, dns) = fixtures()
        http.on(
            "resolver.example.net/xrpc/com.atproto.identity.resolveHandle",
            status: 400, body: #"{"error":"InvalidRequest","message":"Unable to resolve handle"}"#
        )
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        let service = try #require(URL(string: "https://resolver.example.net"))

        let strict = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(handleStrategy: .xrpc(service: service, fallbackToDirect: false))
        )
        await #expect(throws: IdentityError.handleNotFound(handle)) {
            try await strict.resolveHandle(handle)
        }
        #expect(dns.queries.isEmpty)

        let falling = IdentityResolver.forTesting(
            http: http, dns: dns, options: .init(handleStrategy: .xrpc(service: service, fallbackToDirect: true))
        )
        #expect(try await falling.resolveHandle(handle).didString() == alice)
        #expect(dns.queries == ["_atproto.\(handle)"])
    }

    @Test("A custom lookup is used, its answer is validated as a DID, and it is verified like any other")
    func customStrategy() async throws {
        let (http, dns) = fixtures()
        let alice = alice
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(handleStrategy: .custom(lookup: { _ in alice }, fallbackToDirect: false))
        )
        #expect(try await resolver.resolveHandle(handle).didString() == alice)

        let broken = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(handleStrategy: .custom(lookup: { _ in "not-a-did" }, fallbackToDirect: false))
        )
        do {
            _ = try await broken.resolveHandle(handle)
            Issue.record("Expected a lookup failure")
        } catch let IdentityError.handleLookupFailed(failedHandle, _) {
            #expect(failedHandle == handle)
        }
    }
}
