import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCore
import PetrelCrypto

/// Where a ``PLCDirectoryClient`` connects, and the bounds it applies.
///
/// ``production(origin:timeout:maximumStateBytes:maximumAuditBytes:maximumSubmitResponseBytes:maximumExportBytes:operationLimits:allowsNonDefaultPort:)``
/// targets a public directory over HTTPS and defaults to
/// `https://plc.directory`; pass another origin for a mirror or a private
/// directory.
/// ``laboratory(origin:submitSuccessResponsePolicy:allowlistedHost:timeout:maximumStateBytes:maximumAuditBytes:maximumSubmitResponseBytes:maximumExportBytes:operationLimits:)``
/// targets a development directory over plain HTTP on a loopback address.
public struct PLCClientConfiguration: Sendable, Equatable {
    /// `https://plc.directory`.
    public static let defaultProductionOrigin = URL(string: "https://plc.directory")!

    /// The largest response bound any request may ask a transport for.
    public static let maximumResponseBytesCeiling = 64 * 1_024 * 1_024

    /// The directory's origin: scheme, host and optional port, no path.
    public let origin: URL
    /// Per-request timeout in seconds.
    public let timeout: TimeInterval
    /// Largest accepted body for `GET /:did`, `/:did/data` and
    /// `/:did/log/last`.
    public let maximumStateBytes: Int
    /// Largest accepted body for `GET /:did/log` and `/:did/log/audit`.
    public let maximumAuditBytes: Int
    /// Largest accepted body for the response to `POST /:did`.
    public let maximumSubmitResponseBytes: Int
    /// Largest accepted body for one page of `GET /export`.
    public let maximumExportBytes: Int
    /// How a successful submit response is validated.
    public let submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy
    /// The write rules applied before an operation is submitted.
    public let operationLimits: PLCOperationLimits
    /// Whether this configuration targets a laboratory origin.
    public let isLaboratory: Bool

    private init(
        origin: URL,
        laboratory: Bool,
        allowlistedLaboratoryHost: String? = nil,
        allowsNonDefaultPort: Bool = false,
        submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy,
        timeout: TimeInterval,
        maximumStateBytes: Int,
        maximumAuditBytes: Int,
        maximumSubmitResponseBytes: Int,
        maximumExportBytes: Int,
        operationLimits: PLCOperationLimits
    ) throws {
        let bounds = 1 ... Self.maximumResponseBytesCeiling
        guard timeout > 0, timeout <= 30, timeout.isFinite,
              bounds.contains(maximumStateBytes),
              bounds.contains(maximumAuditBytes),
              bounds.contains(maximumSubmitResponseBytes),
              bounds.contains(maximumExportBytes) else {
            throw PetrelPLCError.malformed("PLC client bounds are invalid")
        }
        guard laboratory || submitSuccessResponsePolicy == .strict else {
            throw PetrelPLCError.malformed(
                "PLC reference submit compatibility requires a laboratory origin"
            )
        }
        self.origin = try Self.validateOrigin(
            origin,
            laboratory: laboratory,
            allowlistedLaboratoryHost: allowlistedLaboratoryHost,
            allowsNonDefaultPort: allowsNonDefaultPort
        )
        self.timeout = timeout
        self.maximumStateBytes = maximumStateBytes
        self.maximumAuditBytes = maximumAuditBytes
        self.maximumSubmitResponseBytes = maximumSubmitResponseBytes
        self.maximumExportBytes = maximumExportBytes
        self.submitSuccessResponsePolicy = submitSuccessResponsePolicy
        self.operationLimits = operationLimits
        self.isLaboratory = laboratory
    }

