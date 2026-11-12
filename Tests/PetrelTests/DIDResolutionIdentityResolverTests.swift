import Foundation
@testable import Petrel
import PetrelCrypto
import Testing

/// DID resolution, verified identities and caching, against a mocked DNS resolver and a mocked
/// HTTP transport. Nothing here touches the network or process-wide state.
@Suite("IdentityResolver: DID resolution, verified identity and cache")
struct DIDResolutionIdentityResolverTests {
    private let alice = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let bob = "did:plc:7iza6de2dwap2sbkpav7c6c6"
    private let handle = "alice.example.com"

    private func fixtures() -> (MockIdentityHTTP, MockIdentityDNS) {
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: [handle]))
        http.on("\(handle)/.well-known/atproto-did", status: 404, body: "")
        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        return (http, dns)
    }

    // MARK: did:plc

    @Test("did:plc is fetched from the PLC directory, without following redirects")
    func plcDocument() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let document = try await resolver.resolveDIDDocument(alice)

        #expect(document.id == alice)
        let request = try #require(http.requests.first)
        #expect(request.url.absoluteString == "https://plc.directory/\(alice)")
        #expect(!request.followsRedirects)
        #expect(request.accept.contains("application/did+ld+json"))
        #expect(request.maximumResponseBytes == 256 * 1024)
    }

    @Test("The PLC directory is configurable, including a base path")
    func configurablePLCDirectory() async throws {
        let http = MockIdentityHTTP()
        http.on("plc.mirror.example.net", body: IdentityFixtures.document(did: alice))
        let directory = try #require(URL(string: "https://plc.mirror.example.net/directory/"))
        let resolver = IdentityResolver.forTesting(
            http: http, dns: MockIdentityDNS(), options: .init(plcDirectoryURL: directory)
        )

        _ = try await resolver.resolveDIDDocument(alice)

        #expect(http.requests.map(\.url.absoluteString) == ["https://plc.mirror.example.net/directory/\(alice)"])
        #expect(http.requestCount(containing: "plc.directory") == 0)
    }

    @Test("A DID is one path segment of the directory URL: a percent sign cannot smuggle a path")
    func plcDIDIsPercentEncoded() async throws {
        let http = MockIdentityHTTP()
        let did = "did:plc:abc%2F..%2Fexport"
        http.on("plc.directory", body: IdentityFixtures.document(did: did))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        _ = try await resolver.resolveDIDDocument(did)

        #expect(http.requests.map(\.url.absoluteString) == ["https://plc.directory/did:plc:abc%252F..%252Fexport"])
    }

    @Test("PLC statuses: 404 is not found, 410 is tombstoned, anything else is an unexpected status")
    func plcStatuses() async throws {
        let http = MockIdentityHTTP()
        http.on("plc.directory/did:plc:missing", status: 404, body: "")
        http.on("plc.directory/did:plc:gone", status: 410, body: "")
        http.on("plc.directory/did:plc:broken", status: 502, body: "")
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        await #expect(throws: IdentityError.didNotFound("did:plc:missing")) {
            try await resolver.resolveDIDDocument("did:plc:missing")
        }
        await #expect(throws: IdentityError.didTombstoned("did:plc:gone")) {
            try await resolver.resolveDIDDocument("did:plc:gone")
        }
        await #expect(
            throws: IdentityError.unexpectedStatus(url: "https://plc.directory/did:plc:broken", statusCode: 502)
        ) {
            try await resolver.resolveDIDDocument("did:plc:broken")
        }
    }

    // MARK: did:web

    @Test("A hostname-level did:web is fetched from https://<host>/.well-known/did.json, without redirects")
    func webDocument() async throws {
        let http = MockIdentityHTTP()
        let did = "did:web:identity.example.com"
        http.on("identity.example.com", body: IdentityFixtures.document(did: did))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        let document = try await resolver.resolveDIDDocument(did)

        #expect(document.id == did)
        #expect(http.requests.map(\.url.absoluteString) == ["https://identity.example.com/.well-known/did.json"])
        #expect(http.requests.allSatisfy { !$0.followsRedirects })
    }

    @Test("did:web:localhost, with a port, resolves over http only when development identifiers are allowed")
    func webLocalhost() async throws {
        let http = MockIdentityHTTP()
        let did = "did:web:localhost%3A2583"
        http.on("localhost:2583", body: IdentityFixtures.document(did: did))

        let production = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())
        await #expect(throws: IdentityError.invalidDIDWeb(did: did, reason: .developmentHostNotAllowed)) {
            try await production.resolveDIDDocument(did)
        }
        #expect(http.requests.isEmpty)

        let development = IdentityResolver.forTesting(
            http: http, dns: MockIdentityDNS(), options: .init(allowsDevelopmentIdentifiers: true)
        )
        _ = try await development.resolveDIDDocument(did)
        #expect(http.requests.map(\.url.absoluteString) == ["http://localhost:2583/.well-known/did.json"])
    }

    @Test("A did:web host that answers 404 is not found; 410 has no special meaning outside PLC")
    func webStatuses() async throws {
        let http = MockIdentityHTTP()
        http.on("missing.example.com", status: 404, body: "")
        http.on("gone.example.com", status: 410, body: "")
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        await #expect(throws: IdentityError.didNotFound("did:web:missing.example.com")) {
            try await resolver.resolveDIDDocument("did:web:missing.example.com")
        }
        await #expect(
            throws: IdentityError.unexpectedStatus(url: "https://gone.example.com/.well-known/did.json", statusCode: 410)
        ) {
            try await resolver.resolveDIDDocument("did:web:gone.example.com")
        }
    }

    // MARK: Rejected before any request

    @Test("Unsupported methods and did:web forms AT Protocol does not allow are rejected without a request")
    func rejectedDIDs() async throws {
        let cases: [(did: String, error: IdentityError)] = [
            ("did:web:example.com:users:alice", .unsupportedDIDWebPath("did:web:example.com:users:alice")),
            ("did:web:example.com%3A8443", .invalidDIDWeb(did: "did:web:example.com%3A8443", reason: .portNotAllowed)),
            ("did:web:example.com%3a8443", .invalidDIDWeb(did: "did:web:example.com%3a8443", reason: .portNotAllowed)),
            ("did:web:blah.arpa", .invalidDIDWeb(did: "did:web:blah.arpa", reason: .reservedTopLevelDomain)),
            ("did:web:laptop.local", .invalidDIDWeb(did: "did:web:laptop.local", reason: .reservedTopLevelDomain)),
            ("did:web:dev.test", .invalidDIDWeb(did: "did:web:dev.test", reason: .developmentHostNotAllowed)),
            ("did:web:192.168.1.1", .invalidDIDWeb(did: "did:web:192.168.1.1", reason: .invalidHostname)),
            ("did:web:Example.com", .invalidDIDWeb(did: "did:web:Example.com", reason: .invalidHostname)),
            ("did:web:com", .invalidDIDWeb(did: "did:web:com", reason: .invalidHostname)),
            ("did:web:example.com%2Fpath", .invalidDIDWeb(did: "did:web:example.com%2Fpath", reason: .invalidHostname)),
            (
                "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N",
                .unsupportedDIDMethod(did: "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N", method: "key")
            ),
            ("did:example:123456789abcdefghi", .unsupportedDIDMethod(did: "did:example:123456789abcdefghi", method: "example")),
        ]
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        for testCase in cases {
            await #expect(throws: testCase.error, "\(testCase.did)") {
                try await resolver.resolveDIDDocument(testCase.did)
            }
            await #expect(throws: testCase.error, "\(testCase.did)") {
                try await resolver.resolveIdentity(testCase.did)
            }
        }
        #expect(http.requests.isEmpty)
        #expect(dns.queries.isEmpty)
    }

    @Test("Every invalid DID in the interop vectors is rejected as invalid syntax without a request")
    func invalidDIDVectors() async throws {
        let vectors = try IdentityFixtures.vectorLines("did_syntax_invalid")
            + ["did:plc:abc\n", "did:plc:abc\r\n", "did:plc:abc ", " did:plc:abc", "did:plc:abc\u{0B}"]
        #expect(vectors.count >= 20)
        let http = MockIdentityHTTP()
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        for vector in vectors {
            await #expect(throws: IdentityError.invalidDIDSyntax(vector), "\(vector.debugDescription)") {
                try await resolver.resolveDIDDocument(vector)
            }
        }
        #expect(http.requests.isEmpty)
    }

    @Test("Every valid DID in the interop vectors passes syntax; only plc and web are then resolved")
    func validDIDVectors() async throws {
        let vectors = try IdentityFixtures.vectorLines("did_syntax_valid")
        #expect(vectors.count >= 20)
        let http = MockIdentityHTTP()
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        for vector in vectors {
            do {
                _ = try await resolver.resolveDIDDocument(vector)
                Issue.record("\(vector) resolved against an empty test double")
            } catch let error as IdentityError {
                switch error {
                case .invalidDIDSyntax:
                    Issue.record("\(vector) is valid syntax")
                case let .unsupportedDIDMethod(_, method):
                    #expect(method != "plc" && method != "web", "\(vector)")
                case .transport:
                    #expect(vector.hasPrefix("did:plc:") || vector.hasPrefix("did:web:"), "\(vector)")
                case .invalidDIDWeb:
                    #expect(vector.hasPrefix("did:web:"), "\(vector)")
                default:
                    Issue.record("\(vector): unexpected \(error)")
                }
            }
        }
    }

    // MARK: Document checks

    @Test("A document whose id is not the requested DID is rejected")
    func documentIDMustMatch() async throws {
        let http = MockIdentityHTTP()
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: bob, handles: [handle]))
        http.on("impostor.example.com", body: IdentityFixtures.document(did: "did:web:victim.example.com"))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        await #expect(throws: IdentityError.documentIDMismatch(expected: alice, actual: bob)) {
            try await resolver.resolveDIDDocument(alice)
        }
        await #expect(
            throws: IdentityError.documentIDMismatch(
                expected: "did:web:impostor.example.com", actual: "did:web:victim.example.com"
            )
        ) {
            try await resolver.resolveDIDDocument("did:web:impostor.example.com")
        }
        // Nothing was cached from the rejected answers.
        await #expect(throws: IdentityError.self) {
            try await resolver.resolveDIDToPDSURL(did: alice)
        }
    }

    @Test("A response that is not a DID document is rejected")
    func undecodableDocument() async throws {
        let http = MockIdentityHTTP()
        http.on("plc.directory/did:plc:html", body: "<html>maintenance</html>")
        http.on("plc.directory/did:plc:noid", body: #"{"service":[]}"#)
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        for did in ["did:plc:html", "did:plc:noid"] {
            do {
                _ = try await resolver.resolveDIDDocument(did)
                Issue.record("Expected \(did) to be rejected")
            } catch let IdentityError.invalidDIDDocument(rejected, _) {
                #expect(rejected == did)
            }
        }
    }

    // MARK: Verified identity

    @Test("A DID whose claimed handle resolves back to it has a verified handle")
    func verifiedIdentityFromDID() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let identity = try await resolver.resolveIdentity(alice)

        #expect(identity.did.didString() == alice)
        #expect(identity.handle.value == handle)
        #expect(identity.handleVerification == .verified)
        #expect(identity.isHandleVerified)
        #expect(identity.claimedHandle?.value == handle)
        #expect(identity.pdsEndpoint?.absoluteString == "https://pds.example.com")
    }

    @Test("A handle resolves to the same verified identity")
    func verifiedIdentityFromHandle() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let identity = try await resolver.resolveIdentity("Alice.Example.com")

        #expect(identity.did.didString() == alice)
        #expect(identity.handle.value == handle)
        #expect(identity.isHandleVerified)
    }

    @Test("A document that claims no handle yields handle.invalid")
    func noHandleClaimed() async throws {
        let http = MockIdentityHTTP()
        let dns = MockIdentityDNS()
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: []))
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let identity = try await resolver.resolveIdentity(alice)

        #expect(identity.handle.value == "handle.invalid")
        #expect(identity.handle.value == Handle.invalid)
        #expect(identity.handleVerification == .noHandleClaimed)
        #expect(!identity.isHandleVerified)
        #expect(identity.claimedHandle == nil)
        #expect(identity.pdsEndpoint != nil, "a broken handle does not break the account")
        #expect(dns.queries.isEmpty)
    }

    @Test("A claimed handle that resolves to another DID yields handle.invalid")
    func handleResolvesElsewhere() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", ["did=\(bob)"])
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let identity = try await resolver.resolveIdentity(alice)

        #expect(identity.handle.value == Handle.invalid)
        #expect(identity.handleVerification == .resolvesToDifferentDID(bob))
        #expect(identity.claimedHandle?.value == handle)

        let (handleString, pds) = try await resolver.resolveDIDToHandleAndPDSURL(did: alice)
        #expect(handleString == "handle.invalid")
        #expect(pds.absoluteString == "https://pds.example.com")
    }

    @Test("A claimed handle that does not resolve, or uses a reserved TLD, yields handle.invalid")
    func handleDoesNotResolve() async throws {
        let (http, dns) = fixtures()
        dns.set("_atproto.\(handle)", [])
        http.on("plc.directory/\(bob)", body: IdentityFixtures.document(did: bob, handles: ["bob.internal"]))
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let unresolvable = try await resolver.resolveIdentity(alice)
        #expect(unresolvable.handle.value == Handle.invalid)
        #expect(unresolvable.handleVerification == .doesNotResolve)

        let queriesBefore = dns.queries.count
        let reserved = try await resolver.resolveIdentity(bob)
        #expect(reserved.handle.value == Handle.invalid)
        #expect(reserved.handleVerification == .doesNotResolve)
        #expect(dns.queries.count == queriesBefore, "a reserved TLD is never looked up")
    }

    @Test("A handle lookup that failed in transit yields handle.invalid for that call only")
    func transientHandleFailureIsNotCached() async throws {
        let (http, dns) = fixtures()
        dns.fail("_atproto.\(handle)")
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let first = try await resolver.resolveIdentity(alice)
        #expect(first.handle.value == Handle.invalid)
        #expect(first.handleVerification == .lookupFailed)

        dns.set("_atproto.\(handle)", ["did=\(alice)"])
        let second = try await resolver.resolveIdentity(alice)
        #expect(second.handle.value == handle)
        #expect(second.handleVerification == .verified)
    }

    @Test("Cancellation is thrown as CancellationError, never turned into handle.invalid")
    func cancellationPropagates() async throws {
        let (http, dns) = fixtures()
        dns.delay("_atproto.\(handle)", seconds: 600)
        http.on("\(handle)/.well-known/atproto-did") { _ in
            try await Task.sleep(nanoseconds: 600_000_000_000)
            return IdentityHTTPResponse(statusCode: 404, body: Data())
        }
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)
        let alice = alice

        let task = Task { try await resolver.resolveIdentity(alice) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        switch await task.result {
        case .success:
            Issue.record("Expected CancellationError")
        case let .failure(error):
            #expect(error is CancellationError)
        }
    }

    @Test("Resolving a PDS endpoint does not look up the handle")
    func pdsLookupDoesNotResolveHandle() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        let pds = try await resolver.resolveDIDToPDSURL(did: alice)

        #expect(pds.absoluteString == "https://pds.example.com")
        #expect(dns.queries.isEmpty)
        #expect(http.requests.count == 1)
    }

    // MARK: Keys and services through the resolver

    @Test("resolveSigningKey returns the #atproto key, and a forced refresh sees a rotated key")
    func signingKeyAndRotation() async throws {
        let vectors = try JSONDecoder().decode([DIDKeyVector].self, from: IdentityFixtures.vectorJSON("w3c_didkey_K256"))
        let first = try #require(vectors.first)
        let second = try #require(vectors.dropFirst().first)
        func document(_ vector: DIDKeyVector) -> String {
            IdentityFixtures.document(did: alice, handles: [handle], verificationMethods: [[
                "id": "\(alice)#atproto", "type": "Multikey", "controller": alice,
                "publicKeyMultibase": String(vector.publicDidKey.dropFirst("did:key:".count)),
            ]])
        }
        let http = MockIdentityHTTP()
        http.on("plc.directory/\(alice)", body: document(first))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        let firstKey = try ATProtoJWTVerificationKey(PLCDIDKeyCodec.decode(first.publicDidKey))
        let secondKey = try ATProtoJWTVerificationKey(PLCDIDKeyCodec.decode(second.publicDidKey))
        let key = try await resolver.resolveSigningKey(for: alice)
        #expect(key == firstKey)

        // The account rotates its key. The cached document still answers...
        http.on("plc.directory/\(alice)", body: document(second))
        #expect(try await resolver.resolveSigningKey(for: alice) == key)
        // ...until the caller, after a failed signature check, asks for a fresh one.
        let rotated = try await resolver.resolveSigningKey(for: alice, forceRefresh: true)
        #expect(rotated == secondKey)
        #expect(rotated != key)
    }

    @Test("resolveSigningKey fails with a typed error when the document has no usable key")
    func missingSigningKey() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        await #expect(throws: IdentityError.missingSigningKey(did: alice)) {
            try await resolver.resolveSigningKey(for: alice)
        }
    }

    @Test("resolveServiceEndpoint finds a service by id and type")
    func serviceEndpoint() async throws {
        let http = MockIdentityHTTP()
        let labeler = "did:plc:ar7c4by46qjdydhdevvrndac"
        http.on("plc.directory/\(labeler)", body: IdentityFixtures.document(did: labeler, services: [
            ["id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://mod.example.com"],
        ]))
        let resolver = IdentityResolver.forTesting(http: http, dns: MockIdentityDNS())

        let endpoint = try await resolver.resolveServiceEndpoint(for: labeler, service: .labeler)
        #expect(endpoint.absoluteString == "https://mod.example.com")

        await #expect(throws: IdentityError.missingService(did: labeler, id: "#bsky_fg")) {
            try await resolver.resolveServiceEndpoint(for: labeler, service: .feedGenerator)
        }
    }

    // MARK: Cache

    @Test("A fresh entry is served without a request; an old one is fetched again")
    func cacheLifetime() async throws {
        let (http, dns) = fixtures()
        let clock = IdentityTestClock()
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(cachePolicy: IdentityCachePolicy(freshFor: 600, maximumAge: 3600)), clock: clock
        )

        _ = try await resolver.resolveDIDDocument(alice)
        _ = try await resolver.resolveDIDDocument(alice)
        #expect(http.requestCount(containing: "plc.directory") == 1)

        clock.advance(by: 599)
        _ = try await resolver.resolveDIDDocument(alice)
        #expect(http.requestCount(containing: "plc.directory") == 1)

        clock.advance(by: 2)
        _ = try await resolver.resolveDIDDocument(alice)
        #expect(http.requestCount(containing: "plc.directory") == 2)
    }

    @Test("A handle lookup is cached with the same lifetime")
    func handleCacheLifetime() async throws {
        let (http, dns) = fixtures()
        let clock = IdentityTestClock()
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(cachePolicy: IdentityCachePolicy(freshFor: 600, maximumAge: 3600)), clock: clock
        )

        _ = try await resolver.resolveHandle(handle)
        _ = try await resolver.resolveHandle(handle)
        #expect(dns.queries.count == 1)

        clock.advance(by: 601)
        _ = try await resolver.resolveHandle(handle)
        #expect(dns.queries.count == 2)
    }

    @Test("forceRefresh bypasses a fresh entry and replaces it")
    func forceRefresh() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        #expect(try await resolver.resolveDIDToPDSURL(did: alice).absoluteString == "https://pds.example.com")

        // The account migrates to another PDS.
        http.on("plc.directory/\(alice)", body: IdentityFixtures.document(did: alice, handles: [handle], pds: "https://new-pds.example.com"))
        #expect(try await resolver.resolveDIDToPDSURL(did: alice).absoluteString == "https://pds.example.com")

        let refreshed = try await resolver.resolveDIDDocument(alice, forceRefresh: true)
        #expect(refreshed.pdsEndpoint?.absoluteString == "https://new-pds.example.com")
        #expect(try await resolver.resolveDIDToPDSURL(did: alice).absoluteString == "https://new-pds.example.com")
        #expect(http.requestCount(containing: "plc.directory") == 2)

        _ = try await resolver.resolveHandle(handle)
        _ = try await resolver.resolveHandle(handle, forceRefresh: true)
        #expect(dns.queries.count == 2)
    }

    @Test("invalidate(did:), invalidate(handle:) and clearCache() drop entries")
    func invalidation() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns)

        _ = try await resolver.resolveHandle(handle)
        #expect(http.requestCount(containing: "plc.directory") == 1)
        #expect(dns.queries.count == 1)

        await resolver.invalidate(did: alice)
        _ = try await resolver.resolveHandle(handle)
        #expect(http.requestCount(containing: "plc.directory") == 2)
        #expect(dns.queries.count == 1, "the handle entry was not invalidated")

        await resolver.invalidate(handle: "Alice.Example.com")
        _ = try await resolver.resolveHandle(handle)
        #expect(http.requestCount(containing: "plc.directory") == 2)
        #expect(dns.queries.count == 2)

        await resolver.clearCache()
        _ = try await resolver.resolveHandle(handle)
        #expect(http.requestCount(containing: "plc.directory") == 3)
        #expect(dns.queries.count == 3)
    }

    @Test("A stale entry is served while the directory is unreachable, but never past its maximum age")
    func staleWhileUnreachable() async throws {
        let (http, dns) = fixtures()
        let clock = IdentityTestClock()
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(cachePolicy: IdentityCachePolicy(freshFor: 600, maximumAge: 3600)), clock: clock
        )
        _ = try await resolver.resolveDIDDocument(alice)

        http.fail("plc.directory/\(alice)")
        clock.advance(by: 1200)
        let stale = try await resolver.resolveDIDDocument(alice)
        #expect(stale.id == alice)
        #expect(http.requestCount(containing: "plc.directory") == 2, "a refresh was attempted first")

        // A caller that asks for a fresh document is not handed the stale one.
        await #expect(throws: IdentityError.self) {
            try await resolver.resolveDIDDocument(alice, forceRefresh: true)
        }

        clock.advance(by: 3600)
        await #expect(throws: IdentityError.self) {
            try await resolver.resolveDIDDocument(alice)
        }
    }

    @Test("A definite 'not found' is never answered from a stale entry and drops it")
    func definitiveAnswerDropsEntry() async throws {
        let (http, dns) = fixtures()
        let clock = IdentityTestClock()
        let resolver = IdentityResolver.forTesting(
            http: http, dns: dns,
            options: .init(cachePolicy: IdentityCachePolicy(freshFor: 600, maximumAge: 3600)), clock: clock
        )
        _ = try await resolver.resolveDIDDocument(alice)

        http.on("plc.directory/\(alice)", status: 410, body: "")
        clock.advance(by: 601)
        await #expect(throws: IdentityError.didTombstoned(alice)) {
            try await resolver.resolveDIDDocument(alice)
        }

        // The entry is gone, so an outage afterwards cannot bring the tombstoned DID back.
        http.fail("plc.directory/\(alice)")
        await #expect(throws: IdentityError.self) {
            try await resolver.resolveDIDDocument(alice)
        }
    }

    @Test("The disabled policy serves nothing from the cache")
    func disabledCache() async throws {
        let (http, dns) = fixtures()
        let resolver = IdentityResolver.forTesting(http: http, dns: dns, options: .init(timeout: IdentityResolver.Options.stubbed.timeout, cachePolicy: .disabled))

        _ = try await resolver.resolveDIDDocument(alice)
        _ = try await resolver.resolveDIDDocument(alice)

        #expect(http.requestCount(containing: "plc.directory") == 2)
    }

    @Test("A cache can be shared between resolvers through the IdentityCache protocol")
    func sharedCache() async throws {
        let (http, dns) = fixtures()
        let cache = InMemoryIdentityCache()
        let first = IdentityResolver.forTesting(http: http, dns: dns, cache: cache)
        _ = try await first.resolveHandle(handle)

        let silentHTTP = MockIdentityHTTP()
        let silentDNS = MockIdentityDNS()
        let second = IdentityResolver.forTesting(http: silentHTTP, dns: silentDNS, cache: cache)
        #expect(try await second.resolveHandle(handle).didString() == alice)
        #expect(silentHTTP.requests.isEmpty)
        #expect(silentDNS.queries.isEmpty)
    }

    @Test("A cached handle entry is still verified against the DID document when it is read")
    func cachedHandleIsVerifiedOnRead() async throws {
        let (http, dns) = fixtures()
        http.on("plc.directory/\(bob)", body: IdentityFixtures.document(did: bob, handles: ["bob.example.com"]))
        let cache = InMemoryIdentityCache()
        // A poisoned or outdated entry: the handle points at a DID that does not claim it.
        await cache.setDID(bob, forHandle: handle, storedAt: Date())
        let resolver = IdentityResolver.forTesting(http: http, dns: dns, cache: cache)

        await #expect(throws: IdentityError.handleNotClaimedByDID(handle: handle, did: bob)) {
            try await resolver.resolveHandle(handle)
        }
    }

    @Test("The in-memory cache is bounded")
    func boundedCache() async throws {
        let cache = InMemoryIdentityCache(capacity: 8)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0 ..< 100 {
            await cache.setDID("did:plc:entry\(index)", forHandle: "h\(index).example.com", storedAt: start.addingTimeInterval(Double(index)))
        }
        var kept = 0
        for index in 0 ..< 100 {
            if await cache.did(forHandle: "h\(index).example.com") != nil {
                kept += 1
            }
        }
        #expect(kept <= 8)
        #expect(await cache.did(forHandle: "h99.example.com")?.value == "did:plc:entry99", "the newest entry is kept")
        #expect(await cache.did(forHandle: "h0.example.com") == nil, "the oldest entry is dropped")
    }
}

private struct DIDKeyVector: Decodable {
    let publicDidKey: String
}
