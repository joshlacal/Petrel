//
//  SpaceHostResolverTests.swift
//  PetrelTests
//

import Foundation
import Testing
@testable import Petrel

private final class DummyDIDResolver: DIDResolving, @unchecked Sendable {
    func resolveHandleToDID(handle: String) async throws -> String { "did:plc:123" }
    func resolveDIDToPDSURL(did: String) async throws -> URL { URL(string: "https://pds.test")! }
    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) { ("user.test", URL(string: "https://pds.test")!) }
}

private final class ResolverMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handlers: [String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]

    static func setHandler(forHost host: String, _ handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        if let handler {
            handlers[host] = handler
        } else {
            handlers.removeValue(forKey: host)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let host = request.url?.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        ResolverMockURLProtocol.lock.lock()
        let handler = ResolverMockURLProtocol.handlers[host]
        ResolverMockURLProtocol.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("SpaceAuthorityEndpoints extraction", .serialized)
struct SpaceHostResolverTests {
    func doc(
        services: [(id: String, endpoint: String)],
        verificationMethods: [String]
    ) -> DIDDocument {
        DIDDocument(
            context: ["https://www.w3.org/ns/did/v1"],
            id: "did:example:123",
            alsoKnownAs: [],
            verificationMethod: verificationMethods.map { vm in
                VerificationMethod(
                    id: vm,
                    type: "Multikey",
                    controller: "did:example:123",
                    publicKeyMultibase: "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
                )
            },
            service: services.map { s in
                Service(
                    id: s.id,
                    type: s.id.contains("space_host") ? "AtprotoSpaceHost" : "AtprotoPersonalDataServer",
                    serviceEndpoint: s.endpoint
                )
            }
        )
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ResolverMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test("prefers #atproto_space_host over #atproto_pds")
    func prefersSpaceHost() throws {
        let d = doc(
            services: [
                ("#atproto_pds", "https://pds.test"),
                ("#atproto_space_host", "https://space.test")
            ],
            verificationMethods: ["#atproto"]
        )
        let e = try SpaceAuthorityEndpoints.extract(from: d)
        #expect(e.spaceHost == URL(string: "https://space.test")!)
    }

    @Test("falls back to #atproto_pds when no space host")
    func fallsBackToPDS() throws {
        let d = doc(
            services: [("#atproto_pds", "https://pds.test")],
            verificationMethods: ["#atproto"]
        )
        #expect(try SpaceAuthorityEndpoints.extract(from: d).spaceHost == URL(string: "https://pds.test")!)
    }

    @Test("prefers #atproto_space key, falls back to #atproto")
    func keyFallback() throws {
        let withKey = doc(
            services: [("#atproto_pds", "https://pds.test")],
            verificationMethods: ["#atproto", "#atproto_space"]
        )
        #expect(try SpaceAuthorityEndpoints.extract(from: withKey).signingKeyFragment == "#atproto_space")

        let without = doc(
            services: [("#atproto_pds", "https://pds.test")],
            verificationMethods: ["#atproto"]
        )
        #expect(try SpaceAuthorityEndpoints.extract(from: without).signingKeyFragment == "#atproto")
    }

    @Test("handles full-id service and verification method matching")
    func fullIdMatching() throws {
        let d = doc(
            services: [
                ("did:plc:123#atproto_pds", "https://pds.test"),
                ("did:plc:123#atproto_space_host", "https://space.test")
            ],
            verificationMethods: ["did:plc:123#atproto", "did:plc:123#atproto_space"]
        )
        let e = try SpaceAuthorityEndpoints.extract(from: d)
        #expect(e.spaceHost == URL(string: "https://space.test")!)
        #expect(e.signingKeyFragment == "#atproto_space")
    }

    @Test("throws when document has no usable service endpoint")
    func throwsOnNoHost() {
        let d = doc(services: [], verificationMethods: ["#atproto"])
        #expect(throws: (any Error).self) { try SpaceAuthorityEndpoints.extract(from: d) }
    }
    @Test("falls back to #atproto_pds when #atproto_space_host endpoint is unparseable")
    func fallbackWhenSpaceHostEndpointIsInvalid() throws {
        let d = doc(
            services: [
                ("#atproto_space_host", ""),
                ("#atproto_pds", "https://pds.test")
            ],
            verificationMethods: ["#atproto"]
        )
        let e = try SpaceAuthorityEndpoints.extract(from: d)
        #expect(e.spaceHost == URL(string: "https://pds.test")!)
    }

    @Test("throws when service matches type but not #atproto_space_host or #atproto_pds id")
    func throwsOnTypeMatchOnly() {
        let d = DIDDocument(
            context: ["https://www.w3.org/ns/did/v1"],
            id: "did:example:123",
            alsoKnownAs: [],
            verificationMethod: [
                VerificationMethod(
                    id: "#atproto",
                    type: "Multikey",
                    controller: "did:example:123",
                    publicKeyMultibase: "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
                )
            ],
            service: [
                Service(
                    id: "#custom_service",
                    type: "AtprotoPersonalDataServer",
                    serviceEndpoint: "https://pds.test"
                )
            ]
        )
        #expect(throws: (any Error).self) { try SpaceAuthorityEndpoints.extract(from: d) }
    }

    @Test("throws when service has bare id without fragment hash")
    func throwsOnBareIdWithoutHash() {
        let d = doc(
            services: [("atproto_pds", "https://pds.test")],
            verificationMethods: ["#atproto"]
        )
        #expect(throws: (any Error).self) { try SpaceAuthorityEndpoints.extract(from: d) }
    }

    @Test("SpaceHostResolver public init with didResolver only compiles and constructs")
    func publicInitSignature() {
        let resolver = SpaceHostResolver(didResolver: DummyDIDResolver())
        _ = resolver
    }

    @Test("SpaceHostResolver actor resolves did:plc DID document over network")
    func actorResolvesPLCDID() async throws {
        let didJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:plc:test12345",
            "alsoKnownAs": ["at://user.test"],
            "verificationMethod": [
                {
                    "id": "did:plc:test12345#atproto_space",
                    "type": "Multikey",
                    "controller": "did:plc:test12345",
                    "publicKeyMultibase": "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
                }
            ],
            "service": [
                {
                    "id": "#atproto_space_host",
                    "type": "AtprotoSpaceHost",
                    "serviceEndpoint": "https://space.plc.test"
                }
            ]
        }
        """
        ResolverMockURLProtocol.setHandler(forHost: "plc.directory") { request in
            #expect(request.url?.absoluteString == "https://plc.directory/did:plc:test12345")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(didJSON.utf8))
        }
        defer { ResolverMockURLProtocol.setHandler(forHost: "plc.directory", nil) }

        let resolver = SpaceHostResolver(
            didResolver: DummyDIDResolver(),
            urlSession: makeMockSession()
        )
        let endpoints = try await resolver.resolve(authorityDID: "did:plc:test12345")
        #expect(endpoints.spaceHost == URL(string: "https://space.plc.test")!)
        #expect(endpoints.signingKeyFragment == "#atproto_space")
    }

    @Test("SpaceHostResolver actor resolves did:web DID document over network")
    func actorResolvesWebDID() async throws {
        let didJSON = """
        {
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": "did:web:example.com",
            "alsoKnownAs": [],
            "verificationMethod": [
                {
                    "id": "did:web:example.com#atproto",
                    "type": "Multikey",
                    "controller": "did:web:example.com",
                    "publicKeyMultibase": "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
                }
            ],
            "service": [
                {
                    "id": "#atproto_pds",
                    "type": "AtprotoPersonalDataServer",
                    "serviceEndpoint": "https://pds.example.com"
                }
            ]
        }
        """
        ResolverMockURLProtocol.setHandler(forHost: "example.com") { request in
            #expect(request.url?.absoluteString == "https://example.com/.well-known/did.json")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(didJSON.utf8))
        }
        defer { ResolverMockURLProtocol.setHandler(forHost: "example.com", nil) }

        let resolver = SpaceHostResolver(
            didResolver: DummyDIDResolver(),
            urlSession: makeMockSession()
        )
        let endpoints = try await resolver.resolve(authorityDID: "did:web:example.com")
        #expect(endpoints.spaceHost == URL(string: "https://pds.example.com")!)
        #expect(endpoints.signingKeyFragment == "#atproto")
    }
}