    /// A directory reached over HTTPS.
    ///
    /// - Parameters:
    ///   - origin: The directory's origin. Must be `https`, must not be a
    ///     loopback address, and must use port 443 unless
    ///     `allowsNonDefaultPort` is set.
    ///   - timeout: Per-request timeout, at most 30 seconds.
    ///   - maximumStateBytes: Bound for document, data and last-operation
    ///     responses.
    ///   - maximumAuditBytes: Bound for operation log and audit log
    ///     responses. An identity may hold thousands of operations.
    ///   - maximumSubmitResponseBytes: Bound for the response to a submit.
    ///   - maximumExportBytes: Bound for one export page. A page holds up to
    ///     1,000 operations of up to 7,500 DAG-CBOR bytes each.
    ///   - operationLimits: Write rules applied before submitting.
    ///     ``PLCOperationLimits/specification`` by default; choose
    ///     ``PLCOperationLimits/referenceDirectory`` to refuse locally what
    ///     the reference server would refuse.
    ///   - allowsNonDefaultPort: Permits an HTTPS origin on a port other
    ///     than 443, for a mirror that listens elsewhere.
    public static func production(
        origin: URL = defaultProductionOrigin,
        timeout: TimeInterval = 5,
        maximumStateBytes: Int = 256 * 1_024,
        maximumAuditBytes: Int = 4 * 1_024 * 1_024,
        maximumSubmitResponseBytes: Int = 64 * 1_024,
        maximumExportBytes: Int = 16 * 1_024 * 1_024,
        operationLimits: PLCOperationLimits = .specification,
        allowsNonDefaultPort: Bool = false
    ) throws -> Self {
        try .init(
            origin: origin,
            laboratory: false,
            allowsNonDefaultPort: allowsNonDefaultPort,
            submitSuccessResponsePolicy: .strict,
            timeout: timeout,
            maximumStateBytes: maximumStateBytes,
            maximumAuditBytes: maximumAuditBytes,
            maximumSubmitResponseBytes: maximumSubmitResponseBytes,
            maximumExportBytes: maximumExportBytes,
            operationLimits: operationLimits
        )
    }

    /// A development directory reached over plain HTTP on a literal
    /// loopback address (or one explicitly allowlisted host), on a port of
    /// 1024 or above.
    public static func laboratory(
        origin: URL,
        submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy = .strict,
        allowlistedHost: String? = nil,
        timeout: TimeInterval = 5,
        maximumStateBytes: Int = 256 * 1_024,
        maximumAuditBytes: Int = 4 * 1_024 * 1_024,
        maximumSubmitResponseBytes: Int = 64 * 1_024,
        maximumExportBytes: Int = 16 * 1_024 * 1_024,
        operationLimits: PLCOperationLimits = .specification
    ) throws -> Self {
        try .init(
            origin: origin,
            laboratory: true,
            allowlistedLaboratoryHost: allowlistedHost,
            submitSuccessResponsePolicy: submitSuccessResponsePolicy,
            timeout: timeout,
            maximumStateBytes: maximumStateBytes,
            maximumAuditBytes: maximumAuditBytes,
            maximumSubmitResponseBytes: maximumSubmitResponseBytes,
            maximumExportBytes: maximumExportBytes,
            operationLimits: operationLimits
        )
    }

    private static func validateOrigin(
        _ origin: URL,
        laboratory: Bool,
        allowlistedLaboratoryHost: String?,
        allowsNonDefaultPort: Bool
    ) throws -> URL {
        guard let components = URLComponents(url: origin, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw PetrelPLCError.malformed("PLC directory must be configured as an origin")
        }
        if laboratory {
            let dotCharacters = CharacterSet(charactersIn: ".")
            let normalizedHost = host.lowercased().trimmingCharacters(in: dotCharacters)
            let normalizedAllowlist = allowlistedLaboratoryHost?.lowercased()
                .trimmingCharacters(in: dotCharacters)
            guard scheme == "http",
                  plcIsLoopbackLiteral(host) ||
                  (normalizedAllowlist != nil && normalizedHost == normalizedAllowlist),
                  let port = components.port, (1_024 ... 65_535).contains(port),
                  allowlistedLaboratoryHost == nil ||
                  (normalizedAllowlist?.isEmpty == false &&
                      normalizedHost == normalizedAllowlist) else {
                throw PetrelPLCError.malformed(
                    "PLC laboratory origin must be an HTTP literal-loopback origin or an explicitly allowlisted lab host"
                )
            }
        } else {
            guard scheme == "https", !plcIsLoopbackLiteral(host) else {
                throw PetrelPLCError.malformed("PLC production origin must use HTTPS")
            }
            if let port = components.port, port != 443 {
                guard allowsNonDefaultPort, (1 ... 65_535).contains(port) else {
                    throw PetrelPLCError.malformed("PLC production origin must use HTTPS on port 443")
                }
            }
        }
        var canonical = components
        canonical.path = ""
        guard let result = canonical.url, !result.absoluteString.hasSuffix("/") else {
            throw PetrelPLCError.malformed("PLC directory origin is malformed")
        }
        return result
    }
}

