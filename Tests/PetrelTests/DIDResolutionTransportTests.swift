import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// The default transport (`HardenedIdentityHTTPTransport`) and the `ATProtoClient` entry points,
/// end to end: real `URLSession` requests answered by a `URLProtocol` stub, host addresses
/// supplied by the test, and DNS TXT answers supplied by the test.
@Suite("Identity over the default transport and the public client", .serialized)
struct DIDResolutionTransportTests {
    private let alice = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let bob = "did:plc:7iza6de2dwap2sbkpav7c6c6"
    private let handle = "alice.handle-host.com"

    /// Runs `body` with the stub transport installed. `addresses` maps hosts to the addresses
    /// they resolve to (any other host resolves to a public address); `txt` maps DNS names to
    /// TXT values.
    private func withStubs<T>(
        addresses: [String: [String]] = [:],
        txt: [String: [String]] = [:],
        _ body: @escaping () async throws -> T
    ) async throws -> T {
        try await withSerializedStorageOverrideTest {
            IdentityStubURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses([IdentityStubURLProtocol.self])
            NetworkService.dnsResolverOverride = { host in addresses[host] ?? ["104.244.42.1"] }
            SystemIdentityDNSResolver.testOverride.withLock { $0 = { name in txt[name] ?? [] } }
            defer {
                IdentityStubURLProtocol.reset()
                NetworkService.setNetworkTestProtocolClasses(nil)
                NetworkService.dnsResolverOverride = nil
                SystemIdentityDNSResolver.testOverride.withLock { $0 = nil }
            }
            return try await body()
        }
    }

    private func respond(_ fragment: String, status: Int = 200, _ body: String, headers: [String: String] = [:]) {
        IdentityStubURLProtocol.install(fragment, .response(status: status, body: Data(body.utf8), headers: headers))
    }

    // MARK: Default transport

    @Test("A handle resolves through the default transport over DNS TXT, and over HTTPS well-known")
    func resolvesThroughDefaultTransport() async throws {
        try await withStubs(txt: ["_atproto.dns.handle-host.com": ["did=\(bob)"]]) {
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            respond("plc.directory/\(bob)", IdentityFixtures.document(did: bob, handles: ["dns.handle-host.com"]))
            respond("\(handle)/.well-known/atproto-did", "\(alice)\n", headers: ["Content-Type": "text/plain"])
            let resolver = IdentityResolver()

            let resolved1 = try await resolver.resolveHandle(handle).didString()
            #expect(resolved1 == alice)
            let resolved2 = try await resolver.resolveHandle("dns.handle-host.com").didString()
            #expect(resolved2 == bob)
        }
    }

    @Test("Requests carry an Accept header and nothing that identifies an account")
    func requestsAreAnonymous() async throws {
        try await withStubs {
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            respond("\(handle)/.well-known/atproto-did", alice)
            let resolver = IdentityResolver(httpTransport: HardenedIdentityHTTPTransport(userAgent: "ExampleApp/1.0"))

            _ = try await resolver.resolveHandle(handle)

            let requests = IdentityStubURLProtocol.requests()
            #expect(requests.count == 2)
            for request in requests {
                let names = Set(request.headers.keys.map { $0.lowercased() })
                #expect(names.isDisjoint(with: ["authorization", "dpop", "cookie", "proxy-authorization", "atproto-proxy", "atproto-accept-labelers", "x-requested-with"]))
                #expect(!names.contains { $0.hasPrefix("x-") })
                #expect(request.headers.first { $0.key.lowercased() == "user-agent" }?.value == "ExampleApp/1.0")
                #expect(request.method == "GET")
            }
            #expect(requests.first { $0.url.host == handle }?.headers["Accept"] == "text/plain")
            #expect(requests.first { $0.url.host == "plc.directory" }?.headers["Accept"]?.contains("application/did+ld+json") == true)
        }
    }

