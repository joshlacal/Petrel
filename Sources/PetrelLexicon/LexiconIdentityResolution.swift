import Foundation
import Petrel
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The DNS step of Lexicon resolution, performed by an identity-layer DNS resolver.
///
/// `_lexicon.<authority domain>` is looked up with the same `IdentityDNSResolver` a
/// handle's `_atproto.<handle>` record is: the system resolver by default, or whatever
/// the application supplies (DNS over HTTPS, a recursive resolver, a test double).
public struct IdentityLexiconDNSResolver: LexiconDNSTXTResolving {
    private let dns: any IdentityDNSResolver

    /// Creates the adapter.
    ///
    /// - Parameter dns: Performs the lookup. Defaults to `SystemIdentityDNSResolver`.
    public init(_ dns: any IdentityDNSResolver = SystemIdentityDNSResolver()) {
        self.dns = dns
    }

    /// The TXT records of `name`. A name with no TXT records returns an empty array;
    /// a lookup that could not be completed throws.
    public func resolveTXT(_ name: String) async throws -> [String] {
        try await dns.queryTXT(name: name)
    }
}

/// The DID step of Lexicon resolution, performed by an `IdentityResolver`.
///
/// The authority DID is resolved to its DID document under the resolver's rules
/// (`did:plc` and hostname-level `did:web` only, the document's `id` must equal the
/// DID, results cached), and the endpoint of the `#atproto_pds` service is returned.
public struct IdentityLexiconDIDResolver: LexiconDIDDocumentResolving {
    private let identity: IdentityResolver

    /// Creates the adapter.
    public init(_ identity: IdentityResolver) {
        self.identity = identity
    }

    /// The endpoint of the DID's `#atproto_pds` service.
    ///
    /// - Throws: `IdentityError` when the DID does not resolve, or its document has
    ///   no usable `#atproto_pds` service.
    public func resolvePDSEndpoint(for did: String) async throws -> URL {
        try await identity.resolveServiceEndpoint(for: did, service: .pds)
    }
}

public extension LexiconHTTPRecordFetcher {
    /// The largest `com.atproto.repo.getRecord` response the hardened transport accepts:
    /// 2 MiB, above the size any valid record can reach as JSON.
    static let defaultMaximumResponseBytes = 2 * 1024 * 1024

    /// A transport that sends each request through an `IdentityHTTPTransport`.
    ///
    /// The PDS a Lexicon is fetched from is named by a DNS record and a DID document
    /// that anyone can publish, so it is an untrusted host. An identity transport
    /// sends no credentials or cookies, bounds the time and the response size, and
    /// (the default `HardenedIdentityHTTPTransport`) refuses destinations that
    /// resolve to private, loopback or reserved addresses. Redirects are not followed.
    ///
    /// - Parameters:
    ///   - transport: Performs the request.
    ///   - timeout: Seconds allowed for the exchange.
    ///   - maximumResponseBytes: The largest response body accepted.
    static func transport(
        over transport: any IdentityHTTPTransport,
        timeout: TimeInterval = 10,
        maximumResponseBytes: Int = LexiconHTTPRecordFetcher.defaultMaximumResponseBytes
    ) -> LexiconHTTPTransport {
        { request in
            guard let url = request.url else {
                throw LexiconHTTPError.invalidEndpoint("(no URL)")
            }
            let response = try await transport.send(
                IdentityHTTPRequest(
                    url: url,
                    accept: request.value(forHTTPHeaderField: "Accept") ?? "application/json",
                    timeout: timeout,
                    maximumResponseBytes: maximumResponseBytes,
                    followsRedirects: false
                )
            )
            guard let http = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw LexiconHTTPError.malformedResponse("status \(response.statusCode) is not an HTTP status")
            }
            return (response.body, http)
        }
    }

    /// The default transport: ``transport(over:timeout:maximumResponseBytes:)`` over a
    /// new `HardenedIdentityHTTPTransport`.
    static func hardenedTransport() -> LexiconHTTPTransport {
        transport(over: HardenedIdentityHTTPTransport())
    }
}

public extension DefaultLexiconResolver {
    /// Creates a resolver that runs every network step through the identity layer.
    ///
    /// ```swift
    /// let resolver = DefaultLexiconResolver(identity: IdentityResolver())
    /// let resolved = try await resolver.resolve("com.example.note")
    /// ```
    ///
    /// - Parameters:
    ///   - identity: Resolves the authority DID to its PDS.
    ///   - dns: Looks up `_lexicon.<authority domain>`. Defaults to
    ///     `SystemIdentityDNSResolver`.
    ///   - httpTransport: Fetches the schema record. Defaults to a new
    ///     `HardenedIdentityHTTPTransport`; the request uses the identity resolver's
    ///     timeout.
    ///   - cache: Optional TTL cache of results.
    ///   - schemaOptions: How strictly resolved documents are checked.
    init(
        identity: IdentityResolver,
        dns: any IdentityDNSResolver = SystemIdentityDNSResolver(),
        httpTransport: (any IdentityHTTPTransport)? = nil,
        cache: LexiconResolutionCache? = nil,
        schemaOptions: LexiconSchemaOptions = .strict
    ) {
        self.init(
            dns: IdentityLexiconDNSResolver(dns),
            didResolver: IdentityLexiconDIDResolver(identity),
            fetcher: LexiconHTTPRecordFetcher(
                transport: LexiconHTTPRecordFetcher.transport(
                    over: httpTransport ?? HardenedIdentityHTTPTransport(),
                    timeout: identity.options.timeout
                )
            ),
            cache: cache,
            schemaOptions: schemaOptions
        )
    }
}