/// The verified subset of directory access: what an account service needs
/// to register an identity and read back state it can rely on.
///
/// ``PLCDirectoryClient`` is the implementation and offers the complete
/// directory API on top; this protocol exists so that a service can be
/// tested against a stand-in.
public protocol PLCClient: Sendable {
    /// Submits a signed operation for `did`.
    func submit(did: String, operation: PLCSignedOperation) async throws
    /// The identity's current state, checked against its verified audit log.
    func fetchState(did: String) async throws -> PLCDocumentData
    /// The identity's audit log, verified.
    func fetchAudit(did: String) async throws -> [PLCAuditEntry]
    /// As ``fetchAudit(did:)``, returning `nil` for an unregistered DID.
    func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]?
}

public extension PLCClient {
    /// The default implementation forwards to ``fetchAudit(did:)`` and so
    /// throws for an unregistered DID instead of returning `nil`.
    func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]? {
        try await fetchAudit(did: did)
    }
}

/// A client for a did:plc directory.
///
/// **Reading.** Every read endpoint has a direct method that returns what
/// the directory said: ``getDocument(did:)``, ``getDocumentData(did:)``,
/// ``getOperationLog(did:)``, ``getAuditLog(did:)``,
/// ``getLastOperation(did:)``, ``export(after:count:)`` and
/// ``exportSequence(after:pageSize:)``. Operations are decoded leniently, so
/// every operation the public directory serves can be read, legacy `create`
/// operations and tombstones included.
///
/// **Verifying.** ``fetchVerifiedAuditLog(did:)`` and ``fetchState(did:)``
/// return data that has been proven from the operation log rather than
/// taken on the directory's word.
///
/// **Writing.** ``submit(did:operation:)`` posts a signed operation;
/// ``createDID(handle:signingKey:rotationKeys:pdsEndpoint:signer:)``,
/// ``updateHandle(did:signer:handle:)``, ``updatePDS(did:signer:endpoint:)``,
/// ``updateAtprotoKey(did:signer:signingKey:)``,
/// ``updateRotationKeys(did:signer:rotationKeys:)`` and
/// ``tombstone(did:signer:)`` build, sign and submit in one call. Operations
/// to be written are held to ``PLCClientConfiguration/operationLimits``.
///
/// **Errors.** An unregistered DID is ``PetrelPLCError/notFound(did:)``, a
/// deactivated one ``PetrelPLCError/tombstoned(did:)``, a refused request
/// ``PetrelPLCError/rejected(status:message:)`` carrying the directory's
/// explanation.
public struct PLCDirectoryClient: PLCClient, Sendable {
    /// The directory this client talks to, and its bounds.
    public let configuration: PLCClientConfiguration
    private let transport: any PLCHTTPTransport

