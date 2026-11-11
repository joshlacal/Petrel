import Foundation
import PetrelCore
@testable import PetrelLexicon
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Records every call so tests can assert exactly what the resolver asked for.
actor CallLog {
    private(set) var entries: [String] = []

    func add(_ entry: String) {
        entries.append(entry)
    }
}

struct StubError: Error, CustomStringConvertible {
    let description: String
}

struct StubDNS: LexiconDNSTXTResolving {
    let records: [String: [String]]
    let log: CallLog
    var failure: StubError?

    func resolveTXT(_ name: String) async throws -> [String] {
        await log.add("dns:\(name)")
        if let failure { throw failure }
        return records[name] ?? []
    }
}

struct StubDIDResolver: LexiconDIDDocumentResolving {
    let endpoints: [String: URL]
    let log: CallLog

    func resolvePDSEndpoint(for did: String) async throws -> URL {
        await log.add("did:\(did)")
        guard let endpoint = endpoints[did] else {
            throw StubError(description: "no DID document")
        }
        return endpoint
    }
}

struct StubFetcher: LexiconRecordFetching {
    let records: [String: LexiconFetchedRecord]
    let log: CallLog

    func fetchRecord(pdsEndpoint: URL, did: String, collection: String, recordKey: String) async throws -> LexiconFetchedRecord {
        let uri = "at://\(did)/\(collection)/\(recordKey)"
        await log.add("fetch:\(pdsEndpoint.absoluteString) \(uri)")
        guard let record = records[uri] else {
            throw StubError(description: "RecordNotFound")
        }
        return record
    }
}

@Suite("Lexicon resolution")
struct LexiconResolverTests {
    static let nsid = "edu.university.dept.lab.blogging.getBlogPost"
    static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    static let dnsName = "_lexicon.blogging.lab.dept.university.edu"
    static let pds = URL(string: "https://pds.university.edu")!
    static let uri = "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.atproto.lexicon.schema/edu.university.dept.lab.blogging.getBlogPost"

    static func schemaRecord(id: String = nsid, type: String? = "com.atproto.lexicon.schema", lexicon: LexValue? = 1) -> LexValue {
        var fields: [String: LexValue] = [
            "id": .string(id),
            "defs": ["main": ["type": "query", "output": ["encoding": "application/json"]]],
        ]
        fields["$type"] = type.map(LexValue.string)
        fields["lexicon"] = lexicon
        return .object(fields)
    }

    static func resolver(
        txt: [String] = ["did=\(did)"],
        record: LexValue? = schemaRecord(),
        cid: CID? = nil,
        endpoints: [String: URL] = [did: pds],
        log: CallLog = CallLog(),
        cache: LexiconResolutionCache? = nil
    ) -> DefaultLexiconResolver {
        var records: [String: LexiconFetchedRecord] = [:]
        if let record {
            records[uri] = LexiconFetchedRecord(value: record, cid: cid)
        }
        return DefaultLexiconResolver(
            dns: StubDNS(records: [dnsName: txt], log: log),
            didResolver: StubDIDResolver(endpoints: endpoints, log: log),
            fetcher: StubFetcher(records: records, log: log),
            cache: cache
        )
    }

    static func failure(_ resolver: DefaultLexiconResolver, nsid: String = nsid) async -> LexiconResolutionError? {
        do {
            _ = try await resolver.resolve(nsid)
            return nil
        } catch let error as LexiconResolutionError {
            return error
        } catch {
            Issue.record("unexpected error: \(error)")
            return nil
        }
    }

    // MARK: Authority

    @Test("the authority domain is the NSID minus its name, reversed", arguments: [
        ("app.toy.record", "toy.app", "_lexicon.toy.app"),
        ("edu.university.dept.lab.blogging.getBlogPost", "blogging.lab.dept.university.edu", "_lexicon.blogging.lab.dept.university.edu"),
        ("edu.university.dept.lab.blogging.getBlogComments", "blogging.lab.dept.university.edu", "_lexicon.blogging.lab.dept.university.edu"),
        ("edu.university.dept.lab.gallery.photo", "gallery.lab.dept.university.edu", "_lexicon.gallery.lab.dept.university.edu"),
        ("com.atproto.lexicon.schema", "lexicon.atproto.com", "_lexicon.lexicon.atproto.com"),
        ("COM.Example.fooBar", "example.com", "_lexicon.example.com"),
    ])
    func authorityDomain(nsid: String, domain: String, dnsName: String) throws {
        #expect(try LexiconAuthority.domain(for: nsid) == domain)
        #expect(try LexiconAuthority.dnsName(for: nsid) == dnsName)
    }

