import Foundation
import Petrel
import PetrelLexicon
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// An identity DNS resolver that answers from a table and records every name it was asked.
private final class TableDNS: IdentityDNSResolver, @unchecked Sendable {
    struct Unreachable: Error {}

    private let lock = NSLock()
    private let records: [String: [String]]
    private let failing: Set<String>
    private var recorded: [String] = []

    init(_ records: [String: [String]] = [:], failing: Set<String> = []) {
        self.records = records
        self.failing = failing
    }

    var queries: [String] {
        lock.withLock { recorded }
    }

    func queryTXT(name: String) async throws -> [String] {
        lock.withLock { recorded.append(name) }
        if failing.contains(name) { throw Unreachable() }
        return records[name] ?? []
    }
}

/// An identity HTTP transport that answers from a route table and records every request.
private final class TableHTTP: IdentityHTTPTransport, @unchecked Sendable {
    struct ConnectionReset: Error {}

    private let lock = NSLock()
    private var routes: [(prefix: String, status: Int, body: String)] = []
    private var recorded: [IdentityHTTPRequest] = []

    var requests: [IdentityHTTPRequest] {
        lock.withLock { recorded }
    }

    /// Answers requests whose URL starts with `prefix`.
    func on(_ prefix: String, status: Int = 200, body: String) {
        lock.withLock { routes.append((prefix, status, body)) }
    }

    func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
        let route = lock.withLock { () -> (prefix: String, status: Int, body: String)? in
            recorded.append(request)
            return routes.first { request.url.absoluteString.hasPrefix($0.prefix) }
        }
        guard let route else { throw ConnectionReset() }
        return IdentityHTTPResponse(statusCode: route.status, body: Data(route.body.utf8))
    }
}

@Suite("Lexicon resolution over the identity layer")
struct LexiconIdentityResolutionTests {
    static let nsid = "com.example.note"
    static let dnsName = "_lexicon.example.com"
    static let plcDID = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    static let webDID = "did:web:lexicons.example.com"
    static let pds = "https://pds.example.com"