    /// - Parameters:
    ///   - configuration: The directory and bounds.
    ///   - transport: The HTTP implementation. Supply your own to route
    ///     through a different HTTP stack, or a stub in tests.
    public init(
        configuration: PLCClientConfiguration,
        transport: any PLCHTTPTransport
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    /// Creates a client that uses `URLSession`.
    public init(configuration: PLCClientConfiguration) throws {
        self.configuration = configuration
        transport = try URLSessionPLCTransport(maximumTimeout: configuration.timeout)
    }

    /// Creates a client for the public directory at `https://plc.directory`,
    /// using `URLSession`.
    public init() throws {
        try self.init(configuration: .production())
    }

    // MARK: Read endpoints

    /// `GET /:did` — the DID document the directory renders.
    ///
    /// The document is not verified: it is the directory's presentation of
    /// the identity. See ``PLCDIDDocument``.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``,
    ///   ``PetrelPLCError/tombstoned(did:)``.
    public func getDocument(did: String) async throws -> PLCDIDDocument {
        let body = try await get(
            did: did,
            suffix: [],
            accept: "application/did+ld+json, application/json",
            contentTypes: [
                "application/did+ld+json", "application/did+json",
                "application/ld+json", "application/json",
            ],
            maximumBytes: configuration.maximumStateBytes
        )
        try StrictJSON.validate(body)
        guard let document = try? JSONDecoder().decode(PLCDIDDocument.self, from: body),
              document.id == did else {
            throw PetrelPLCError.malformed("PLC DID document is malformed")
        }
        return document
    }

    /// `GET /:did/data` — the identity's current state as the directory
    /// reports it, without verification. ``fetchState(did:)`` is the
    /// verified equivalent.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``,
    ///   ``PetrelPLCError/tombstoned(did:)``.
    public func getDocumentData(did: String) async throws -> PLCDocumentData {
        let body = try await getJSON(
            did: did, suffix: ["data"], maximumBytes: configuration.maximumStateBytes
        )
        return try decodeState(body, expectedDID: did)
    }

    /// `GET /:did/log` — the currently valid operations, oldest first,
    /// without verification. Pass the result to
    /// ``PLCAuditLogVerifier/validateOperationLog(_:did:)`` to verify it.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``.
    public func getOperationLog(did: String) async throws -> [PLCSignedOperation] {
        let body = try await getJSON(
            did: did, suffix: ["log"], maximumBytes: configuration.maximumAuditBytes
        )
        guard let rawOperations = try? JSONSerialization.jsonObject(with: body) as? [Any],
              !rawOperations.isEmpty,
              rawOperations.count <= PLCAuditLogVerifier.maximumEntries else {
            throw PetrelPLCError.malformed("PLC operation log is malformed")
        }
        return try rawOperations.map { try PLCOperationCodec.decodeSigned(jsonObject: $0) }
    }

    /// `GET /:did/log/audit` — every operation the directory holds for the
    /// identity, nullified ones included, with the directory's own
    /// `nullified` flags and without verifying signatures.
    /// ``fetchVerifiedAuditLog(did:)`` is the verified equivalent.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``.
    public func getAuditLog(did: String) async throws -> [PLCAuditEntry] {
        let body = try await getJSON(
            did: did, suffix: ["log", "audit"], maximumBytes: configuration.maximumAuditBytes
        )
        return try PLCAuditLogVerifier.decode(body, did: did)
    }

    /// `GET /:did/log/last` — the newest valid operation, without
    /// verification. This is the operation an update names in `prev`; the
    /// updaters on this client take it from the verified audit log instead.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``.
    public func getLastOperation(did: String) async throws -> PLCSignedOperation {
        let body = try await getJSON(
            did: did, suffix: ["log", "last"], maximumBytes: configuration.maximumStateBytes
        )
        guard let object = try? JSONSerialization.jsonObject(with: body) else {
            throw PetrelPLCError.malformed("PLC operation JSON is malformed")
        }
        return try PLCOperationCodec.decodeSigned(jsonObject: object)
    }

    /// `GET /export` — one page of the directory-wide operation log.
    ///
    /// Each entry's CID is checked against its operation.
    ///
    /// - Parameters:
    ///   - after: Where to start. `.sequence(_:)` selects the current
    ///     `sequenced_op` format; `.sequence(0)` is the first page. A
    ///     `.timestamp(_:)`, or `nil`, selects the legacy format.
    ///   - count: Page size, 1–1000.
    /// - Returns: Up to `count` entries; empty when nothing follows `after`.
    ///   Continue with the ``PLCExportEntry/cursor`` of the last entry.
    public func export(
        after: PLCExportCursor? = nil,
        count: Int = 1_000
    ) async throws -> [PLCExportEntry] {
        guard (1 ... 1_000).contains(count) else {
            throw PetrelPLCError.malformed("PLC export count must be 1...1000")
        }
        var query = [URLQueryItem(name: "count", value: String(count))]
        if let after {
            if case let .timestamp(value) = after, plcTimestampMilliseconds(value) == nil {
                throw PetrelPLCError.malformed(
                    "PLC export timestamp cursor must be YYYY-MM-DDTHH:mm:ss.sssZ"
                )
            }
            query.append(URLQueryItem(name: "after", value: after.description))
        }
        let request = try PLCHTTPRequest(
            method: .get,
            url: endpoint(path: ["export"], query: query),
            headers: ["accept": "application/jsonlines, application/json"],
            body: nil,
            timeout: configuration.timeout,
            maximumResponseBytes: configuration.maximumExportBytes
        )
        let response = try await transport.execute(request)
        try validate(
            response,
            for: request,
            did: nil,
            contentTypes: [
                "application/jsonlines", "application/jsonl", "application/x-ndjson",
                "application/x-jsonlines", "application/json", "text/plain",
            ],
            permitsEmptyBody: true
        )
        return try PLCExportEntry.decode(jsonLines: response.body)
    }

    /// The directory-wide operation log as an asynchronous sequence that
    /// requests `GET /export` pages as it is consumed.
    ///
    /// Pages are fetched only when the consumer asks for the next element,
    /// so a slow consumer does not accumulate pages in memory. The sequence
    /// ends when it reaches the newest operation; to follow the log, start
    /// another one from the last entry's ``PLCExportEntry/cursor``.
    ///
    /// ```swift
    /// for try await entry in client.exportSequence(after: .sequence(0)) {
    ///     index(entry.did, entry.operation)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - after: Where to start; the beginning by default. A timestamp
    ///     cursor selects the legacy format, in which operations sharing a
    ///     millisecond with a page boundary can be skipped — prefer sequence
    ///     numbers.
    ///   - pageSize: Operations per request, 1–1000.
    public func exportSequence(
        after: PLCExportCursor = .sequence(0),
        pageSize: Int = 1_000
    ) -> PLCExportSequence {
        PLCExportSequence(client: self, start: after, pageSize: pageSize)
    }

    // MARK: Verified reads

    /// Fetches the audit log and verifies it: see
    /// ``PLCAuditLogVerifier/verify(_:did:)``.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``;
    ///   ``PetrelPLCError/unauthorized(_:)`` if the log does not verify.
    public func fetchVerifiedAuditLog(did: String) async throws -> PLCVerifiedAuditLog {
        try await PLCAuditLogVerifier.verify(getAuditLog(did: did), did: did)
    }

    /// The verified audit log's entries, with `nullified` recomputed.
    public func fetchAudit(did: String) async throws -> [PLCAuditEntry] {
        try await fetchVerifiedAuditLog(did: did).entries
    }

    /// As ``fetchAudit(did:)``, returning `nil` for an unregistered DID.
    public func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]? {
        do {
            return try await fetchAudit(did: did)
        } catch PetrelPLCError.notFound {
            return nil
        }
    }

