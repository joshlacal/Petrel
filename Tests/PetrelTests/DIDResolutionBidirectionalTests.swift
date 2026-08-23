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

        await #expect(throws: (any Error).self) {
            try await resolver.resolveHandleToDID(handle: "alice.bsky.social")
        }
    }

    @Test("PDS selection selects by service id #atproto_pds")
    func pdsSelectionByServiceId() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:user1",
            "alsoKnownAs": ["at://user.bsky.social"],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "CustomServiceType",
                    "serviceEndpoint": "https://pds1.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:user1") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let pdsURL = try await resolver.resolveDIDToPDSURL(did: "did:plc:user1")
        #expect(pdsURL.absoluteString == "https://pds1.example.com")
    }

    @Test("PDS selection selects by type AtprotoPersonalDataServer")
    func pdsSelectionByType() async throws {
        DIDTestURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses([DIDTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["104.244.42.1"] }
        defer {
            DIDTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }

        let didDocJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:user2",
            "alsoKnownAs": ["at://user.bsky.social"],
            "service": [
                {
                    "id": "#custom_id",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds2.example.com"
                }
            ]
        }
        """

        DIDTestURLProtocol.installRoute(matching: "plc.directory/did:plc:user2") { _ in
            (200, Data(didDocJSON.utf8), ["Content-Type": "application/json"])
        }

        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let pdsURL = try await resolver.resolveDIDToPDSURL(did: "did:plc:user2")
        #expect(pdsURL.absoluteString == "https://pds2.example.com")
    }

    @Test("Disallowed TLD handles are rejected before network lookup")
    func disallowedTLDHandlesRejected() async throws {
        let networkService = NetworkService(baseURL: baseURL)
        let resolver = await DIDResolutionService(networkService: networkService)

        let disallowedHandles = [
            "alice.local",
            "bob.arpa",
            "charlie.onion",
            "dan.test",
            "eve.internal",
            "frank.localhost",
            "grace.invalid",
            "heidi.example",
            "ivan.alt",
        ]

        for handle in disallowedHandles {
            await #expect(throws: (any Error).self, "Handle should be rejected: \(handle)") {
                try await resolver.resolveHandleToDID(handle: handle)
            }
        }
    }
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
