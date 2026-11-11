import Foundation
import PetrelCore
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A Lexicon fetched from the network, with where it came from.
public struct ResolvedLexicon: Sendable, Hashable {
    /// The NSID that was resolved.
    public let nsid: String
    /// The parsed, validated schema.
    public let doc: LexiconDoc
    /// The DID of the repository that publishes the schema: the authority the
    /// NSID's `_lexicon` DNS record points at.
    public let did: String
    /// `at://<did>/com.atproto.lexicon.schema/<nsid>`.
    public let uri: String
    /// CID of the schema record, when the record source reported one.
    public let cid: CID?
    /// The schema record exactly as fetched, including fields the model does
    /// not keep.
    public let record: LexValue

    /// Creates a resolution result.
    public init(nsid: String, doc: LexiconDoc, did: String, uri: String, cid: CID?, record: LexValue) {
        self.nsid = nsid
        self.doc = doc
        self.did = did
        self.uri = uri
        self.cid = cid
        self.record = record
    }
}

/// Resolves the Lexicon for an NSID.
public protocol LexiconResolver: Sendable {
    /// Finds, fetches and validates the Lexicon published for `nsid`.
    ///
    /// - Throws: ``LexiconResolutionError``.
    func resolve(_ nsid: String) async throws -> ResolvedLexicon
}

/// Looks up DNS TXT records.
public protocol LexiconDNSTXTResolving: Sendable {
    /// Returns the TXT records of `name`, each with its character-strings
    /// already joined. A name with no TXT records returns an empty array.
    func resolveTXT(_ name: String) async throws -> [String]
}

/// Finds the PDS that hosts a DID's repository.
public protocol LexiconDIDDocumentResolving: Sendable {
    /// Resolves `did` to its DID document and returns the endpoint of its
    /// `#atproto_pds` service.
    func resolvePDSEndpoint(for did: String) async throws -> URL
}

/// A record as returned by a record source.
public struct LexiconFetchedRecord: Sendable, Hashable {
    /// The record value.
    public let value: LexValue
    /// The record's CID, if the source reported one.
    public let cid: CID?

    /// Creates a fetched record.
    public init(value: LexValue, cid: CID? = nil) {
        self.value = value
        self.cid = cid
    }
}

/// Fetches one record from a repository.
public protocol LexiconRecordFetching: Sendable {
    /// Fetches `at://<did>/<collection>/<recordKey>` from the PDS at
    /// `pdsEndpoint`.
    func fetchRecord(
        pdsEndpoint: URL,
        did: String,
        collection: String,
        recordKey: String
    ) async throws -> LexiconFetchedRecord
}