    /// The identity's current state, proven: `GET /:did/data` must equal
    /// the state established by the newest valid operation of the verified
    /// audit log.
    ///
    /// - Throws: ``PetrelPLCError/notFound(did:)``,
    ///   ``PetrelPLCError/tombstoned(did:)``;
    ///   ``PetrelPLCError/unauthorized(_:)`` if the data and the log disagree.
    public func fetchState(did: String) async throws -> PLCDocumentData {
        let state = try await getDocumentData(did: did)
        let log = try await fetchVerifiedAuditLog(did: did)
        guard let proven = log.documentData else {
            throw PetrelPLCError.tombstoned(did: did)
        }
        guard state == proven else {
            throw PetrelPLCError.unauthorized("PLC document data does not match its audit log")
        }
        return state
    }

    // MARK: Submit

    /// `POST /:did` — submits a signed operation.
    ///
    /// Before anything is sent the operation is held to the write rules
    /// (``PLCClientConfiguration/operationLimits``), and a genesis operation
    /// must hash to `did` and carry a valid signature. Whether an update is
    /// signed by a current rotation key is for the directory to decide; the
    /// updaters on this client check it first.
    ///
    /// Against a production origin, a success status is not taken as proof:
    /// the audit log is read back and verified, and the newest valid
    /// operation must be the one submitted.
    ///
    /// - Throws: ``PetrelPLCError/rejected(status:message:)`` when the
    ///   directory refuses the operation;
    ///   ``PetrelPLCError/submittedButUnconfirmed(cid:reason:)`` when it
    ///   accepted but the confirming read failed;
    ///   ``PetrelPLCError/unauthorized(_:)`` when the confirmed log does not
    ///   end in the submitted operation.
    public func submit(did: String, operation: PLCSignedOperation) async throws {
        try PLCOperationCodec.validateCanonicalDID(did)
        try PLCOperationCodec.validateForSubmission(operation, limits: configuration.operationLimits)
        if operation.prev == nil {
            try PLCOperationCodec.verifyGenesis(operation, expectedDID: did)
        }
        let body = try operation.canonicalJSON
        guard try PLCOperationCodec.decodeSignedJSON(body) == operation else {
            throw PetrelPLCError.malformed("PLC operation is not canonical")
        }
        let request = try PLCHTTPRequest(
            method: .post,
            url: endpoint(did: did, suffix: []),
            headers: [
                "accept": "application/json",
                "content-type": "application/json",
            ],
            body: body,
            timeout: configuration.timeout,
            maximumResponseBytes: configuration.maximumSubmitResponseBytes
        )
        let response = try await transport.execute(request)
        switch try validateSubmitResponse(response, for: request, did: did) {
        case .verified:
            return
        case .requiresDirectoryConfirmation:
            try await confirmSubmittedOperation(did: did, operation: operation)
        }
    }