    static func didDocument(_ did: String, services: [[String: String]]) -> String {
        let object: [String: Any] = [
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": did,
            "service": services,
        ]
        // Force-unwrap: the object holds strings and arrays of strings only.
        return String(data: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), encoding: .utf8)!
    }

    static let pdsService = ["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": pds]

    static func getRecordBody(did: String, id: String = nsid) -> String {
        """
        {"uri":"at://\(did)/com.atproto.lexicon.schema/\(nsid)","value":{"$type":"com.atproto.lexicon.schema","lexicon":1,"id":"\(id)","defs":{"main":{"type":"record","key":"tid","record":{"type":"object","properties":{"text":{"type":"string"}}}}}}}
        """
    }

    static func failure(_ body: () async throws -> Void) async -> LexiconResolutionError? {
        do {
            try await body()
            return nil
        } catch let error as LexiconResolutionError {
            return error
        } catch {
            Issue.record("unexpected error type: \(error)")
            return nil
        }
    }

    // MARK: DNS

    @Test("the DNS adapter asks the identity DNS resolver for exactly the name it is given")
    func dnsAdapterForwardsTheLookup() async throws {
        let dns = TableDNS([Self.dnsName: ["did=\(Self.plcDID)", "v=spf1 -all"]])
        let adapter = IdentityLexiconDNSResolver(dns)

        #expect(try await adapter.resolveTXT(Self.dnsName) == ["did=\(Self.plcDID)", "v=spf1 -all"])
        #expect(try await adapter.resolveTXT("_lexicon.nothing.example") == [])
        #expect(dns.queries == [Self.dnsName, "_lexicon.nothing.example"])
    }

    @Test("a DNS lookup that could not be completed is a failure, not an absent record")
    func dnsAdapterPropagatesLookupFailures() async {
        let dns = TableDNS(failing: [Self.dnsName])
        let adapter = IdentityLexiconDNSResolver(dns)

        await #expect(throws: TableDNS.Unreachable.self) {
            _ = try await adapter.resolveTXT(Self.dnsName)
        }

        let http = TableHTTP()
        let resolver = DefaultLexiconResolver(
            identity: IdentityResolver(httpTransport: http, dnsResolver: dns),
            dns: dns,
            httpTransport: http
        )
        let error = await Self.failure { _ = try await resolver.resolve(Self.nsid) }
        guard case let .dnsLookupFailed(name, _) = error else {
            Issue.record("expected dnsLookupFailed, got \(String(describing: error))")
            return
        }
        #expect(name == Self.dnsName)
        #expect(http.requests.isEmpty)
    }

    // MARK: DID

    @Test("the DID adapter returns the #atproto_pds endpoint of a did:plc document")
    func didAdapterResolvesPLC() async throws {
        let http = TableHTTP()
        http.on("https://plc.directory/\(Self.plcDID)", body: Self.didDocument(Self.plcDID, services: [
            ["id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://labeler.example.com"],
            Self.pdsService,
        ]))
        let adapter = IdentityLexiconDIDResolver(IdentityResolver(httpTransport: http, dnsResolver: TableDNS()))

        let endpoint = try await adapter.resolvePDSEndpoint(for: Self.plcDID)

        #expect(endpoint.absoluteString == Self.pds)
        #expect(http.requests.map(\.url.absoluteString) == ["https://plc.directory/\(Self.plcDID)"])
        #expect(http.requests.allSatisfy { !$0.followsRedirects })
    }

    @Test("the DID adapter returns the #atproto_pds endpoint of a did:web document")
    func didAdapterResolvesWeb() async throws {
        let http = TableHTTP()
        http.on(
            "https://lexicons.example.com/.well-known/did.json",
            body: Self.didDocument(Self.webDID, services: [Self.pdsService])
        )
        let adapter = IdentityLexiconDIDResolver(IdentityResolver(httpTransport: http, dnsResolver: TableDNS()))

        #expect(try await adapter.resolvePDSEndpoint(for: Self.webDID).absoluteString == Self.pds)
    }

    @Test("a DID whose document has no PDS, names another DID, or cannot be fetched does not resolve")
    func didAdapterFailures() async {
        let http = TableHTTP()
        http.on("https://plc.directory/did:plc:nopdsnopdsnopdsnopdsnopd", body: Self.didDocument(
            "did:plc:nopdsnopdsnopdsnopdsnopd",
            services: [["id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://labeler.example.com"]]
        ))
        http.on("https://plc.directory/did:plc:wrongidwrongidwrongidwro", body: Self.didDocument(Self.plcDID, services: [Self.pdsService]))
        http.on("https://plc.directory/did:plc:gonegonegonegonegonegone", status: 404, body: #"{"message":"DID not registered"}"#)
        let adapter = IdentityLexiconDIDResolver(IdentityResolver(httpTransport: http, dnsResolver: TableDNS()))

        for did in [
            "did:plc:nopdsnopdsnopdsnopdsnopd",
            "did:plc:wrongidwrongidwrongidwro",
            "did:plc:gonegonegonegonegonegone",
            "did:plc:unroutedunroutedunrouted",
            "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme",
        ] {
            await #expect(throws: IdentityError.self, "\(did) resolved") {
                _ = try await adapter.resolvePDSEndpoint(for: did)
            }
        }
    }

    // MARK: Whole procedure

    @Test("DefaultLexiconResolver(identity:) runs DNS, DID resolution and the record fetch through the identity layer")
    func resolvesThroughTheIdentityLayer() async throws {
        let dns = TableDNS([Self.dnsName: ["did=\(Self.plcDID)"]])
        let http = TableHTTP()
        http.on("https://plc.directory/\(Self.plcDID)", body: Self.didDocument(Self.plcDID, services: [Self.pdsService]))
        http.on("\(Self.pds)/xrpc/com.atproto.repo.getRecord", body: Self.getRecordBody(did: Self.plcDID))
        let identity = IdentityResolver(
            options: IdentityResolver.Options(timeout: 3),
            httpTransport: http,
            dnsResolver: dns
        )
        let resolver = DefaultLexiconResolver(identity: identity, dns: dns, httpTransport: http)

        let resolved = try await resolver.resolve(Self.nsid)

        #expect(resolved.did == Self.plcDID)
        #expect(resolved.uri == "at://\(Self.plcDID)/com.atproto.lexicon.schema/\(Self.nsid)")
        #expect(resolved.doc.id == Self.nsid)

        // Exactly one DNS name; no hierarchy walk.
        #expect(dns.queries == [Self.dnsName])

        // The DID document, then one unauthenticated getRecord at the PDS it names.
        let requests = http.requests
        #expect(requests.count == 2)
        #expect(requests.first?.url.absoluteString == "https://plc.directory/\(Self.plcDID)")
        let fetch = try #require(requests.last)
        let components = try #require(URLComponents(url: fetch.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "pds.example.com")
        #expect(components.path == "/xrpc/com.atproto.repo.getRecord")
        #expect(components.queryItems == [
            URLQueryItem(name: "repo", value: Self.plcDID),
            URLQueryItem(name: "collection", value: "com.atproto.lexicon.schema"),
            URLQueryItem(name: "rkey", value: Self.nsid),
        ])
        #expect(fetch.accept == "application/json")
        #expect(fetch.followsRedirects == false)
        #expect(fetch.timeout == 3)
        #expect(fetch.maximumResponseBytes == LexiconHTTPRecordFetcher.defaultMaximumResponseBytes)
    }

    @Test("a DID that does not resolve to a PDS stops resolution before any record fetch")
    func unresolvableAuthority() async {
        let dns = TableDNS([Self.dnsName: ["did=\(Self.plcDID)"]])
        let http = TableHTTP()
        http.on("https://plc.directory/\(Self.plcDID)", body: Self.didDocument(Self.plcDID, services: []))
        let resolver = DefaultLexiconResolver(
            identity: IdentityResolver(httpTransport: http, dnsResolver: dns),
            dns: dns,
            httpTransport: http
        )

        let error = await Self.failure { _ = try await resolver.resolve(Self.nsid) }

        guard case let .pdsResolutionFailed(did, _) = error else {
            Issue.record("expected pdsResolutionFailed, got \(String(describing: error))")
            return
        }
        #expect(did == Self.plcDID)
        #expect(http.requests.count == 1)
    }

    // MARK: Record transport

    @Test("the identity-backed record transport reports XRPC errors, transport failures and wrong records")
    func recordTransportFailures() async {
        func resolver(status: Int = 200, body: String?) -> DefaultLexiconResolver {
            let dns = TableDNS([Self.dnsName: ["did=\(Self.plcDID)"]])
            let http = TableHTTP()
            http.on("https://plc.directory/\(Self.plcDID)", body: Self.didDocument(Self.plcDID, services: [Self.pdsService]))
            if let body {
                http.on("\(Self.pds)/xrpc/com.atproto.repo.getRecord", status: status, body: body)
            }
            return DefaultLexiconResolver(
                identity: IdentityResolver(httpTransport: http, dnsResolver: dns),
                dns: dns,
                httpTransport: http
            )
        }

        let notFound = await Self.failure {
            _ = try await resolver(status: 400, body: #"{"error":"RecordNotFound","message":"Could not locate record"}"#).resolve(Self.nsid)
        }
        guard case let .recordFetchFailed(uri, reason) = notFound else {
            Issue.record("expected recordFetchFailed, got \(String(describing: notFound))")
            return
        }
        #expect(uri == "at://\(Self.plcDID)/com.atproto.lexicon.schema/\(Self.nsid)")
        #expect(reason == "HTTP 400 RecordNotFound: Could not locate record")

        let unreachable = await Self.failure { _ = try await resolver(body: nil).resolve(Self.nsid) }
        guard case .recordFetchFailed = unreachable else {
            Issue.record("expected recordFetchFailed, got \(String(describing: unreachable))")
            return
        }

        let otherID = await Self.failure {
            _ = try await resolver(body: Self.getRecordBody(did: Self.plcDID, id: "com.example.other")).resolve(Self.nsid)
        }
        #expect(otherID == .idMismatch(expected: Self.nsid, actual: "com.example.other"))
    }

    @Test("the record transport passes its limits to the identity transport and never follows redirects")
    func recordTransportLimits() async throws {
        let http = TableHTTP()
        http.on("https://pds.example.com/", status: 302, body: "")
        let transport = LexiconHTTPRecordFetcher.transport(over: http, timeout: 7, maximumResponseBytes: 4096)
        var request = try URLRequest(url: #require(URL(string: "https://pds.example.com/xrpc/com.atproto.repo.getRecord?repo=x")))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // A caller-supplied credential is not something an identity request can carry.
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport(request)

        #expect(response.statusCode == 302)
        #expect(data.isEmpty)
        #expect(try http.requests == [
            IdentityHTTPRequest(
                url: #require(request.url),
                accept: "application/json",
                timeout: 7,
                maximumResponseBytes: 4096,
                followsRedirects: false
            ),
        ])
    }
}