/// Why a Lexicon could not be resolved.
public enum LexiconResolutionError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The string is not a valid NSID.
    case invalidNSID(String)
    /// The DNS lookup itself failed.
    case dnsLookupFailed(name: String, reason: String)
    /// The authority's `_lexicon` name has no `did=` TXT record. Resolution
    /// does not walk up or down the DNS hierarchy.
    case authorityNotFound(name: String)
    /// The `_lexicon` name has `did=` records that disagree.
    case conflictingAuthorityRecords(name: String, values: [String])
    /// The `did=` value is not a valid DID.
    case invalidAuthorityDID(name: String, value: String)
    /// The authority DID could not be resolved to a PDS.
    case pdsResolutionFailed(did: String, reason: String)
    /// The schema record could not be fetched.
    case recordFetchFailed(uri: String, reason: String)
    /// The record does not hash to the CID the source reported for it.
    case recordCIDMismatch(uri: String, reported: String, computed: String)
    /// The record's `$type` is not `com.atproto.lexicon.schema`.
    case notASchemaRecord(uri: String, type: String?)
    /// The record's `lexicon` field is missing or is not `1`.
    case unsupportedLexiconVersion(uri: String)
    /// The record's `id` is not the NSID that was asked for (which is also
    /// its record key).
    case idMismatch(expected: String, actual: String?)
    /// The record is not a valid Lexicon document.
    case invalidSchema(LexiconSchemaError)

    /// A single-line, human-readable rendering.
    public var description: String {
        switch self {
        case let .invalidNSID(nsid):
            return "\"\(nsid)\" is not a valid NSID"
        case let .dnsLookupFailed(name, reason):
            return "DNS TXT lookup of \(name) failed: \(reason)"
        case let .authorityNotFound(name):
            return "no did= TXT record at \(name)"
        case let .conflictingAuthorityRecords(name, values):
            return "conflicting did= TXT records at \(name): \(values.joined(separator: ", "))"
        case let .invalidAuthorityDID(name, value):
            return "the did= TXT record at \(name) is not a DID: \(value)"
        case let .pdsResolutionFailed(did, reason):
            return "could not find the PDS of \(did): \(reason)"
        case let .recordFetchFailed(uri, reason):
            return "could not fetch \(uri): \(reason)"
        case let .recordCIDMismatch(uri, reported, computed):
            return "\(uri) was reported as \(reported) but hashes to \(computed)"
        case let .notASchemaRecord(uri, type):
            return "\(uri) has $type \(type ?? "(none)"), expected \(lexiconSchemaCollection)"
        case let .unsupportedLexiconVersion(uri):
            return "\(uri) does not declare \"lexicon\": 1"
        case let .idMismatch(expected, actual):
            return "schema record id is \(actual ?? "(none)"), expected \(expected)"
        case let .invalidSchema(error):
            return "invalid Lexicon: \(error)"
        }
    }
}

/// The pure, network-free parts of Lexicon resolution.
public enum LexiconAuthority {
    /// The authority domain of an NSID: every segment but the name, in
    /// reverse (DNS) order and lower-cased.
    ///
    /// `edu.university.dept.lab.blogging.getBlogPost` →
    /// `blogging.lab.dept.university.edu`.
    ///
    /// - Throws: ``LexiconResolutionError/invalidNSID(_:)``.
    public static func domain(for nsid: String) throws -> String {
        guard LexSyntax.isNSID(nsid) else {
            throw LexiconResolutionError.invalidNSID(nsid)
        }
        let segments = nsid.split(separator: ".")
        return segments.dropLast().reversed().joined(separator: ".").lowercased()
    }

    /// The single DNS name whose TXT record names the authority's DID:
    /// `_lexicon.<authority domain>`. Resolution is not hierarchical; no other
    /// name is ever consulted.
    ///
    /// - Throws: ``LexiconResolutionError/invalidNSID(_:)``.
    public static func dnsName(for nsid: String) throws -> String {
        try "_lexicon." + domain(for: nsid)
    }

    /// Extracts the authority DID from the TXT records of a `_lexicon` name.
    ///
    /// Records without the `did=` prefix are ignored. Exactly one distinct
    /// DID must remain.
    ///
    /// - Throws: ``LexiconResolutionError/authorityNotFound(name:)``,
    ///   ``LexiconResolutionError/conflictingAuthorityRecords(name:values:)``
    ///   or ``LexiconResolutionError/invalidAuthorityDID(name:value:)``.
    public static func did(fromTXT records: [String], name: String) throws -> String {
        var values: [String] = []
        for record in records where record.hasPrefix("did=") {
            let value = String(record.dropFirst("did=".count))
            if !values.contains(value) {
                values.append(value)
            }
        }
        guard let value = values.first else {
            throw LexiconResolutionError.authorityNotFound(name: name)
        }
        guard values.count == 1 else {
            throw LexiconResolutionError.conflictingAuthorityRecords(name: name, values: values)
        }
        guard LexSyntax.isDID(value) else {
            throw LexiconResolutionError.invalidAuthorityDID(name: name, value: value)
        }
        return value
    }