    /// Confirms a submit whose response body carried nothing authenticatable
    /// by re-reading the directory's own audit log. The active terminal
    /// operation must be exactly the operation just submitted, so a submit is
    /// reported as successful only against verified directory state rather
    /// than against an unauthenticated acknowledgement body.
    private func confirmSubmittedOperation(
        did: String,
        operation: PLCSignedOperation
    ) async throws {
        let submitted = try operation.cid.string
        let log: PLCVerifiedAuditLog
        do {
            log = try await fetchVerifiedAuditLog(did: did)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The directory said yes and the read-back failed. That is not a
            // rejection, and reporting it as one would invite a blind retry
            // of an operation that is probably registered.
            throw PetrelPLCError.submittedButUnconfirmed(
                cid: submitted,
                reason: String(describing: error)
            )
        }
        guard log.head.cid == submitted else {
            // `.unauthorized` keeps this off the retryable `.unavailable`
            // shape: retrying a DID-creating POST is the one response this
            // must never invite.
            throw PetrelPLCError.unauthorized(
                "PLC directory did not record the submitted operation"
            )
        }
    }

    // MARK: Requests

    private func getJSON(did: String, suffix: [String], maximumBytes: Int) async throws -> Data {
        let body = try await get(
            did: did,
            suffix: suffix,
            accept: "application/json",
            contentTypes: ["application/json"],
            maximumBytes: maximumBytes
        )
        try StrictJSON.validate(body)
        return body
    }

    private func get(
        did: String,
        suffix: [String],
        accept: String,
        contentTypes: Set<String>,
        maximumBytes: Int
    ) async throws -> Data {
        let request = try PLCHTTPRequest(
            method: .get,
            url: endpoint(did: did, suffix: suffix),
            headers: ["accept": accept],
            body: nil,
            timeout: configuration.timeout,
            maximumResponseBytes: maximumBytes
        )
        let response = try await transport.execute(request)
        try validate(
            response, for: request, did: did, contentTypes: contentTypes, permitsEmptyBody: false
        )
        return response.body
    }

    private func endpoint(did: String, suffix: [String]) throws -> URL {
        try PLCOperationCodec.validateCanonicalDID(did)
        return try endpoint(path: [did] + suffix, query: [])
    }