    @Test("Hosts that resolve to private, loopback or link-local addresses are never contacted")
    func privateAddressesAreBlocked() async throws {
        let addresses = [
            "intranet.corp-site.com": ["10.1.2.3"],
            "metadata.corp-site.com": ["169.254.169.254"],
            "loop.corp-site.com": ["127.0.0.1"],
            "v6.corp-site.com": ["::1"],
            "mixed.corp-site.com": ["104.244.42.1", "192.168.1.10"],
        ]
        try await withStubs(addresses: addresses) {
            let resolver = IdentityResolver()
            for host in addresses.keys.sorted() {
                respond("\(host)/.well-known/did.json", IdentityFixtures.document(did: "did:web:\(host)"))
                respond("\(host)/.well-known/atproto-did", alice)

                await #expect(
                    throws: IdentityError.blockedByNetworkPolicy(url: "https://\(host)/.well-known/did.json"), "\(host)"
                ) {
                    try await resolver.resolveDIDDocument("did:web:\(host)")
                }
                await #expect(throws: IdentityError.self, "\(host)") {
                    try await resolver.resolveHandle(host)
                }
            }
            #expect(IdentityStubURLProtocol.requests().isEmpty, "no request may leave for a private address")
        }
    }

    @Test("A response larger than the limit is refused")
    func oversizedResponsesAreRefused() async throws {
        try await withStubs {
            let padding = String(repeating: " ", count: 8192)
            respond("big.handle-host.com/.well-known/did.json", IdentityFixtures.document(did: "did:web:big.handle-host.com") + padding)
            respond("\(handle)/.well-known/atproto-did", alice + padding)
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            let resolver = IdentityResolver(options: .init(maximumDocumentBytes: 2048))

            await #expect(
                throws: IdentityError.responseTooLarge(url: "https://big.handle-host.com/.well-known/did.json")
            ) {
                try await resolver.resolveDIDDocument("did:web:big.handle-host.com")
            }
            // The well-known body is capped at 4096 bytes whatever the document limit is.
            do {
                _ = try await resolver.resolveHandle(handle)
                Issue.record("Expected the oversized well-known body to be refused")
            } catch let IdentityError.handleLookupFailed(failedHandle, _) {
                #expect(failedHandle == handle)
            }
        }
    }

    // No wall-clock bound: the stub never answers, so the only way out is the configured
    // timeout, which `timedOut` names. The time limit only stops a regression from hanging
    // the run.
    @Test("A host that never answers is abandoned at the timeout", .timeLimit(.minutes(5)))
    func timeoutIsEnforced() async throws {
        try await withStubs {
            IdentityStubURLProtocol.install("slow.handle-host.com", .hang)
            let resolver = IdentityResolver(options: .init(timeout: 0.3))

            await #expect(throws: IdentityError.timedOut("GET https://slow.handle-host.com/.well-known/did.json")) {
                try await resolver.resolveDIDDocument("did:web:slow.handle-host.com")
            }
        }
    }

    #if canImport(Darwin)
        // The stub drives redirects through URLProtocol's redirect callback, which only Apple's
        // Foundation implements for custom protocols.

        @Test("A handle's well-known lookup follows a redirect to another host")
        func wellKnownFollowsRedirect() async throws {
            try await withStubs {
                IdentityStubURLProtocol.install(
                    "\(handle)/.well-known/atproto-did",
                    .redirect(to: "https://cdn.handle-host.com/.well-known/atproto-did")
                )
                respond("cdn.handle-host.com/.well-known/atproto-did", alice)
                respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
                let resolver = IdentityResolver()

                let resolved3 = try await resolver.resolveHandle(handle).didString()
                #expect(resolved3 == alice)
            }
        }

        @Test("Redirects are bounded: the sixth hop is not followed")
        func redirectHopLimit() async throws {
            try await withStubs {
                IdentityStubURLProtocol.install(
                    "\(handle)/.well-known/atproto-did", .redirect(to: "https://hop1.handle-host.com/next")
                )
                for hop in 1 ... 7 {
                    IdentityStubURLProtocol.install(
                        "hop\(hop).handle-host.com/next", .redirect(to: "https://hop\(hop + 1).handle-host.com/next")
                    )
                }
                respond("hop8.handle-host.com/next", alice)
                respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
                let resolver = IdentityResolver()

                await #expect(throws: IdentityError.self) {
                    try await resolver.resolveHandle(handle)
                }
                let hosts = IdentityStubURLProtocol.requests().compactMap(\.url.host)
                #expect(hosts.contains("hop5.handle-host.com"), "five redirects are followed")
                #expect(!hosts.contains("hop6.handle-host.com"), "the sixth redirect is not followed")
                #expect(!hosts.contains("hop8.handle-host.com"))
            }
        }

        @Test("A redirect to a host with a private address is not followed")
        func redirectToPrivateAddressIsBlocked() async throws {
            try await withStubs(addresses: ["intranet.corp-site.com": ["10.1.2.3"]]) {
                IdentityStubURLProtocol.install(
                    "\(handle)/.well-known/atproto-did",
                    .redirect(to: "https://intranet.corp-site.com/.well-known/atproto-did")
                )
                respond("intranet.corp-site.com", alice)
                respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
                let resolver = IdentityResolver()

                await #expect(throws: IdentityError.self) {
                    try await resolver.resolveHandle(handle)
                }
                #expect(!IdentityStubURLProtocol.requests().contains { $0.url.host == "intranet.corp-site.com" })
            }
        }

        @Test("A DID document fetch does not follow redirects")
        func didDocumentDoesNotFollowRedirects() async throws {
            try await withStubs {
                IdentityStubURLProtocol.install(
                    "moved.handle-host.com/.well-known/did.json",
                    .redirect(to: "https://elsewhere.handle-host.com/.well-known/did.json")
                )
                respond("elsewhere.handle-host.com", IdentityFixtures.document(did: "did:web:moved.handle-host.com"))
                IdentityStubURLProtocol.install(
                    "plc.directory/\(alice)", .redirect(to: "https://elsewhere.handle-host.com/plc")
                )
                let resolver = IdentityResolver()

                await #expect(throws: IdentityError.self) {
                    try await resolver.resolveDIDDocument("did:web:moved.handle-host.com")
                }
                await #expect(throws: IdentityError.self) {
                    try await resolver.resolveDIDDocument(alice)
                }
                #expect(!IdentityStubURLProtocol.requests().contains { $0.url.host == "elsewhere.handle-host.com" })
            }
        }
    #endif

    // MARK: Public client path

    @Test("ATProtoClient: the client's service resolves the handle, and the answer is verified")
    func clientResolvesViaItsService() async throws {
        try await withStubs {
            respond(
                "appview.service-host.com/xrpc/com.atproto.identity.resolveHandle",
                #"{"did":"\#(alice)"}"#, headers: ["Content-Type": "application/json"]
            )
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            let client = await ATProtoClient(baseURL: URL(string: "https://appview.service-host.com")!)

            let resolved4 = try await client.resolveHandleToDID(handle: handle)
            #expect(resolved4 == alice)
            let resolved5 = try await client.resolveDIDToPDSURL(did: alice).absoluteString
            #expect(resolved5 == "https://pds.example.com")

            let identity = try await client.resolveIdentity(alice)
            #expect(identity.handle.value == handle)
            #expect(identity.isHandleVerified)
            let resolved6 = try await client.resolveDIDDocument(alice).id
            #expect(resolved6 == alice)
            #expect(client.identityResolver != nil)
        }
    }

    @Test("ATProtoClient: when its service does not know the handle, DNS TXT answers")
    func clientFallsBackToDNS() async throws {
        try await withStubs(txt: ["_atproto.\(handle)": ["did=\(alice)"]]) {
            respond(
                "appview.service-host.com/xrpc/com.atproto.identity.resolveHandle", status: 400,
                #"{"error":"InvalidRequest","message":"Unable to resolve handle"}"#,
                headers: ["Content-Type": "application/json"]
            )
            respond("\(handle)/.well-known/atproto-did", status: 404, "")
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            let client = await ATProtoClient(baseURL: URL(string: "https://appview.service-host.com")!)

            let resolved7 = try await client.resolveHandleToDID(handle: handle)
            #expect(resolved7 == alice)
        }
    }

    @Test("ATProtoClient: when its service does not know the handle, HTTPS well-known answers")
    func clientFallsBackToWellKnown() async throws {
        try await withStubs {
            respond("appview.service-host.com/xrpc/com.atproto.identity.resolveHandle", status: 400, #"{"error":"InvalidRequest"}"#)
            respond("\(handle)/.well-known/atproto-did", " \(alice) \n")
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            let client = await ATProtoClient(baseURL: URL(string: "https://appview.service-host.com")!)

            let resolved8 = try await client.resolveHandleToDID(handle: handle)
            #expect(resolved8 == alice)
            // The handle host was asked without the client's XRPC headers.
            let wellKnown = try #require(IdentityStubURLProtocol.requests().first { $0.url.host == handle })
            let names = Set(wellKnown.headers.keys.map { $0.lowercased() })
            #expect(names.isDisjoint(with: ["authorization", "atproto-proxy", "atproto-accept-labelers", "x-requested-with"]))
        }
    }

    @Test("ATProtoClient: DNS is preferred when DNS and HTTPS disagree, and conflicting TXT records fail")
    func clientConflicts() async throws {
        let txt = [
            "_atproto.\(handle)": ["did=\(bob)"],
            "_atproto.split.handle-host.com": ["did=\(alice)", "did=\(bob)"],
        ]
        try await withStubs(txt: txt) {
            respond("appview.service-host.com/xrpc/com.atproto.identity.resolveHandle", status: 400, #"{"error":"InvalidRequest"}"#)
            respond("\(handle)/.well-known/atproto-did", alice)
            respond("split.handle-host.com/.well-known/atproto-did", alice)
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            respond("plc.directory/\(bob)", IdentityFixtures.document(did: bob, handles: [handle]))
            let client = await ATProtoClient(baseURL: URL(string: "https://appview.service-host.com")!)

            let resolved9 = try await client.resolveHandleToDID(handle: handle)
            #expect(resolved9 == bob)
            await #expect(
                throws: IdentityError.handleAmbiguous(handle: "split.handle-host.com", dids: [alice, bob])
            ) {
                try await client.resolveHandleToDID(handle: "split.handle-host.com")
            }
        }
    }

    @Test("ATProtoClient: negative cases surface as typed errors and reserved TLDs cause no request")
    func clientNegativeCases() async throws {
        try await withStubs {
            respond("appview.service-host.com/xrpc/com.atproto.identity.resolveHandle", status: 400, #"{"error":"InvalidRequest"}"#)
            respond("\(handle)/.well-known/atproto-did", status: 404, "")
            respond("unclaimed.handle-host.com/.well-known/atproto-did", alice)
            respond("plc.directory/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            respond("plc.directory/did:plc:mismatch", IdentityFixtures.document(did: alice))
            respond("plc.directory/did:plc:missing", status: 404, "")
            let client = await ATProtoClient(baseURL: URL(string: "https://appview.service-host.com")!)

            await #expect(throws: IdentityError.reservedHandleTLD("laptop.local")) {
                try await client.resolveHandleToDID(handle: "laptop.local")
            }
            await #expect(throws: IdentityError.invalidHandleSyntax("not a handle")) {
                try await client.resolveHandleToDID(handle: "not a handle")
            }
            #expect(IdentityStubURLProtocol.requests().isEmpty, "rejected handles must not reach any host")

            await #expect(throws: IdentityError.handleNotFound(handle)) {
                try await client.resolveHandleToDID(handle: handle)
            }
            await #expect(throws: IdentityError.handleNotClaimedByDID(handle: "unclaimed.handle-host.com", did: alice)) {
                try await client.resolveHandleToDID(handle: "unclaimed.handle-host.com")
            }
            await #expect(throws: IdentityError.documentIDMismatch(expected: "did:plc:mismatch", actual: alice)) {
                try await client.resolveDIDToPDSURL(did: "did:plc:mismatch")
            }
            await #expect(throws: IdentityError.didNotFound("did:plc:missing")) {
                try await client.resolveDIDToPDSURL(did: "did:plc:missing")
            }
            await #expect(throws: IdentityError.unsupportedDIDWebPath("did:web:handle-host.com:u:alice")) {
                try await client.resolveDIDToPDSURL(did: "did:web:handle-host.com:u:alice")
            }
            await #expect(throws: IdentityError.unsupportedDIDMethod(did: "did:key:zabc", method: "key")) {
                try await client.resolveDIDToPDSURL(did: "did:key:zabc")
            }
        }
    }

    @Test("ATProtoClient: an IdentityResolver passed as didResolver replaces the service-first lookup")
    func clientWithInjectedResolver() async throws {
        try await withStubs {
            respond("plc.internal-directory.net/\(alice)", IdentityFixtures.document(did: alice, handles: [handle]))
            respond("\(handle)/.well-known/atproto-did", status: 404, "")
            let dns = MockIdentityDNS()
            dns.set("_atproto.\(handle)", ["did=\(alice)"])
            let resolver = IdentityResolver(
                options: .init(plcDirectoryURL: URL(string: "https://plc.internal-directory.net")!),
                dnsResolver: dns
            )
            let client = await ATProtoClient(
                baseURL: URL(string: "https://appview.service-host.com")!, didResolver: resolver
            )

            let resolved10 = try await client.resolveHandleToDID(handle: handle)
            #expect(resolved10 == alice)
            #expect(client.identityResolver === resolver)
            #expect(dns.queries == ["_atproto.\(handle)"])
            let hosts = Set(IdentityStubURLProtocol.requests().compactMap(\.url.host))
            #expect(!hosts.contains("appview.service-host.com"), "the direct strategy does not ask the client's service")
            #expect(!hosts.contains("plc.directory"))
        }
    }
}