    /// The AT-URI of the schema record for `nsid` in the repository `did`.
    public static func recordURI(did: String, nsid: String) -> String {
        "at://\(did)/\(lexiconSchemaCollection)/\(nsid)"
    }

    /// Checks a fetched schema record and turns it into a document: `$type`
    /// is `com.atproto.lexicon.schema`, `lexicon` is `1`, `id` equals the
    /// requested NSID (and so the record key), and the document is a valid
    /// Lexicon.
    ///
    /// - Throws: ``LexiconResolutionError``.
    public static func document(
        fromRecord record: LexValue,
        nsid: String,
        uri: String,
        options: LexiconSchemaOptions = .strict
    ) throws -> LexiconDoc {
        guard record.type == lexiconSchemaCollection else {
            throw LexiconResolutionError.notASchemaRecord(uri: uri, type: record.type)
        }
        guard record["lexicon"]?.integerValue == 1 else {
            throw LexiconResolutionError.unsupportedLexiconVersion(uri: uri)
        }
        guard let id = record["id"]?.stringValue, id == nsid else {
            throw LexiconResolutionError.idMismatch(expected: nsid, actual: record["id"]?.stringValue)
        }
        do {
            return try LexiconDoc(record, options: options)
        } catch let error as LexiconSchemaError {
            throw LexiconResolutionError.invalidSchema(error)
        }
    }
}

/// A small time-to-live cache for resolved Lexicons.
///
/// DNS authority changes are not broadcast anywhere, so resolved schemas must
/// not be held for long; the default lifetime is five minutes.
public actor LexiconResolutionCache {
    private struct Entry {
        let value: ResolvedLexicon
        let expires: Date
    }

    private var entries: [String: Entry] = [:]
    private let timeToLive: TimeInterval
    private let now: @Sendable () -> Date

    /// Creates a cache.
    ///
    /// - Parameters:
    ///   - timeToLive: Seconds an entry stays valid.
    ///   - now: Clock, injectable for tests.
    public init(timeToLive: TimeInterval = 300, now: @escaping @Sendable () -> Date = { Date() }) {
        self.timeToLive = timeToLive
        self.now = now
    }

    /// The cached resolution for `nsid`, if it has not expired.
    public func value(for nsid: String) -> ResolvedLexicon? {
        guard let entry = entries[nsid] else { return nil }
        guard entry.expires > now() else {
            entries[nsid] = nil
            return nil
        }
        return entry.value
    }

    /// Stores a resolution.
    public func store(_ value: ResolvedLexicon) {
        entries[value.nsid] = Entry(value: value, expires: now().addingTimeInterval(timeToLive))
    }

    /// Drops one entry, or every entry when `nsid` is `nil`.
    public func invalidate(_ nsid: String? = nil) {
        if let nsid {
            entries[nsid] = nil
        } else {
            entries.removeAll()
        }
    }
}

/// The standard resolution procedure, built from three replaceable steps:
///
/// 1. one DNS TXT lookup of `_lexicon.<authority domain>` for a `did=` value;
/// 2. DID resolution to the repository's PDS;
/// 3. fetching `com.atproto.lexicon.schema/<nsid>` from that repository.
///
/// The fetched record is then checked (`$type`, `lexicon`, `id` equal to the
/// NSID and record key) and validated as a Lexicon document.
public struct DefaultLexiconResolver: LexiconResolver {
    private let dns: any LexiconDNSTXTResolving
    private let didResolver: any LexiconDIDDocumentResolving
    private let fetcher: any LexiconRecordFetching
    private let cache: LexiconResolutionCache?
    private let schemaOptions: LexiconSchemaOptions