    private func endpoint(path: [String], query: [URLQueryItem]) throws -> URL {
        // `URL.appendingPathComponent` percent-encodes `:` on Linux but not
        // Darwin. PLC's route is literally `/:did`, so construct the already
        // validated path explicitly and make its wire representation stable
        // across Foundation implementations.
        guard path.allSatisfy({ !$0.isEmpty && !$0.contains("/") }),
              var components = URLComponents(
                  url: configuration.origin,
                  resolvingAgainstBaseURL: false
              ) else {
            throw PetrelPLCError.malformed("PLC request URL is invalid")
        }
        components.percentEncodedPath = "/" + path.joined(separator: "/")
        if !query.isEmpty {
            // `URLComponents` leaves `:` and `+` unescaped in a query; escape
            // everything outside the unreserved set so a timestamp cursor has
            // one wire form on every platform.
            let unreserved = CharacterSet(
                charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
            )
            components.percentEncodedQuery = try query.map { item in
                guard let name = item.name.addingPercentEncoding(withAllowedCharacters: unreserved),
                      let value = (item.value ?? "")
                      .addingPercentEncoding(withAllowedCharacters: unreserved) else {
                    throw PetrelPLCError.malformed("PLC request URL is invalid")
                }
                return "\(name)=\(value)"
            }.joined(separator: "&")
        }
        guard let url = components.url,
              url.host == configuration.origin.host,
              url.scheme == configuration.origin.scheme,
              url.port == configuration.origin.port,
              url.fragment == nil,
              query.isEmpty == (url.query == nil) else {
            throw PetrelPLCError.malformed("PLC request URL is invalid")
        }
        return url
    }

    /// Checks a response in the order that matters: it must come from the
    /// requested URL without a redirect and fit its bound before its status
    /// is believed, and its status is mapped before its body is parsed.
    private func validate(
        _ response: PLCHTTPResponse,
        for request: PLCHTTPRequest,
        did: String?,
        contentTypes: Set<String>,
        permitsEmptyBody: Bool
    ) throws {
        guard response.redirectCount == 0,
              response.finalURL == request.url else {
            throw PetrelPLCError.unauthorized("PLC directory redirects are forbidden")
        }
        guard response.body.count <= request.maximumResponseBytes else {
            throw PetrelPLCError.unavailable("PLC directory response exceeded its bound")
        }
        guard (200 ... 299).contains(response.status) else {
            throw Self.failure(for: response, did: did)
        }
        if permitsEmptyBody, response.body.isEmpty {
            return
        }
        guard let contentType = Self.mediaType(of: response), contentTypes.contains(contentType) else {
            throw PetrelPLCError.malformed("PLC directory response has an unexpected content type")
        }
    }

