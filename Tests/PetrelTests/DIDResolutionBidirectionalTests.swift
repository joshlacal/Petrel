import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

@Suite("DID Resolution and Bidirectional Identity Tests", .serialized)
struct DIDResolutionBidirectionalTests {
    private let baseURL = URL(string: "https://bsky.social")!

    @Test("Bidirectional resolution succeeds when alsoKnownAs contains handle")
    func bidirectionalResolutionSuccess() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        // Mock resolveHandle response
        let resolveHandleJSON = #"{"did":"did:plc:alice123"}"#
        // Mock PLC directory DID doc
        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:alice123",
            "alsoKnownAs": ["at://alice.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(resolveHandleJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:alice123") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let did = try await resolver.resolveHandleToDID(handle: "alice.bsky.social")
        #expect(did == "did:plc:alice123")

        let (handle, pdsURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:alice123")
        #expect(handle == "alice.bsky.social")
        #expect(pdsURL.absoluteString == "https://pds.example.com")
    }

    @Test("Bidirectional resolution fails when alsoKnownAs does not match handle")
    func bidirectionalResolutionFailureMismatch() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        let resolveHandleJSON = #"{"did":"did:plc:alice123"}"#
        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:alice123",
            "alsoKnownAs": ["at://bob.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(resolveHandleJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:alice123") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        // First call: rejects because DID document alsoKnownAs does not assert handle
        await #expect(throws: (any Error).self) {
            try await resolver.resolveHandleToDID(handle: "alice.bsky.social")
        }

        // Second call: must ALSO reject (premature caching must not serve hostile DID)
        await #expect(throws: (any Error).self) {
            try await resolver.resolveHandleToDID(handle: "alice.bsky.social")
        }
    }

    @Test("PDS selection requires matching service id AND type AtprotoPersonalDataServer")
    func pdsSelectionRequiresIdAndType() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        // 1. Valid: id is #atproto_pds and type is AtprotoPersonalDataServer
        let validDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:valid1",
            "alsoKnownAs": ["at://user1.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds1.example.com"
                }
            ]
        }
        """

        // 2. Valid: id is did#atproto_pds and type is AtprotoPersonalDataServer
        let validPrefixedDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:valid2",
            "alsoKnownAs": ["at://user2.bsky.social"],
            "service": [
                {
                    "id": "did:plc:valid2#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds2.example.com"
                }
            ]
        }
        """

        // 3. Invalid: id is #atproto_pds but type is NOT AtprotoPersonalDataServer
        let wrongTypeDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:wrongtype",
            "alsoKnownAs": ["at://user3.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "CustomServiceType",
                    "serviceEndpoint": "https://pds3.example.com"
                }
            ]
        }
        """

        // 4. Invalid: type is AtprotoPersonalDataServer but id is unrelated (#custom_id)
        let wrongIdDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:wrongid",
            "alsoKnownAs": ["at://user4.bsky.social"],
            "service": [
                {
                    "id": "#custom_id",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds4.example.com"
                }
            ]
        }
        """

        // 5. Invalid: ambiguous multiple PDS services
        let multipleDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:multiple",
            "alsoKnownAs": ["at://user5.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds5a.example.com"
                },
                {
                    "id": "did:plc:multiple#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds5b.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:valid1") { _ in
            (200, Data(validDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:valid2") { _ in
            (200, Data(validPrefixedDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:wrongtype") { _ in
            (200, Data(wrongTypeDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:wrongid") { _ in
            (200, Data(wrongIdDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:multiple") { _ in
            (200, Data(multipleDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { request in
            guard let url = request.url?.absoluteString else {
                return (404, Data(), [:])
            }
            if url.contains("user1.bsky.social") {
                return (200, Data(#"{"did":"did:plc:valid1"}"#.utf8), ["Content-Type": "application/json"])
            } else if url.contains("user2.bsky.social") {
                return (200, Data(#"{"did":"did:plc:valid2"}"#.utf8), ["Content-Type": "application/json"])
            }
            return (404, Data(), [:])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let pds1 = try await resolver.resolveDIDToPDSURL(did: "did:plc:valid1")
        #expect(pds1.absoluteString == "https://pds1.example.com")

        let pds2 = try await resolver.resolveDIDToPDSURL(did: "did:plc:valid2")
        #expect(pds2.absoluteString == "https://pds2.example.com")

        await #expect(throws: (any Error).self) {
            try await resolver.resolveDIDToPDSURL(did: "did:plc:wrongtype")
        }

        await #expect(throws: (any Error).self) {
            try await resolver.resolveDIDToPDSURL(did: "did:plc:wrongid")
        }

        await #expect(throws: (any Error).self) {
            try await resolver.resolveDIDToPDSURL(did: "did:plc:multiple")
        }
    }

    @Test("Reverse DID to handle resolution degrades to handle.invalid on round-trip mismatch without blocking PDS")
    func reverseResolutionFailureMismatch() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        // Attacker DID doc asserts alsoKnownAs: attacker.bsky.social
        let attackerDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:attacker123",
            "alsoKnownAs": ["at://attacker.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """
        // But resolveHandle for attacker.bsky.social returns a DIFFERENT DID (e.g. did:plc:victim456)
        let resolveHandleJSON = #"{"did":"did:plc:victim456"}"#
        let victimDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:victim456",
            "alsoKnownAs": ["at://attacker.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://victim-pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:attacker123") { _ in
            (200, Data(attackerDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:victim456") { _ in
            (200, Data(victimDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(resolveHandleJSON.utf8), ["Content-Type": "application/json"])
        }
        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        // PDS URL still returned, handle degrades to handle.invalid
        let (handle, pdsURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:attacker123")
        #expect(handle == Handle.invalid)
        #expect(pdsURL.absoluteString == "https://pds.example.com")

        let directPDSURL = try await resolver.resolveDIDToPDSURL(did: "did:plc:attacker123")
        #expect(directPDSURL.absoluteString == "https://pds.example.com")
    }

    @Test("Reverse DID to handle resolution degrades to handle.invalid when asserted handle cannot be resolved without blocking PDS")
    func reverseResolutionFailureUnresolvable() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        DIDResolutionService.dnsTXTResolverOverride = { _ in [] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
            DIDResolutionService.dnsTXTResolverOverride = nil
        }

        // DID doc asserts an unresolvable handle
        let unresolvableDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:unresolvable123",
            "alsoKnownAs": ["at://nonexistent.handle.test"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:unresolvable123") { _ in
            (200, Data(unresolvableDocJSON.utf8), ["Content-Type": "application/json"])
        }
        // resolveHandle fails with 404
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (404, Data("HandleNotFound".utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        // PDS URL still returned, handle degrades to handle.invalid
        let (handle, pdsURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:unresolvable123")
        #expect(handle == Handle.invalid)
        #expect(pdsURL.absoluteString == "https://pds.example.com")

        let directPDSURL = try await resolver.resolveDIDToPDSURL(did: "did:plc:unresolvable123")
        #expect(directPDSURL.absoluteString == "https://pds.example.com")
    }

    @Test("did:web rejects path injection and invalid percent-encoding")
    func didWebAntiInjection() async throws {
        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let invalidDIDs = [
            "did:web:example.com%2F..%2Fx",
            "did:web:example.com:path%2Ftraversal",
            "did:web:example.com:..:x",
            "did:web:example.com:.",
            "did:web:example.com:port%3Aabc",
            "did:web:example.com:path?evil",
            "did:web:example.com:path#evil",
            "did:web:example.com:path evil",
            "did:web:example.com:path\u{1F600}",
        ]
        for did in invalidDIDs {
            await #expect(throws: (any Error).self, "Invalid did:web should be rejected: \(did)") {
                try await resolver.resolveDIDToPDSURL(did: did)
            }
        }
    }

    @Test("did:web preserves percent-encoded path segments and does not interpret %3F as query delimiter")
    func didWebPercentEncodedPathPreserved() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        let docJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:web:example.com:path%3Fevil",
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        let receivedBox = TestBox<URL?>(nil)
        DIDTestURLProtocol.installRoute(matching: "example.com") { request in
            receivedBox.set(request.url)
            return (200, Data(docJSON.utf8), ["Content-Type": "application/json"])
        }
        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let pds = try await resolver.resolveDIDToPDSURL(did: "did:web:example.com:path%3Fevil")
        #expect(pds.absoluteString == "https://pds.example.com")
        let receivedURL = receivedBox.get()
        #expect(receivedURL != nil)
        #expect(receivedURL?.query == nil)
        #expect(receivedURL?.absoluteString.contains("path%3Fevil/did.json") == true)
        #expect(receivedURL?.absoluteString != "https://example.com/path?evil/did.json")
    }

    @Test("extractCandidateHandle skips bare-hostname aliases and selects first valid at:// handle URI")
    func extractCandidateHandleSkipsBareHostnames() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        let docJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:alice123",
            "alsoKnownAs": ["example.com", "https://example.com/user", "at://invalid..handle", "at://alice.example.com"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:alice123") { _ in
            (200, Data(docJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { request in
            guard let url = request.url?.absoluteString, url.contains("alice.example.com") else {
                return (404, Data(), [:])
            }
            return (200, Data(#"{"did":"did:plc:alice123"}"#.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let (handle, pdsURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:alice123")
        #expect(handle == "alice.example.com")
        #expect(pdsURL.absoluteString == "https://pds.example.com")
    }

    @Test("Cancellation propagates and is never swallowed or converted to handle.invalid")
    func cancellationPropagates() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        DIDResolutionService.dnsTXTResolverOverride = { _ in [] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
            DIDResolutionService.dnsTXTResolverOverride = nil
        }

        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:cancelled123",
            "alsoKnownAs": ["at://slow.handle.test"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:cancelled123") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(#"{"did":"did:plc:cancelled123"}"#.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let task = Task {
            try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:cancelled123")
        }
        task.cancel()

        let result = await task.result
        switch result {
        case .success:
            Issue.record("Expected cancellation to throw CancellationError, but got success")
        case let .failure(error):
            #expect(error is CancellationError)
        }
    }

    @Test("Transient reverse resolution failure is not cached as invalid and retries on subsequent call")
    func transientFailureIsNotCachedAndRetriesReverseCheck() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        DIDResolutionService.dnsTXTResolverOverride = { _ in [] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
            DIDResolutionService.dnsTXTResolverOverride = nil
        }

        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:transient123",
            "alsoKnownAs": ["at://transient.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:transient123") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }

        // First call: resolveHandle endpoint fails with transient 500 error
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (500, Data("InternalServerError".utf8), ["Content-Type": "text/plain"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        // First call returns PDS URL and degrades handle to handle.invalid for THIS call
        let (firstHandle, firstPDSURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:transient123")
        #expect(firstHandle == Handle.invalid)
        #expect(firstPDSURL.absoluteString == "https://pds.example.com")

        // Second call: resolveHandle endpoint recovers with 200 OK and matching DID
        DIDTestURLProtocol.reset()
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:transient123") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(#"{"did":"did:plc:transient123"}"#.utf8), ["Content-Type": "application/json"])
        }

        // Second call retries reverse check and returns verified handle!
        let (secondHandle, secondPDSURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:transient123")
        #expect(secondHandle == "transient.bsky.social")
        #expect(secondPDSURL.absoluteString == "https://pds.example.com")

        // Third call: wipes routes to prove verified result is now in cache
        DIDTestURLProtocol.reset()
        let (thirdHandle, thirdPDSURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:transient123")
        #expect(thirdHandle == "transient.bsky.social")
        #expect(thirdPDSURL.absoluteString == "https://pds.example.com")
    }

    @Test("Definitive reverse resolution mismatch is cached as invalid")
    func definitiveMismatchIsCachedAsInvalid() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        DIDResolutionService.dnsTXTResolverOverride = { _ in [] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
            DIDResolutionService.dnsTXTResolverOverride = nil
        }

        let attackerDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:cachedattacker123",
            "alsoKnownAs": ["at://attacker.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """
        // Reverse check succeeds with 200 and valid victim doc but returns a different DID (victim456)
        let resolveHandleJSON = #"{"did":"did:plc:victim456"}"#
        let victimDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:victim456",
            "alsoKnownAs": ["at://attacker.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://victim-pds.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:cachedattacker123") { _ in
            (200, Data(attackerDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:victim456") { _ in
            (200, Data(victimDocJSON.utf8), ["Content-Type": "application/json"])
        }
        DIDTestURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
            (200, Data(resolveHandleJSON.utf8), ["Content-Type": "application/json"])
        }
        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        // First call: reverse check definitive mismatch -> returns handle.invalid
        let (firstHandle, firstPDSURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:cachedattacker123")
        #expect(firstHandle == Handle.invalid)
        #expect(firstPDSURL.absoluteString == "https://pds.example.com")

        // Wipe all routes so any new network request would fail
        DIDTestURLProtocol.reset()

        // Second call: served from cache as handle.invalid without making network calls
        let (secondHandle, secondPDSURL) = try await resolver.resolveDIDToHandleAndPDSURL(did: "did:plc:cachedattacker123")
        #expect(secondHandle == Handle.invalid)
        #expect(secondPDSURL.absoluteString == "https://pds.example.com")
    }
}

private final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    func get() -> T { lock.withLock { value } }
    func set(_ newValue: T) { lock.withLock { value = newValue } }
}

// MARK: - Mock URLProtocol for DID Tests
private final class DIDTestURLProtocol: URLProtocol, @unchecked Sendable {
    typealias RouteHandler = @Sendable (URLRequest) -> (statusCode: Int, body: Data, headers: [String: String])

    private static let lock = NSLock()
    private nonisolated(unsafe) static var routes: [(matcher: String, handler: RouteHandler)] = []

    static func installRoute(matching: String, handler: @escaping RouteHandler) {
        lock.withLock {
            routes.append((matcher: matching, handler: handler))
        }
    }

    static func reset() {
        lock.withLock {
            routes.removeAll()
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.lock.withLock { () -> RouteHandler? in
            guard let urlString = request.url?.absoluteString else { return nil }
            return Self.routes.first(where: { urlString.contains($0.matcher) })?.handler
        }

        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        let (statusCode, body, headers) = handler(request)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
