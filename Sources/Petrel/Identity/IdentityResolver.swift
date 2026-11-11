//
//  IdentityResolver.swift
//  Petrel
//

import Foundation
import PetrelCrypto

// MARK: - Options

/// How an ``IdentityResolver`` turns a handle into a candidate DID.
///
/// Whatever the strategy, the candidate is never trusted on its own: the resolver fetches the
/// DID document and requires it to claim the handle back.
public enum HandleResolutionStrategy: Sendable {
    /// Ask the handle's own domain: the DNS TXT record at `_atproto.<handle>` and
    /// `https://<handle>/.well-known/atproto-did`, in parallel.
    case direct
    /// Ask a service's `com.atproto.identity.resolveHandle`, without credentials.
    ///
    /// The handle specification lets clients rely on a network service this way. With
    /// `fallbackToDirect`, the handle's own domain is asked when the service fails or does not
    /// know the handle.
    case xrpc(service: URL, fallbackToDirect: Bool)
    /// Ask your own lookup, which returns a candidate DID or `nil` when the handle is unknown.
    ///
    /// With `fallbackToDirect`, the handle's own domain is asked when the lookup throws or
    /// returns `nil`.
    case custom(lookup: @Sendable (_ handle: Handle) async throws -> String?, fallbackToDirect: Bool)
}

/// What a direct handle lookup does when DNS and HTTPS name different DIDs.
public enum HandleConflictPolicy: Sendable, Equatable {
    /// Use the DNS TXT result, as the handle specification prefers. The HTTPS request is
    /// abandoned as soon as DNS answers with a DID.
    case preferDNS
    /// Wait for both methods and fail with ``IdentityError/handleAmbiguous(handle:dids:)`` when
    /// they disagree.
    case reject
}

// MARK: - Results

/// Whether a DID's claimed handle was confirmed.
public enum HandleVerification: Sendable, Equatable {
    /// The handle resolves back to the DID.
    case verified
    /// The DID document claims no syntactically valid handle.
    case noHandleClaimed
    /// The claimed handle resolves to this other DID.
    case resolvesToDifferentDID(String)
    /// The claimed handle does not resolve: no record exists, or it uses a reserved top-level
    /// domain.
    case doesNotResolve
    /// The lookup failed in transit, so the handle may be valid. This outcome is not cached.
    case lookupFailed
}

/// A DID together with its document and the outcome of verifying its handle in both directions.
public struct ResolvedIdentity: Sendable, Equatable {
    /// The account's DID.
    public let did: DID
    /// The verified handle, or `handle.invalid` when the document claims no handle or the claim
    /// could not be confirmed.
    public let handle: Handle
    /// Why ``handle`` is or is not the claimed handle.
    public let handleVerification: HandleVerification
    /// The DID document.
    public let document: DIDDocument

    /// Whether ``handle`` was confirmed in both directions.
    public var isHandleVerified: Bool { handleVerification == .verified }
    /// The handle the document claims, whether or not it was confirmed.
    public var claimedHandle: Handle? { document.claimedHandle }
    /// The account's PDS endpoint, or `nil` when the document has no valid one.
    public var pdsEndpoint: URL? { document.pdsEndpoint }

    /// The account's `#atproto` signing key.
    /// - Throws: ``IdentityError/missingSigningKey(did:)``.
    public func signingKey() throws -> ATProtoJWTVerificationKey {
        try document.atprotoSigningKey()
    }
}

// MARK: - IdentityResolver