// MARK: - URLProtocol stub

private final class IdentityStubURLProtocol: URLProtocol {
    enum Behavior: Sendable {
        case response(status: Int, body: Data, headers: [String: String])
        case redirect(to: String)
        case hang
    }

    struct Recorded: Sendable {
        let url: URL
        let method: String
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var routes: [(fragment: String, behavior: Behavior)] = []
    private nonisolated(unsafe) static var recorded: [Recorded] = []

    static func install(_ fragment: String, _ behavior: Behavior) {
        lock.withLock { routes.insert((fragment, behavior), at: 0) }
    }

    static func reset() {
        lock.withLock {
            routes.removeAll()
            recorded.removeAll()
        }
    }

    static func requests() -> [Recorded] {
        lock.withLock { recorded }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let behavior = Self.lock.withLock { () -> Behavior? in
            Self.recorded.append(Recorded(
                url: url, method: request.httpMethod ?? "GET", headers: request.allHTTPHeaderFields ?? [:]
            ))
            return Self.routes.first { url.absoluteString.contains($0.fragment) }?.behavior
        }
        switch behavior {
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
        case .hang:
            break
        case let .response(status, body, headers):
            deliver(url: url, status: status, body: body, headers: headers)
        case let .redirect(target):
            guard let targetURL = URL(string: target),
                  let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target])
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: targetURL), redirectResponse: response)
            // A session that follows the redirect stops this load. One that declines it keeps
            // the load open and expects the 302 itself as the response.
            let pending = UncheckedBox(self)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                pending.value.deliverDeclinedRedirect(response)
            }
        }
    }

    private struct UncheckedBox: @unchecked Sendable {
        let value: IdentityStubURLProtocol
        init(_ value: IdentityStubURLProtocol) { self.value = value }
    }

    private let stateLock = NSLock()
    private var stopped = false

    private func deliverDeclinedRedirect(_ response: HTTPURLResponse) {
        guard !stateLock.withLock({ stopped }) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func deliver(url: URL, status: Int, body: Data, headers: [String: String]) {
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stateLock.withLock { stopped = true }
    }
}

#if compiler(<6.2)
    extension IdentityStubURLProtocol: @unchecked Sendable {}
#endif