    @Test("an invalid NSID has no authority", arguments: ["", "com.example", "not an nsid", "com.example.foo#bar", "com.example.3d"])
    func authorityOfInvalidNSID(nsid: String) {
        #expect(throws: LexiconResolutionError.invalidNSID(nsid)) { try LexiconAuthority.domain(for: nsid) }
    }

    @Test("TXT records: exactly one distinct did= value")
    func txtRecords() throws {
        let name = Self.dnsName
        #expect(try LexiconAuthority.did(fromTXT: ["did=\(Self.did)"], name: name) == Self.did)
        // Unrelated TXT records at the same name are ignored.
        #expect(try LexiconAuthority.did(fromTXT: ["v=spf1 -all", "did=\(Self.did)", "google-site-verification=abc"], name: name) == Self.did)
        // The same value twice is not a conflict.
        #expect(try LexiconAuthority.did(fromTXT: ["did=\(Self.did)", "did=\(Self.did)"], name: name) == Self.did)
        #expect(throws: LexiconResolutionError.authorityNotFound(name: name)) {
            try LexiconAuthority.did(fromTXT: [], name: name)
        }
        #expect(throws: LexiconResolutionError.authorityNotFound(name: name)) {
            try LexiconAuthority.did(fromTXT: ["v=spf1 -all", "DID=\(Self.did)", " did=\(Self.did)"], name: name)
        }
        #expect(throws: LexiconResolutionError.conflictingAuthorityRecords(name: name, values: [Self.did, "did:web:evil.example"])) {
            try LexiconAuthority.did(fromTXT: ["did=\(Self.did)", "did=did:web:evil.example"], name: name)
        }
        #expect(throws: LexiconResolutionError.invalidAuthorityDID(name: name, value: "not-a-did")) {
            try LexiconAuthority.did(fromTXT: ["did=not-a-did"], name: name)
        }
        #expect(throws: LexiconResolutionError.invalidAuthorityDID(name: name, value: "")) {
            try LexiconAuthority.did(fromTXT: ["did="], name: name)
        }
    }

    // MARK: Full resolution

    @Test("resolution: one TXT lookup, DID to PDS, then the schema record")
    func resolves() async throws {
        let log = CallLog()
        let resolved = try await Self.resolver(log: log).resolve(Self.nsid)
        #expect(resolved.nsid == Self.nsid)
        #expect(resolved.did == Self.did)
        #expect(resolved.uri == Self.uri)
        #expect(resolved.cid == nil)
        #expect(resolved.doc.id == Self.nsid)
        #expect(resolved.doc.main?.typeName == "query")
        #expect(resolved.record == Self.schemaRecord())
        #expect(await log.entries == [
            "dns:\(Self.dnsName)",
            "did:\(Self.did)",
            "fetch:https://pds.university.edu \(Self.uri)",
        ])
        // The resolved document drops straight into a catalog.
        var catalog = LexiconCatalog()
        try catalog.add(resolved.doc)
        #expect(catalog.definition(Self.nsid) != nil)
    }

    @Test("resolution is not hierarchical: a missing TXT record fails after exactly one lookup")
    func noHierarchyWalk() async {
        let log = CallLog()
        let resolver = DefaultLexiconResolver(
            dns: StubDNS(
                records: [
                    // Records exist one level up, one level down, and at the
                    // registered domain. None of them may be consulted.
                    "_lexicon.lab.dept.university.edu": ["did=\(Self.did)"],
                    "_lexicon.getBlogPost.blogging.lab.dept.university.edu": ["did=\(Self.did)"],
                    "_lexicon.university.edu": ["did=\(Self.did)"],
                ],
                log: log
            ),
            didResolver: StubDIDResolver(endpoints: [Self.did: Self.pds], log: log),
            fetcher: StubFetcher(records: [Self.uri: LexiconFetchedRecord(value: Self.schemaRecord())], log: log)
        )
        #expect(await Self.failure(resolver) == .authorityNotFound(name: Self.dnsName))
        #expect(await log.entries == ["dns:\(Self.dnsName)"])
    }

    @Test("an invalid NSID fails before any network call")
    func invalidNSID() async {
        let log = CallLog()
        #expect(await Self.failure(Self.resolver(log: log), nsid: "com.example") == .invalidNSID("com.example"))
        #expect(await log.entries.isEmpty)
    }

    @Test("DNS failures and conflicts stop resolution")
    func dnsFailures() async {
        let log = CallLog()
        var dns = StubDNS(records: [:], log: log)
        dns.failure = StubError(description: "SERVFAIL")
        let failing = DefaultLexiconResolver(
            dns: dns,
            didResolver: StubDIDResolver(endpoints: [:], log: log),
            fetcher: StubFetcher(records: [:], log: log)
        )
        #expect(await Self.failure(failing) == .dnsLookupFailed(name: Self.dnsName, reason: "SERVFAIL"))

        let conflicting = Self.resolver(txt: ["did=\(Self.did)", "did=did:web:other.example"], log: log)
        #expect(await Self.failure(conflicting) == .conflictingAuthorityRecords(name: Self.dnsName, values: [Self.did, "did:web:other.example"]))
        #expect(await Self.failure(Self.resolver(txt: ["did=nope"], log: log)) == .invalidAuthorityDID(name: Self.dnsName, value: "nope"))
        // Nothing past DNS was attempted in any of the three.
        #expect(await log.entries.allSatisfy { $0.hasPrefix("dns:") })
    }

    @Test("a DID without a PDS, or a PDS without the record, fails")
    func downstreamFailures() async {
        #expect(await Self.failure(Self.resolver(endpoints: [:])) == .pdsResolutionFailed(did: Self.did, reason: "no DID document"))
        #expect(await Self.failure(Self.resolver(record: nil)) == .recordFetchFailed(uri: Self.uri, reason: "RecordNotFound"))
    }

    @Test("the fetched record must be a schema record for exactly this NSID")
    func recordChecks() async {
        #expect(
            await Self.failure(Self.resolver(record: Self.schemaRecord(type: "app.bsky.feed.post")))
                == .notASchemaRecord(uri: Self.uri, type: "app.bsky.feed.post")
        )
        #expect(
            await Self.failure(Self.resolver(record: Self.schemaRecord(type: nil)))
                == .notASchemaRecord(uri: Self.uri, type: nil)
        )
        #expect(await Self.failure(Self.resolver(record: Self.schemaRecord(lexicon: 2))) == .unsupportedLexiconVersion(uri: Self.uri))
        #expect(await Self.failure(Self.resolver(record: Self.schemaRecord(lexicon: nil))) == .unsupportedLexiconVersion(uri: Self.uri))
        #expect(await Self.failure(Self.resolver(record: Self.schemaRecord(lexicon: "1"))) == .unsupportedLexiconVersion(uri: Self.uri))
        // A record published under this record key but describing another NSID.
        #expect(
            await Self.failure(Self.resolver(record: Self.schemaRecord(id: "edu.university.dept.lab.blogging.other")))
                == .idMismatch(expected: Self.nsid, actual: "edu.university.dept.lab.blogging.other")
        )
        #expect(await Self.failure(Self.resolver(record: "not an object")) == .notASchemaRecord(uri: Self.uri, type: nil))
    }

    @Test("the fetched record must be a valid Lexicon")
    func schemaValidation() async {
        let invalid: LexValue = [
            "$type": "com.atproto.lexicon.schema",
            "lexicon": 1,
            "id": .string(Self.nsid),
            "defs": ["notMain": ["type": "query"]],
        ]
        guard case let .invalidSchema(error)? = await Self.failure(Self.resolver(record: invalid)) else {
            Issue.record("expected invalidSchema")
            return
        }
        #expect(error.code == .primaryNotMain)
        #expect(error.nsid == Self.nsid)
    }

    @Test("a reported CID must be the hash of the record")
    func cidCheck() async throws {
        let record = Self.schemaRecord()
        let good = try record.cid()
        let resolved = try await Self.resolver(record: record, cid: good).resolve(Self.nsid)
        #expect(resolved.cid == good)

        let other = CID.fromDAGCBOR(Data([0xA0]))
        #expect(
            await Self.failure(Self.resolver(record: record, cid: other))
                == .recordCIDMismatch(uri: Self.uri, reported: other.string, computed: good.string)
        )
    }

    @Test("a known authority skips DNS")
    func knownAuthority() async throws {
        let log = CallLog()
        let resolved = try await Self.resolver(txt: [], log: log).resolve(Self.nsid, authority: Self.did)
        #expect(resolved.did == Self.did)
        #expect(await log.entries.first == "did:\(Self.did)")
        #expect(try await Self.resolver().resolveAuthority(for: Self.nsid) == Self.did)
    }

    // MARK: Cache

    @Test("the TTL cache serves repeats, then expires")
    func cache() async throws {
        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            private var value = Date(timeIntervalSince1970: 1_000_000)
            var now: Date {
                lock.withLock { value }
            }

            func advance(_ seconds: TimeInterval) {
                lock.withLock { value += seconds }
            }
        }
        let clock = Clock()
        let cache = LexiconResolutionCache(timeToLive: 60, now: { clock.now })
        let log = CallLog()
        let resolver = Self.resolver(log: log, cache: cache)

        _ = try await resolver.resolve(Self.nsid)
        _ = try await resolver.resolve(Self.nsid)
        #expect(await log.entries.count == 3, "second resolve must be served from the cache")

        clock.advance(59)
        _ = try await resolver.resolve(Self.nsid)
        #expect(await log.entries.count == 3)

        clock.advance(2)
        _ = try await resolver.resolve(Self.nsid)
        #expect(await log.entries.count == 6, "an expired entry must be resolved again")

        await cache.invalidate(Self.nsid)
        _ = try await resolver.resolve(Self.nsid)
        #expect(await log.entries.count == 9)
        await cache.invalidate()
        #expect(await cache.value(for: Self.nsid) == nil)
    }

    @Test("failures are not cached")
    func failuresNotCached() async {
        let cache = LexiconResolutionCache()
        let resolver = Self.resolver(txt: [], cache: cache)
        #expect(await Self.failure(resolver) == .authorityNotFound(name: Self.dnsName))
        #expect(await cache.value(for: Self.nsid) == nil)
    }

    // MARK: HTTP record fetcher

    static func transport(
        status: Int = 200,
        body: String,
        capture: CallLog = CallLog()
    ) -> LexiconHTTPTransport {
        { request in
            await capture.add("\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (Data(body.utf8), response)
        }
    }

    @Test("the HTTP fetcher issues an unauthenticated com.atproto.repo.getRecord")
    func httpFetcherRequest() async throws {
        let log = CallLog()
        let record = Self.schemaRecord()
        let cid = try record.cid()
        let body = #"{"uri":"\#(Self.uri)","cid":"\#(cid.string)","value":\#(record.jsonString())}"#
        let fetcher = LexiconHTTPRecordFetcher(transport: Self.transport(body: body, capture: log))
        let fetched = try await fetcher.fetchRecord(
            pdsEndpoint: #require(URL(string: "https://pds.university.edu/")),
            did: Self.did,
            collection: lexiconSchemaCollection,
            recordKey: Self.nsid
        )
        #expect(fetched.value == record)
        #expect(fetched.cid == cid)
        let requests = await log.entries
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.hasPrefix("GET "))
        let url = try #require(URLComponents(string: String(request.dropFirst("GET ".count))))
        #expect(url.scheme == "https")
        #expect(url.host == "pds.university.edu")
        #expect(url.path == "/xrpc/com.atproto.repo.getRecord")
        #expect(url.queryItems == [
            URLQueryItem(name: "repo", value: Self.did),
            URLQueryItem(name: "collection", value: "com.atproto.lexicon.schema"),
            URLQueryItem(name: "rkey", value: Self.nsid),
        ])

        // End to end through the default resolver.
        let resolver = DefaultLexiconResolver(
            dns: StubDNS(records: [Self.dnsName: ["did=\(Self.did)"]], log: CallLog()),
            didResolver: StubDIDResolver(endpoints: [Self.did: Self.pds], log: CallLog()),
            fetcher: fetcher
        )
        #expect(try await resolver.resolve(Self.nsid).cid == cid)
    }

    @Test("the HTTP fetcher surfaces XRPC errors and malformed responses")
    func httpFetcherFailures() async {
        func failure(status: Int = 200, body: String, endpoint: String = "https://pds.example") async -> LexiconHTTPError? {
            do {
                _ = try await LexiconHTTPRecordFetcher(transport: Self.transport(status: status, body: body)).fetchRecord(
                    pdsEndpoint: URL(string: endpoint)!,
                    did: Self.did,
                    collection: lexiconSchemaCollection,
                    recordKey: Self.nsid
                )
                return nil
            } catch let error as LexiconHTTPError {
                return error
            } catch {
                Issue.record("unexpected error: \(error)")
                return nil
            }
        }
        #expect(
            await failure(status: 400, body: #"{"error":"RecordNotFound","message":"Could not locate record"}"#)
                == .status(code: 400, error: "RecordNotFound", message: "Could not locate record")
        )
        #expect(await failure(status: 502, body: "<html>bad gateway</html>") == .status(code: 502, error: nil, message: nil))
        if case .malformedResponse? = await failure(body: "not json") {} else { Issue.record("expected malformedResponse for non-JSON") }
        if case .malformedResponse? = await failure(body: #"{"uri":"x"}"#) {} else { Issue.record("expected malformedResponse for missing value") }
        if case .malformedResponse? = await failure(body: #"{"value":"string"}"#) {} else { Issue.record("expected malformedResponse for non-object value") }
        if case .malformedResponse? = await failure(body: #"{"value":{},"cid":"nope"}"#) {} else { Issue.record("expected malformedResponse for bad cid") }
        // The record itself is held to the data model: a float is not a record.
        if case .malformedResponse? = await failure(body: #"{"value":{"lexicon":1.5}}"#) {} else { Issue.record("expected malformedResponse for float") }
        #expect(await failure(body: "{}", endpoint: "ftp://pds.example") == .invalidEndpoint("ftp://pds.example"))
    }
}