/// Resolves AT Protocol handles and DIDs.
///
/// The resolver needs no `ATProtoClient`, account or keychain, and runs on Apple platforms and
/// Linux:
///
/// ```swift
/// let resolver = IdentityResolver()
/// let identity = try await resolver.resolveIdentity("atproto.com")
/// identity.did                 // did:plc:ewvi7nxzyoun6zhxrhs64oiz
/// identity.handle              // atproto.com, or handle.invalid
/// identity.pdsEndpoint         // https://…
/// try identity.signingKey()    // the #atproto key
/// ```
///
/// What it enforces:
///
/// - **DIDs.** `did:plc` (from a configurable PLC directory) and hostname-level `did:web`.
///   Other methods, path-based `did:web`, and ports on hosts other than `localhost` are rejected
///   with distinct errors. The document's `id` must equal the DID that was asked for.
/// - **Handles.** Reserved top-level domains fail before any network request. The DNS TXT and
///   HTTPS well-known methods run in parallel; only `did=` TXT values count; several `did=`
///   records naming different DIDs fail; DNS wins a disagreement with HTTPS unless
///   ``Options/handleConflictPolicy`` says otherwise.
/// - **Both directions.** A handle resolves only to a DID whose document claims that handle. A
///   DID's handle is reported as `handle.invalid` unless it resolves back to the DID.
/// - **Untrusted hosts.** Every request is sent without credentials through an
///   ``IdentityHTTPTransport``. The default one refuses private and reserved addresses, bounds
///   redirects and response size, and applies ``Options/timeout``.
/// - **Caching.** Results are cached under an ``IdentityCachePolicy``; pass `forceRefresh: true`
///   or call ``invalidate(did:)`` and ``invalidate(handle:)`` to bypass or drop an entry.
public actor IdentityResolver: DIDResolving {
    /// The configuration of an ``IdentityResolver``.
    public struct Options: Sendable {
        /// The public PLC directory, `https://plc.directory`.
        public static let defaultPLCDirectoryURL = URL(staticString: "https://plc.directory")

        /// The PLC directory. Defaults to ``defaultPLCDirectoryURL``.
        public var plcDirectoryURL: URL
        /// How a handle is turned into a candidate DID. Defaults to ``HandleResolutionStrategy/direct``.
        public var handleStrategy: HandleResolutionStrategy
        /// What to do when DNS and HTTPS disagree. Defaults to ``HandleConflictPolicy/preferDNS``.
        public var handleConflictPolicy: HandleConflictPolicy
        /// The time allowed for each HTTP request and each DNS query, in seconds. Defaults to 5.
        public var timeout: TimeInterval
        /// How long cached results are trusted.
        public var cachePolicy: IdentityCachePolicy
        /// The largest DID document accepted, in bytes. Defaults to 256 KiB.
        public var maximumDocumentBytes: Int
        /// Whether development identifiers resolve: `.test` handles, `did:web:localhost` (with
        /// an optional port, over `http`) and `.test` `did:web` hosts. The specifications allow
        /// these in testing and development only, so the default is `false`.
        public var allowsDevelopmentIdentifiers: Bool

        /// Creates options.
        public init(
            plcDirectoryURL: URL = Options.defaultPLCDirectoryURL,
            handleStrategy: HandleResolutionStrategy = .direct,
            handleConflictPolicy: HandleConflictPolicy = .preferDNS,
            timeout: TimeInterval = 5,
            cachePolicy: IdentityCachePolicy = .default,
            maximumDocumentBytes: Int = 256 * 1024,
            allowsDevelopmentIdentifiers: Bool = false
        ) {
            self.plcDirectoryURL = plcDirectoryURL
            self.handleStrategy = handleStrategy
            self.handleConflictPolicy = handleConflictPolicy
            self.timeout = timeout
            self.cachePolicy = cachePolicy
            self.maximumDocumentBytes = maximumDocumentBytes
            self.allowsDevelopmentIdentifiers = allowsDevelopmentIdentifiers
        }
    }

    /// The largest `/.well-known/atproto-did` body accepted. A DID is at most 2048 bytes.
    static let maximumWellKnownBytes = 4096
    /// The largest `com.atproto.identity.resolveHandle` response accepted.
    static let maximumResolveHandleBytes = 16 * 1024
    /// The longest name a DNS query can carry.
    static let maximumDNSNameLength = 253

    /// The configuration this resolver was created with.
    public nonisolated let options: Options
    private let cache: any IdentityCache
    private let http: any IdentityHTTPTransport
    private let dns: any IdentityDNSResolver
    private let now: @Sendable () -> Date

    /// Creates a resolver.
    ///
    /// - Parameters:
    ///   - options: PLC directory, handle strategy, timeout and cache lifetimes.
    ///   - cache: Where results are kept. Defaults to a new ``InMemoryIdentityCache``.
    ///   - httpTransport: Performs the HTTP requests. Defaults to a new
    ///     ``HardenedIdentityHTTPTransport``.
    ///   - dnsResolver: Performs the DNS TXT lookups. Defaults to ``SystemIdentityDNSResolver``.
    public init(
        options: Options = Options(),
        cache: (any IdentityCache)? = nil,
        httpTransport: (any IdentityHTTPTransport)? = nil,
        dnsResolver: (any IdentityDNSResolver)? = nil
    ) {
        self.init(options: options, cache: cache, httpTransport: httpTransport, dnsResolver: dnsResolver, now: { Date() })
    }

    /// Creates a resolver with a replaceable clock, for cache-lifetime tests.
    init(
        options: Options,
        cache: (any IdentityCache)?,
        httpTransport: (any IdentityHTTPTransport)?,
        dnsResolver: (any IdentityDNSResolver)?,
        now: @escaping @Sendable () -> Date
    ) {
        self.options = options
        self.cache = cache ?? InMemoryIdentityCache()
        http = httpTransport ?? HardenedIdentityHTTPTransport()
        dns = dnsResolver ?? SystemIdentityDNSResolver()
        self.now = now
    }

    // MARK: Handles

    /// Resolves a handle to its DID and verifies the link in both directions.
    ///
    /// - Parameters:
    ///   - handle: The handle. Letter case is normalized; nothing else is.
    ///   - forceRefresh: Ignore cached results for the handle and for the DID document.
    /// - Returns: The DID whose document claims the handle.
    /// - Throws: ``IdentityError``, or `CancellationError`.
    public func resolveHandle(_ handle: String, forceRefresh: Bool = false) async throws -> DID {
        try await verify(handle: validatedHandle(handle), forceRefresh: forceRefresh).did
    }

    /// The handle's DID and that DID's document, once the document claims the handle back.
    private func verify(handle: Handle, forceRefresh: Bool) async throws -> (did: DID, document: DIDDocument) {
        try Task.checkCancellation()
        let candidate = try await lookUpHandle(handle, forceRefresh: forceRefresh)
        let document = try await resolveDIDDocument(candidate, forceRefresh: forceRefresh)
        guard document.claimedHandle == handle else {
            // A failed verification is not remembered: once the handle's records are fixed, the
            // next attempt sees them without waiting for the cached lookup to age out.
            await cache.removeHandle(handle.value)
            throw IdentityError.handleNotClaimedByDID(handle: handle.value, did: candidate)
        }
        return try (DID(didString: candidate), document)
    }

    /// Resolves a handle to its DID and verifies the link in both directions.
    public func resolveHandle(_ handle: Handle, forceRefresh: Bool = false) async throws -> DID {
        try await resolveHandle(handle.value, forceRefresh: forceRefresh)
    }

    // MARK: DIDs

    /// Resolves a DID to its document.
    ///
    /// The DID's syntax and method are checked first, and the returned document's `id` equals
    /// `did`.
    ///
    /// - Parameters:
    ///   - did: A `did:plc` or hostname-level `did:web` DID.
    ///   - forceRefresh: Fetch the document even when a cached copy is fresh.
    /// - Throws: ``IdentityError``, or `CancellationError`.
    public func resolveDIDDocument(_ did: String, forceRefresh: Bool = false) async throws -> DIDDocument {
        try Task.checkCancellation()
        let source = try documentSource(for: did)
        let cached = await cache.didDocument(for: did)
        if !forceRefresh, let cached, age(of: cached.storedAt) < options.cachePolicy.freshFor {
            return cached.value
        }
        do {
            let document = try await fetchDIDDocument(did, from: source)
            await cache.setDIDDocument(document, for: did, storedAt: now())
            return document
        } catch let error as IdentityError {
            if Self.isDefinitive(error) {
                await cache.removeDIDDocument(for: did)
            } else if !forceRefresh, let cached, age(of: cached.storedAt) < options.cachePolicy.maximumAge {
                return cached.value
            }
            throw error
        }
    }

    /// Resolves a DID to its document.
    public func resolveDIDDocument(_ did: DID, forceRefresh: Bool = false) async throws -> DIDDocument {
        try await resolveDIDDocument(did.didString(), forceRefresh: forceRefresh)
    }

    /// Resolves a DID to the account's `#atproto` signing key.
    ///
    /// Pass `forceRefresh: true` after a signature fails to verify, in case the account rotated
    /// its key since the document was cached.
    ///
    /// - Throws: ``IdentityError/missingSigningKey(did:)`` or another ``IdentityError``.
    public func resolveSigningKey(for did: String, forceRefresh: Bool = false) async throws -> ATProtoJWTVerificationKey {
        try await resolveDIDDocument(did, forceRefresh: forceRefresh).atprotoSigningKey()
    }

    /// Resolves a DID to the endpoint of one of its services.
    ///
    /// ```swift
    /// let pds = try await resolver.resolveServiceEndpoint(for: did, service: .pds)
    /// let labeler = try await resolver.resolveServiceEndpoint(for: did, service: .labeler)
    /// ```
    ///
    /// - Throws: ``IdentityError/missingService(did:id:)``,
    ///   ``IdentityError/invalidServiceEndpoint(did:id:)`` or another ``IdentityError``.
    public func resolveServiceEndpoint(
        for did: String,
        service: DIDServiceIdentifier,
        forceRefresh: Bool = false
    ) async throws -> URL {
        try await resolveDIDDocument(did, forceRefresh: forceRefresh).serviceEndpoint(service)
    }

    // MARK: Identity

    /// Resolves a handle or a DID to a verified identity.
    ///
    /// Given a DID, the claimed handle is looked up and reported as `handle.invalid` unless it
    /// resolves back to the DID; a broken handle does not fail the call. Given a handle, the
    /// call fails unless the handle and the DID confirm each other.
    ///
    /// - Parameters:
    ///   - identifier: A handle or a DID.
    ///   - forceRefresh: Ignore cached results.
    /// - Throws: ``IdentityError``, or `CancellationError`.
    public func resolveIdentity(_ identifier: String, forceRefresh: Bool = false) async throws -> ResolvedIdentity {
        if identifier.hasPrefix("did:") {
            return try await resolveIdentity(did: identifier, forceRefresh: forceRefresh)
        }
        let handle = try validatedHandle(identifier)
        let (did, document) = try await verify(handle: handle, forceRefresh: forceRefresh)
        return ResolvedIdentity(did: did, handle: handle, handleVerification: .verified, document: document)
    }

    private func resolveIdentity(did: String, forceRefresh: Bool) async throws -> ResolvedIdentity {
        let document = try await resolveDIDDocument(did, forceRefresh: forceRefresh)
        let typedDID = try DID(didString: did)
        let invalid = try Handle(handleString: Handle.invalid)
        func unverified(_ verification: HandleVerification) -> ResolvedIdentity {
            ResolvedIdentity(did: typedDID, handle: invalid, handleVerification: verification, document: document)
        }
        guard let claimed = document.claimedHandle else {
            return unverified(.noHandleClaimed)
        }
        do {
            let handle = try validatedHandle(claimed.value)
            let candidate = try await lookUpHandle(handle, forceRefresh: forceRefresh)
            guard candidate == did else {
                return unverified(.resolvesToDifferentDID(candidate))
            }
            return ResolvedIdentity(did: typedDID, handle: handle, handleVerification: .verified, document: document)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as IdentityError {
            switch error {
            case .handleNotFound, .reservedHandleTLD, .handleAmbiguous, .invalidHandleSyntax:
                return unverified(.doesNotResolve)
            default:
                return unverified(.lookupFailed)
            }
        }
    }

    // MARK: Cache control

    /// Drops the cached DID document of `did`, for example after an `#identity` or `#account`
    /// event names it.
    public func invalidate(did: String) async {
        await cache.removeDIDDocument(for: did)
    }

    /// Drops the cached lookup of `handle`.
    public func invalidate(handle: String) async {
        await cache.removeHandle(handle.lowercased())
    }

    /// Drops every cached result.
    public func clearCache() async {
        await cache.removeAll()
    }

    // MARK: DIDResolving

    /// `DIDResolving`: the verified DID of `handle`, as a string.
    public func resolveHandleToDID(handle: String) async throws -> String {
        try await resolveHandle(handle).didString()
    }

    /// `DIDResolving`: the PDS endpoint of `did`. The handle is not looked up.
    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        try await resolveDIDDocument(did).serviceEndpoint(.pds)
    }

    /// `DIDResolving`: the verified handle of `did` (or `handle.invalid`) and its PDS endpoint.
    public func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        let identity = try await resolveIdentity(did: did, forceRefresh: false)
        return try (identity.handle.value, identity.document.serviceEndpoint(.pds))
    }

    // MARK: - Handle lookup

    /// Syntax, case normalization and the top-level domain rules, all before any network use.
    private func validatedHandle(_ string: String) throws -> Handle {
        guard let handle = try? Handle(handleString: string) else {
            throw IdentityError.invalidHandleSyntax(string)
        }
        let isDevelopmentOnly = handle.value.hasSuffix(".test") && !options.allowsDevelopmentIdentifiers
        guard !handle.hasDisallowedTLD, !isDevelopmentOnly else {
            throw IdentityError.reservedHandleTLD(handle.value)
        }
        return handle
    }

    /// The DID the handle points at, from the cache or the configured strategy. The result is a
    /// candidate: callers verify it against the DID document.
    private func lookUpHandle(_ handle: Handle, forceRefresh: Bool) async throws -> String {
        let cached = await cache.did(forHandle: handle.value)
        if !forceRefresh, let cached, age(of: cached.storedAt) < options.cachePolicy.freshFor {
            return cached.value
        }
        do {
            let did = try await lookUpHandleUncached(handle)
            await cache.setDID(did, forHandle: handle.value, storedAt: now())
            return did
        } catch let error as IdentityError {
            if Self.isDefinitive(error) {
                await cache.removeHandle(handle.value)
            } else if !forceRefresh, let cached, age(of: cached.storedAt) < options.cachePolicy.maximumAge {
                return cached.value
            }
            throw error
        }
    }

    private func lookUpHandleUncached(_ handle: Handle) async throws -> String {
        let delegated: @Sendable () async throws -> String?
        let fallsBack: Bool
        switch options.handleStrategy {
        case .direct:
            return try await lookUpHandleDirectly(handle)
        case let .xrpc(service, fallbackToDirect):
            let http = http
            let timeout = options.timeout
            delegated = { try await Self.lookUpHandleViaXRPC(handle, service: service, http: http, timeout: timeout) }
            fallsBack = fallbackToDirect
        case let .custom(lookup, fallbackToDirect):
            delegated = { try await lookup(handle) }
            fallsBack = fallbackToDirect
        }

        var delegatedFailure: IdentityError?
        do {
            if let candidate = try await delegated() {
                return try Self.validatedCandidateDID(candidate, handle: handle)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as IdentityError {
            delegatedFailure = error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            delegatedFailure = .handleLookupFailed(handle: handle.value, reason: String(describing: error))
        }
        if fallsBack {
            return try await lookUpHandleDirectly(handle)
        }
        throw delegatedFailure ?? .handleNotFound(handle.value)
    }

    /// What one direct method found.
    private enum MethodOutcome: Sendable {
        case found(String)
        case none
        case ambiguous([String])
        case failed(String)
    }

    private func lookUpHandleDirectly(_ handle: Handle) async throws -> String {
        let dns = dns
        let http = http
        let timeout = options.timeout
        async let dnsLookup = Self.lookUpHandleViaDNS(handle, dns: dns, timeout: timeout)
        async let httpLookup = Self.lookUpHandleViaWellKnown(handle, http: http, timeout: timeout)

        let dnsOutcome = await dnsLookup
        try Task.checkCancellation()
        if case let .ambiguous(dids) = dnsOutcome {
            throw IdentityError.handleAmbiguous(handle: handle.value, dids: dids)
        }
        if case let .found(did) = dnsOutcome, options.handleConflictPolicy == .preferDNS {
            // Leaving the scope cancels the HTTPS request that is no longer needed.
            return did
        }

        let httpOutcome = await httpLookup
        try Task.checkCancellation()
        switch (dnsOutcome, httpOutcome) {
        case let (.found(fromDNS), .found(fromHTTP)):
            guard fromDNS == fromHTTP else {
                throw IdentityError.handleAmbiguous(handle: handle.value, dids: [fromDNS, fromHTTP])
            }
            return fromDNS
        case let (.found(did), _), let (_, .found(did)):
            return did
        case let (.failed(reason), _), let (_, .failed(reason)):
            throw IdentityError.handleLookupFailed(handle: handle.value, reason: reason)
        default:
            throw IdentityError.handleNotFound(handle.value)
        }
    }

    /// The DNS TXT method: the single DID named by the `did=` records at `_atproto.<handle>`.
    private static func lookUpHandleViaDNS(
        _ handle: Handle,
        dns: any IdentityDNSResolver,
        timeout: TimeInterval
    ) async -> MethodOutcome {
        let name = "_atproto.\(handle.value)"
        // A handle this long cannot be asked about over DNS; the HTTPS method still works.
        guard name.utf8.count <= maximumDNSNameLength else { return .none }
        let records: [String]
        do {
            records = try await IdentityDeadline.run(seconds: timeout, describing: "DNS TXT \(name)") {
                try await dns.queryTXT(name: name)
            }
        } catch {
            return .failed("DNS TXT \(name): \(error)")
        }
        let dids = didsInTXTRecords(records)
        switch dids.count {
        case 0: return .none
        case 1: return .found(dids[0])
        default: return .ambiguous(dids)
        }
    }

    /// The distinct, syntactically valid DIDs carried by `did=` TXT values, in record order.
    /// Values without the `did=` prefix are ignored, as the handle specification requires.
    static func didsInTXTRecords(_ records: [String]) -> [String] {
        var dids: [String] = []
        for record in records {
            guard record.hasPrefix("did=") else { continue }
            let did = String(record.dropFirst("did=".count))
            guard isStrictlyValidDID(did), !dids.contains(did) else { continue }
            dids.append(did)
        }
        return dids
    }

    /// The HTTPS well-known method: the DID in the body of `https://<handle>/.well-known/atproto-did`.
    private static func lookUpHandleViaWellKnown(
        _ handle: Handle,
        http: any IdentityHTTPTransport,
        timeout: TimeInterval
    ) async -> MethodOutcome {
        var components = URLComponents()
        components.scheme = "https"
        components.host = handle.value
        components.path = "/.well-known/atproto-did"
        guard let url = components.url else { return .none }
        let response: IdentityHTTPResponse
        do {
            response = try await http.send(IdentityHTTPRequest(
                url: url,
                accept: "text/plain",
                timeout: timeout,
                maximumResponseBytes: maximumWellKnownBytes,
                followsRedirects: true
            ))
        } catch {
            return .failed("GET \(url.absoluteString): \(error)")
        }
        switch response.statusCode {
        case 200 ..< 300:
            // The body is the DID alone; surrounding whitespace is stripped before parsing.
            guard let text = String(data: response.body, encoding: .utf8) else { return .none }
            let did = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return isStrictlyValidDID(did) ? .found(did) : .none
        case 500 ..< 600, 429:
            return .failed("GET \(url.absoluteString): HTTP \(response.statusCode)")
        default:
            return .none
        }
    }

    /// The delegated method: `com.atproto.identity.resolveHandle` on `service`, unauthenticated.
    private static func lookUpHandleViaXRPC(
        _ handle: Handle,
        service: URL,
        http: any IdentityHTTPTransport,
        timeout: TimeInterval
    ) async throws -> String? {
        guard var components = URLComponents(url: service, resolvingAgainstBaseURL: false) else {
            throw IdentityError.transport(url: service.absoluteString, reason: "The service URL is not valid.")
        }
        let base = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = base + "/xrpc/com.atproto.identity.resolveHandle"
        components.queryItems = [URLQueryItem(name: "handle", value: handle.value)]
        guard let url = components.url else {
            throw IdentityError.transport(url: service.absoluteString, reason: "The service URL is not valid.")
        }
        let response = try await http.send(IdentityHTTPRequest(
            url: url,
            accept: "application/json",
            timeout: timeout,
            maximumResponseBytes: maximumResolveHandleBytes,
            followsRedirects: false
        ))
        struct Output: Decodable { let did: String }
        switch response.statusCode {
        case 200 ..< 300:
            guard let output = try? JSONDecoder().decode(Output.self, from: response.body) else {
                throw IdentityError.handleLookupFailed(
                    handle: handle.value, reason: "\(url.absoluteString) did not return a resolveHandle response."
                )
            }
            return output.did
        case 400, 404:
            // `HandleNotFound` and its kin: the service does not know the handle.
            return nil
        default:
            throw IdentityError.unexpectedStatus(url: url.absoluteString, statusCode: response.statusCode)
        }
    }

    private static func validatedCandidateDID(_ candidate: String, handle: Handle) throws -> String {
        guard isStrictlyValidDID(candidate) else {
            throw IdentityError.handleLookupFailed(
                handle: handle.value, reason: "The lookup returned '\(candidate)', which is not a DID."
            )
        }
        return candidate
    }

    // MARK: - DID documents

    private enum DocumentSource {
        case plc(URL)
        case web(URL)
    }

    /// Syntax, then method, then the method's own rules; nothing here touches the network.
    private func documentSource(for did: String) throws -> DocumentSource {
        guard Self.isStrictlyValidDID(did), let parsed = try? DID(didString: did) else {
            throw IdentityError.invalidDIDSyntax(did)
        }
        switch parsed.method {
        case "plc":
            return .plc(try plcDocumentURL(for: did))
        case "web":
            do {
                let web = try DIDWebIdentifier(did, allowingDevelopmentHosts: options.allowsDevelopmentIdentifiers)
                return .web(web.documentURL)
            } catch DIDWebIdentifier.ValidationError.pathNotSupported {
                throw IdentityError.unsupportedDIDWebPath(did)
            } catch let reason as DIDWebIdentifier.ValidationError {
                throw IdentityError.invalidDIDWeb(did: did, reason: reason)
            }
        default:
            throw IdentityError.unsupportedDIDMethod(did: did, method: parsed.method)
        }
    }

    /// `<PLC directory>/<did>`, with the DID as a single percent-encoded path segment.
    private func plcDocumentURL(for did: String) throws -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        guard var components = URLComponents(url: options.plcDirectoryURL, resolvingAgainstBaseURL: false),
              let segment = did.addingPercentEncoding(withAllowedCharacters: allowed)
        else {
            throw IdentityError.invalidDIDSyntax(did)
        }
        let base = components.percentEncodedPath.hasSuffix("/")
            ? String(components.percentEncodedPath.dropLast())
            : components.percentEncodedPath
        components.percentEncodedPath = base + "/" + segment
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw IdentityError.invalidDIDSyntax(did)
        }
        return url
    }

    private func fetchDIDDocument(_ did: String, from source: DocumentSource) async throws -> DIDDocument {
        let url: URL
        let isPLC: Bool
        switch source {
        case let .plc(plcURL): (url, isPLC) = (plcURL, true)
        case let .web(webURL): (url, isPLC) = (webURL, false)
        }
        let response: IdentityHTTPResponse
        do {
            response = try await http.send(IdentityHTTPRequest(
                url: url,
                accept: "application/did+ld+json,application/json",
                timeout: options.timeout,
                maximumResponseBytes: options.maximumDocumentBytes,
                followsRedirects: false
            ))
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as IdentityError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw IdentityError.transport(url: url.absoluteString, reason: String(describing: error))
        }
        switch response.statusCode {
        case 200 ..< 300:
            break
        case 404:
            throw IdentityError.didNotFound(did)
        case 410 where isPLC:
            throw IdentityError.didTombstoned(did)
        default:
            throw IdentityError.unexpectedStatus(url: url.absoluteString, statusCode: response.statusCode)
        }
        let document: DIDDocument
        do {
            document = try JSONDecoder().decode(DIDDocument.self, from: response.body)
        } catch {
            throw IdentityError.invalidDIDDocument(did: did, reason: "The response is not a JSON DID document.")
        }
        guard document.id == did else {
            throw IdentityError.documentIDMismatch(expected: did, actual: document.id)
        }
        return document
    }

    // MARK: - Helpers

    private func age(of date: Date) -> TimeInterval {
        // A clock that moved backwards makes the entry look new; treat that as not fresh.
        let age = now().timeIntervalSince(date)
        return age < 0 ? .infinity : age
    }

    /// Errors that describe the identifier itself rather than a failed attempt to ask about it.
    /// These drop a cached entry; the others may be answered from a stale one.
    private static func isDefinitive(_ error: IdentityError) -> Bool {
        switch error {
        case .transport, .timedOut, .unexpectedStatus, .handleLookupFailed, .blockedByNetworkPolicy, .responseTooLarge:
            return false
        default:
            return true
        }
    }

    /// The DID grammar, checked byte by byte so a trailing line terminator or any other
    /// character outside the grammar cannot slip through.
    static func isStrictlyValidDID(_ did: String) -> Bool {
        let bytes = Array(did.utf8)
        guard bytes.count <= 2048, did.hasPrefix("did:") else { return false }
        let rest = bytes.dropFirst(4)
        guard let methodEnd = rest.firstIndex(of: 58), methodEnd > rest.startIndex else { return false }
        guard rest[..<methodEnd].allSatisfy({ $0 >= 97 && $0 <= 122 }) else { return false }
        let identifier = rest[(methodEnd + 1)...]
        guard let last = identifier.last, last != 58, last != 37 else { return false }
        return identifier.allSatisfy { byte in
            switch byte {
            case 48 ... 57, 65 ... 90, 97 ... 122, 46, 95, 58, 37, 45: return true
            default: return false
            }
        }
    }
}