    /// Creates a resolver.
    ///
    /// - Parameters:
    ///   - dns: DNS TXT lookup.
    ///   - didResolver: DID → PDS endpoint.
    ///   - fetcher: Record source. Defaults to ``LexiconHTTPRecordFetcher``.
    ///   - cache: Optional TTL cache of results.
    ///   - schemaOptions: How strictly resolved documents are checked.
    public init(
        dns: any LexiconDNSTXTResolving,
        didResolver: any LexiconDIDDocumentResolving,
        fetcher: any LexiconRecordFetching = LexiconHTTPRecordFetcher(),
        cache: LexiconResolutionCache? = nil,
        schemaOptions: LexiconSchemaOptions = .strict
    ) {
        self.dns = dns
        self.didResolver = didResolver
        self.fetcher = fetcher
        self.cache = cache
        self.schemaOptions = schemaOptions
    }

    /// Resolves `nsid`: DNS authority lookup, DID resolution, record fetch,
    /// then the record and schema checks. A cached result is returned when
    /// the resolver has a cache and the entry has not expired.
    ///
    /// - Throws: ``LexiconResolutionError``.
    public func resolve(_ nsid: String) async throws -> ResolvedLexicon {
        let name = try LexiconAuthority.dnsName(for: nsid)
        if let cached = await cache?.value(for: nsid) {
            return cached
        }
        let did = try await resolveAuthority(name: name)
        let resolved = try await resolve(nsid, authority: did)
        await cache?.store(resolved)
        return resolved
    }

    /// Resolves the authority DID for an NSID: the DNS step alone.
    ///
    /// - Throws: ``LexiconResolutionError``.
    public func resolveAuthority(for nsid: String) async throws -> String {
        try await resolveAuthority(name: LexiconAuthority.dnsName(for: nsid))
    }

    private func resolveAuthority(name: String) async throws -> String {
        let records: [String]
        do {
            records = try await dns.resolveTXT(name)
        } catch {
            throw LexiconResolutionError.dnsLookupFailed(name: name, reason: String(describing: error))
        }
        return try LexiconAuthority.did(fromTXT: records, name: name)
    }

    /// Fetches and checks the schema for `nsid` from a known authority,
    /// skipping the DNS step.
    ///
    /// - Throws: ``LexiconResolutionError``.
    public func resolve(_ nsid: String, authority did: String) async throws -> ResolvedLexicon {
        guard LexSyntax.isNSID(nsid) else {
            throw LexiconResolutionError.invalidNSID(nsid)
        }
        let uri = LexiconAuthority.recordURI(did: did, nsid: nsid)
        let endpoint: URL
        do {
            endpoint = try await didResolver.resolvePDSEndpoint(for: did)
        } catch {
            throw LexiconResolutionError.pdsResolutionFailed(did: did, reason: String(describing: error))
        }
        let fetched: LexiconFetchedRecord
        do {
            fetched = try await fetcher.fetchRecord(
                pdsEndpoint: endpoint,
                did: did,
                collection: lexiconSchemaCollection,
                recordKey: nsid
            )
        } catch {
            throw LexiconResolutionError.recordFetchFailed(uri: uri, reason: String(describing: error))
        }
        // A reported CID must be the hash of the record's canonical DAG-CBOR
        // form. This catches a source that pairs a record with someone else's
        // CID; it is not a substitute for verifying a signed commit.
        if let reported = fetched.cid {
            let computed: CID
            do {
                computed = try fetched.value.cid()
            } catch {
                throw LexiconResolutionError.recordFetchFailed(uri: uri, reason: "record can not be encoded as DAG-CBOR: \(error)")
            }
            guard computed == reported else {
                throw LexiconResolutionError.recordCIDMismatch(uri: uri, reported: reported.string, computed: computed.string)
            }
        }
        let doc = try LexiconAuthority.document(fromRecord: fetched.value, nsid: nsid, uri: uri, options: schemaOptions)
        return ResolvedLexicon(nsid: nsid, doc: doc, did: did, uri: uri, cid: fetched.cid, record: fetched.value)
    }
}

/// Performs one HTTP request. The seam exists so the HTTP-based pieces can be
/// tested, proxied or rate-limited without subclassing `URLSession`.
public typealias LexiconHTTPTransport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