    private static func mediaType(of response: PLCHTTPResponse) -> String? {
        response.headers["content-type"]?
            .split(separator: ";", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Maps a non-success status to a typed error.
    ///
    /// The reference server answers `404 {"message":"DID not registered: …"}`
    /// for an unknown DID and `404 {"message":"DID not available: …"}` for a
    /// tombstoned one; `410 Gone` is treated as tombstoned as well.
    static func failure(for response: PLCHTTPResponse, did: String?) -> PetrelPLCError {
        let message = directoryMessage(response.body)
        switch response.status {
        case 404:
            guard let did else {
                return .rejected(status: 404, message: message ?? "")
            }
            return message?.contains("not available") == true
                ? .tombstoned(did: did)
                : .notFound(did: did)
        case 410:
            guard let did else {
                return .rejected(status: 410, message: message ?? "")
            }
            return .tombstoned(did: did)
        case 429:
            return .rateLimited(
                retryAfterSeconds: response.headers["retry-after"]
                    .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            )
        case 400 ... 499:
            return .rejected(status: response.status, message: message ?? "")
        default:
            return .unavailable("PLC directory returned HTTP \(response.status)")
        }
    }

    /// The `message` of the reference server's `{"message": …}` error body.
    private static func directoryMessage(_ body: Data) -> String? {
        guard !body.isEmpty,
              body.count <= 64 * 1_024,
              (try? StrictJSON.validate(body)) != nil,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let message = object["message"] as? String else {
            return nil
        }
        return String(message.prefix(1_024))
    }

    /// Whether a submit response authenticated itself, or whether the submit
    /// must still be confirmed against directory state before it may be
    /// reported as successful.
    private enum PLCSubmitAcceptance {
        case verified
        case requiresDirectoryConfirmation
    }

    private func validateSubmitResponse(
        _ response: PLCHTTPResponse,
        for request: PLCHTTPRequest,
        did: String
    ) throws -> PLCSubmitAcceptance {
        guard response.redirectCount == 0,
              response.finalURL == request.url else {
            throw PetrelPLCError.unauthorized("PLC directory redirects are forbidden")
        }
        guard response.body.count <= request.maximumResponseBytes else {
            throw PetrelPLCError.unavailable("PLC directory response exceeded its bound")
        }
        guard (200 ... 299).contains(response.status) else {
            // A refused operation is never "not found": the directory is
            // answering about the operation, not about the DID.
            let failure = Self.failure(for: response, did: nil)
            throw failure
        }

        switch configuration.submitSuccessResponsePolicy {
        case .didPLCServer001:
            guard response.status == 200 else {
                throw PetrelPLCError.unavailable(
                    "PLC directory returned an incompatible submit status"
                )
            }
            guard response.headers["content-type"] == "text/plain; charset=utf-8",
                  response.body == Data([0x4F, 0x4B]) else {
                throw PetrelPLCError.malformed(
                    "PLC directory returned an incompatible submit response"
                )
            }
            return .verified
        case .strict:
            break
        }

        // No submit acknowledgement authenticates anything: PLC issues no
        // signed receipt, so an empty body, `{}`, and the production
        // directory's `sendStatus(200)` plain text are equally unproven. A
        // production submit is therefore never accepted on the strength of
        // its acknowledgement; success is established only by re-reading the
        // directory's verified audit log. Rejecting an unparseable
        // acknowledgement outright would instead abort after the directory
        // had already accepted the operation, stranding a registered DID with
        // no local record.
        guard configuration.isLaboratory else {
            return .requiresDirectoryConfirmation
        }

        // A laboratory origin keeps the historical shape checks: reaching the
        // pinned reference server under strict policy is an operator error,
        // and `didPLCServer001` is the explicit opt-in for it.
        if response.body.isEmpty {
            return .verified
        }
        guard Self.mediaType(of: response) == "application/json" else {
            throw PetrelPLCError.malformed("PLC directory response is not JSON")
        }
        try StrictJSON.validate(response.body)
        return .verified
    }

    private func decodeState(_ data: Data, expectedDID: String) throws -> PLCDocumentData {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let did = object["did"] as? String,
              did == expectedDID,
              let rotationKeys = object["rotationKeys"] as? [String],
              let verificationMethods = object["verificationMethods"] as? [String: String],
              let alsoKnownAs = object["alsoKnownAs"] as? [String],
              let rawServices = object["services"] as? [String: Any] else {
            throw PetrelPLCError.malformed("PLC document data is malformed")
        }
        return try .init(
            did: did,
            rotationKeys: rotationKeys,
            verificationMethods: verificationMethods,
            alsoKnownAs: alsoKnownAs,
            services: PLCOperationCodec.decodeServices(rawServices)
        )
    }
}

/// The directory-wide operation log, fetched one `GET /export` page at a
/// time as it is iterated. Create one with
/// ``PLCDirectoryClient/exportSequence(after:pageSize:)``.
public struct PLCExportSequence: AsyncSequence, Sendable {
    /// One exported operation.
    public typealias Element = PLCExportEntry

    let client: PLCDirectoryClient
    let start: PLCExportCursor
    let pageSize: Int

    /// Starts an iteration from the sequence's starting cursor.
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(client: client, cursor: start, pageSize: pageSize)
    }

    /// Fetches export pages as elements are requested.
    public struct AsyncIterator: AsyncIteratorProtocol {
        let client: PLCDirectoryClient
        let pageSize: Int
        /// The cursor the next request will use: the position after the
        /// last entry fetched. Save it to resume later.
        public private(set) var cursor: PLCExportCursor
        private var buffer = ArraySlice<PLCExportEntry>()
        private var reachedEnd = false

        init(client: PLCDirectoryClient, cursor: PLCExportCursor, pageSize: Int) {
            self.client = client
            self.cursor = cursor
            self.pageSize = pageSize
        }

        /// The next exported operation, fetching the next page when the
        /// current one is used up. `nil` once the newest operation has been
        /// returned.
        public mutating func next() async throws -> PLCExportEntry? {
            if let entry = buffer.popFirst() {
                return entry
            }
            guard !reachedEnd else { return nil }
            try Task.checkCancellation()
            let page = try await client.export(after: cursor, count: pageSize)
            // A short page means the newest operation has been reached.
            reachedEnd = page.count < pageSize
            guard let last = page.last else { return nil }
            cursor = last.cursor
            buffer = page[...]
            return buffer.popFirst()
        }
    }
}