/// Why an HTTP record fetch failed.
public enum LexiconHTTPError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The request URL could not be built from the PDS endpoint.
    case invalidEndpoint(String)
    /// The server answered with a non-2xx status.
    case status(code: Int, error: String?, message: String?)
    /// The response is not the `{uri, cid, value}` shape of
    /// `com.atproto.repo.getRecord`.
    case malformedResponse(String)

    /// A single-line, human-readable rendering.
    public var description: String {
        switch self {
        case let .invalidEndpoint(endpoint):
            return "invalid PDS endpoint: \(endpoint)"
        case let .status(code, error, message):
            return "HTTP \(code)" + (error.map { " \($0)" } ?? "") + (message.map { ": \($0)" } ?? "")
        case let .malformedResponse(detail):
            return "malformed getRecord response: \(detail)"
        }
    }
}

/// Fetches a record with an unauthenticated `com.atproto.repo.getRecord`
/// request.
///
/// This trusts the PDS and the TLS connection to it. It does not verify the
/// record against a signed repository commit; plug a ``LexiconRecordFetching``
/// that uses `com.atproto.sync.getRecord` and MST proof verification
/// (`PetrelRepo`) into ``DefaultLexiconResolver`` where that matters.
public struct LexiconHTTPRecordFetcher: LexiconRecordFetching {
    private let transport: LexiconHTTPTransport

    /// Creates a fetcher.
    ///
    /// - Parameter transport: Performs the request. Defaults to
    ///   `URLSession.shared`.
    public init(transport: @escaping LexiconHTTPTransport = LexiconHTTPRecordFetcher.urlSessionTransport) {
        self.transport = transport
    }

    /// A transport backed by `URLSession.shared`.
    public static let urlSessionTransport: LexiconHTTPTransport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LexiconHTTPError.malformedResponse("not an HTTP response")
        }
        return (data, http)
    }

    /// Requests `com.atproto.repo.getRecord` from the PDS and returns the
    /// record value, parsed under the data-model rules, with the CID the PDS
    /// reported.
    ///
    /// - Throws: ``LexiconHTTPError``, or whatever the transport throws.
    public func fetchRecord(
        pdsEndpoint: URL,
        did: String,
        collection: String,
        recordKey: String
    ) async throws -> LexiconFetchedRecord {
        guard var components = URLComponents(url: pdsEndpoint, resolvingAgainstBaseURL: false),
              components.scheme == "https" || components.scheme == "http", components.host != nil
        else {
            throw LexiconHTTPError.invalidEndpoint(pdsEndpoint.absoluteString)
        }
        components.path = "/xrpc/com.atproto.repo.getRecord"
        components.fragment = nil
        components.queryItems = [
            URLQueryItem(name: "repo", value: did),
            URLQueryItem(name: "collection", value: collection),
            URLQueryItem(name: "rkey", value: recordKey),
        ]
        guard let url = components.url else {
            throw LexiconHTTPError.invalidEndpoint(pdsEndpoint.absoluteString)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport(request)
        guard (200 ..< 300).contains(response.statusCode) else {
            let body = try? LexValue(json: data)
            throw LexiconHTTPError.status(
                code: response.statusCode,
                error: body?["error"]?.stringValue,
                message: body?["message"]?.stringValue
            )
        }
        let body: LexValue
        do {
            body = try LexValue.record(json: data)
        } catch {
            throw LexiconHTTPError.malformedResponse(String(describing: error))
        }
        guard let value = body["value"], case .object = value else {
            throw LexiconHTTPError.malformedResponse("\"value\" is missing or is not an object")
        }
        var cid: CID?
        if let cidString = body["cid"]?.stringValue {
            guard let parsed = LexCID.parseCanonical(cidString) else {
                throw LexiconHTTPError.malformedResponse("\"cid\" is not a CID")
            }
            cid = parsed
        }
        return LexiconFetchedRecord(value: value, cid: cid)
    }
}
