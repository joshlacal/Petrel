import Foundation
import Petrel
import PetrelCrypto

public enum PLCHTTPMethod: String, Sendable, Equatable {
    case get = "GET"
    case post = "POST"
}

public struct PLCHTTPRequest: Sendable, Equatable {
    public let method: PLCHTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
    public let maximumResponseBytes: Int

    public init(
        method: PLCHTTPMethod,
        url: URL,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval,
        maximumResponseBytes: Int
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.maximumResponseBytes = maximumResponseBytes
    }
}

public struct PLCHTTPResponse: Sendable, Equatable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data
    public let finalURL: URL?
    public let redirectCount: Int

    public init(
        status: Int,
        headers: [String: String],
        body: Data,
        finalURL: URL? = nil,
        redirectCount: Int = 0
    ) {
        self.status = status
        self.headers = headers
        self.body = body
        self.finalURL = finalURL
        self.redirectCount = redirectCount
    }
}

public protocol PLCHTTPTransport: Sendable {
    func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse
}

/// Validation applied only to a successful `POST /:did` response.
///
/// The compatibility case is deliberately named after the one pinned package
/// whose Express handler uses `sendStatus(200)`. It is not a general
/// `text/plain` allowance and cannot be selected for a production origin.
public enum PLCSubmitSuccessResponsePolicy: String, Sendable, Equatable {
    case strict
    case didPLCServer001 = "did-plc-server-0.0.1"
}

private final class DisallowRedirectsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Disallow redirects by passing nil
        completionHandler(nil)
    }
}

public final class URLSessionPLCTransport: PLCHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private let delegate: DisallowRedirectsDelegate
    private let maximumTimeout: TimeInterval

    public init(maximumTimeout: TimeInterval = 10) throws {
        guard maximumTimeout > 0, maximumTimeout <= 30, maximumTimeout.isFinite else {
            throw PetrelPLCError.malformed("PLC HTTP transport timeout is invalid")
        }
        self.maximumTimeout = maximumTimeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = maximumTimeout
        configuration.timeoutIntervalForResource = maximumTimeout
        self.delegate = DisallowRedirectsDelegate()
        self.session = URLSession(configuration: configuration)
    }

    public func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse {
        guard request.timeout > 0,
              request.timeout <= maximumTimeout,
              request.timeout.isFinite,
              (1 ... 1_048_576).contains(request.maximumResponseBytes),
              request.body?.count ?? 0 <= 32 * 1_024 else {
            throw PetrelPLCError.malformed("PLC HTTP request bounds are invalid")
        }

        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        if let body = request.body {
            urlRequest.httpBody = body
        }
        urlRequest.timeoutInterval = request.timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest, delegate: delegate)
        } catch {
            throw PetrelPLCError.unavailable("PLC HTTP request failed")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PetrelPLCError.unavailable("PLC HTTP request failed")
        }

        guard data.count <= request.maximumResponseBytes else {
            throw PetrelPLCError.unavailable("PLC HTTP response exceeded its bound")
        }

        var headers = [String: String]()
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                let name = keyString.lowercased()
                if headers[name] == nil {
                    headers[name] = valueString
                } else {
                    headers[name, default: ""].append(",\(valueString)")
                }
            }
        }

        return PLCHTTPResponse(
            status: httpResponse.statusCode,
            headers: headers,
            body: data,
            finalURL: httpResponse.url,
            redirectCount: 0
        )
    }
}

public typealias AsyncHTTPClientPLCTransport = URLSessionPLCTransport

public struct PLCClientConfiguration: Sendable, Equatable {
    public static let defaultProductionOrigin = URL(string: "https://plc.directory")!

    public let origin: URL
    public let timeout: TimeInterval
    public let maximumStateBytes: Int
    public let maximumAuditBytes: Int
    public let maximumSubmitResponseBytes: Int
    public let submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy
    /// Whether this configuration targets a laboratory origin.
    public let isLaboratory: Bool

    private init(
        origin: URL,
        laboratory: Bool,
        allowlistedLaboratoryHost: String? = nil,
        submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy,
        timeout: TimeInterval,
        maximumStateBytes: Int,
        maximumAuditBytes: Int,
        maximumSubmitResponseBytes: Int
    ) throws {
        guard timeout > 0, timeout <= 30, timeout.isFinite,
              (1 ... 1_048_576).contains(maximumStateBytes),
              (1 ... 1_048_576).contains(maximumAuditBytes),
              (1 ... 1_048_576).contains(maximumSubmitResponseBytes) else {
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
            allowlistedLaboratoryHost: allowlistedLaboratoryHost
        )
        self.timeout = timeout
        self.maximumStateBytes = maximumStateBytes
        self.maximumAuditBytes = maximumAuditBytes
        self.maximumSubmitResponseBytes = maximumSubmitResponseBytes
        self.submitSuccessResponsePolicy = submitSuccessResponsePolicy
        self.isLaboratory = laboratory
    }

    public static func production(
        origin: URL = defaultProductionOrigin,
        timeout: TimeInterval = 5,
        maximumStateBytes: Int = 256 * 1_024,
        maximumAuditBytes: Int = 512 * 1_024,
        maximumSubmitResponseBytes: Int = 64 * 1_024
    ) throws -> Self {
        try .init(
            origin: origin,
            laboratory: false,
            submitSuccessResponsePolicy: .strict,
            timeout: timeout,
            maximumStateBytes: maximumStateBytes,
            maximumAuditBytes: maximumAuditBytes,
            maximumSubmitResponseBytes: maximumSubmitResponseBytes
        )
    }

    public static func laboratory(
        origin: URL,
        submitSuccessResponsePolicy: PLCSubmitSuccessResponsePolicy = .strict,
        allowlistedHost: String? = nil,
        timeout: TimeInterval = 5,
        maximumStateBytes: Int = 256 * 1_024,
        maximumAuditBytes: Int = 512 * 1_024,
        maximumSubmitResponseBytes: Int = 64 * 1_024
    ) throws -> Self {
        try .init(
            origin: origin,
            laboratory: true,
            allowlistedLaboratoryHost: allowlistedHost,
            submitSuccessResponsePolicy: submitSuccessResponsePolicy,
            timeout: timeout,
            maximumStateBytes: maximumStateBytes,
            maximumAuditBytes: maximumAuditBytes,
            maximumSubmitResponseBytes: maximumSubmitResponseBytes
        )
    }

    private static func validateOrigin(
        _ origin: URL,
        laboratory: Bool,
        allowlistedLaboratoryHost: String? = nil
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
                  (plcIsLoopbackLiteral(host) ||
                      (normalizedAllowlist != nil && normalizedHost == normalizedAllowlist)),
                  let port = components.port, (1_024 ... 65_535).contains(port),
                  allowlistedLaboratoryHost == nil ||
                      (normalizedAllowlist?.isEmpty == false &&
                          normalizedHost == normalizedAllowlist) else {
                throw PetrelPLCError.malformed(
                    "PLC laboratory origin must be an HTTP literal-loopback origin or an explicitly allowlisted lab host"
                )
            }
        } else {
            guard scheme == "https", !plcIsLoopbackLiteral(host),
                  components.port == nil || components.port == 443 else {
                throw PetrelPLCError.malformed("PLC production origin must use HTTPS on port 443")
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

public struct PLCDocumentData: Sendable, Equatable {
    public let did: String
    public let rotationKeys: [String]
    public let verificationMethods: [String: String]
    public let alsoKnownAs: [String]
    public let services: [String: PLCService]

    public init(
        did: String,
        rotationKeys: [String],
        verificationMethods: [String: String],
        alsoKnownAs: [String],
        services: [String: PLCService]
    ) {
        self.did = did
        self.rotationKeys = rotationKeys
        self.verificationMethods = verificationMethods
        self.alsoKnownAs = alsoKnownAs
        self.services = services
    }
}

public struct PLCAuditEntry: Sendable, Equatable {
    public let did: String
    public let operation: PLCSignedOperation
    public let cid: String
    public let nullified: Bool
    public let createdAt: String

    public init(
        did: String,
        operation: PLCSignedOperation,
        cid: String,
        nullified: Bool,
        createdAt: String
    ) {
        self.did = did
        self.operation = operation
        self.cid = cid
        self.nullified = nullified
        self.createdAt = createdAt
    }
}

public protocol PLCClient: Sendable {
    func submit(did: String, operation: PLCSignedOperation) async throws
    func fetchState(did: String) async throws -> PLCDocumentData
    func fetchAudit(did: String) async throws -> [PLCAuditEntry]
    func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]?
}

public extension PLCClient {
    func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]? {
        try await fetchAudit(did: did)
    }
}

public struct PLCDirectoryClient: PLCClient, Sendable {
    public let configuration: PLCClientConfiguration
    private let transport: any PLCHTTPTransport

    public init(
        configuration: PLCClientConfiguration,
        transport: any PLCHTTPTransport
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    public init(configuration: PLCClientConfiguration) throws {
        self.configuration = configuration
        self.transport = try URLSessionPLCTransport(maximumTimeout: configuration.timeout)
    }

    public func submit(did: String, operation: PLCSignedOperation) async throws {
        try PLCOperationCodec.validateCanonicalDID(did)
        if operation.prev == nil {
            try PLCOperationCodec.verifyGenesis(operation, expectedDID: did)
        } else {
            // This proves structural/canonical constraints without pretending
            // to know the previous operation's authorized rotation keys.
            let reparsed = try PLCOperationCodec.decodeSignedJSON(operation.canonicalJSON)
            guard reparsed == operation else {
                throw PetrelPLCError.malformed("PLC operation is not canonical")
            }
        }
        let request = PLCHTTPRequest(
            method: .post,
            url: try endpoint(did: did, suffix: []),
            headers: [
                "accept": "application/json",
                "content-type": "application/json",
            ],
            body: try operation.canonicalJSON,
            timeout: configuration.timeout,
            maximumResponseBytes: configuration.maximumSubmitResponseBytes
        )
        let response = try await transport.execute(request)
        switch try validateSubmitResponse(response, for: request) {
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
        let audit = try await fetchAudit(did: did)
        guard let terminal = audit.last(where: { !$0.nullified }),
              terminal.cid == submitted else {
            // `.unauthorized` matches this file's convention for an audit
            // mismatch (see `fetchState`), and keeps the failure off the
            // retryable `.unavailable` shape: retrying a DID-creating POST is
            // the one response this must never invite.
            throw PetrelPLCError.unauthorized(
                "PLC directory did not record the submitted operation"
            )
        }
    }

    public func fetchState(did: String) async throws -> PLCDocumentData {
        try PLCOperationCodec.validateCanonicalDID(did)
        let request = PLCHTTPRequest(
            method: .get,
            url: try endpoint(did: did, suffix: ["data"]),
            headers: ["accept": "application/json"],
            body: nil,
            timeout: configuration.timeout,
            maximumResponseBytes: configuration.maximumStateBytes
        )
        let response = try await transport.execute(request)
        try validateResponse(response, for: request, permitsEmptyBody: false)
        let state = try decodeState(response.body, expectedDID: did)
        let audit = try await fetchAudit(did: did)
        guard let activeTerminal = audit.last(where: { !$0.nullified }),
              let regular = activeTerminal.operation.regular,
              state.rotationKeys == regular.rotationKeys,
              state.verificationMethods == regular.verificationMethods,
              state.alsoKnownAs == regular.alsoKnownAs,
              state.services == regular.services else {
            throw PetrelPLCError.unauthorized("PLC document data does not match its audit log")
        }
        return state
    }

    public func fetchAudit(did: String) async throws -> [PLCAuditEntry] {
        guard let audit = try await fetchAuditIfPresent(did: did) else {
            throw PetrelPLCError.unavailable("PLC identity is not registered")
        }
        return audit
    }

    public func fetchAuditIfPresent(did: String) async throws -> [PLCAuditEntry]? {
        try PLCOperationCodec.validateCanonicalDID(did)
        let request = PLCHTTPRequest(
            method: .get,
            url: try endpoint(did: did, suffix: ["log", "audit"]),
            headers: ["accept": "application/json"],
            body: nil,
            timeout: configuration.timeout,
            maximumResponseBytes: configuration.maximumAuditBytes
        )
        let response = try await transport.execute(request)
        if response.status == 404 {
            guard response.redirectCount == 0,
                  response.finalURL == request.url,
                  response.body.count <= request.maximumResponseBytes else {
                throw PetrelPLCError.unauthorized("PLC directory missing response is invalid")
            }
            return nil
        }
        try validateResponse(response, for: request, permitsEmptyBody: false)
        return try decodeAndVerifyAudit(response.body, expectedDID: did)
    }

    private func endpoint(did: String, suffix: [String]) throws -> URL {
        try PLCOperationCodec.validateCanonicalDID(did)
        // `URL.appendingPathComponent` percent-encodes `:` on Linux but not
        // Darwin. PLC's route is literally `/:did`, so construct the already
        // validated path explicitly and make its wire representation stable
        // across Foundation implementations.
        guard suffix.allSatisfy({ !$0.isEmpty && !$0.contains("/") }),
              var components = URLComponents(
                  url: configuration.origin,
                  resolvingAgainstBaseURL: false
              ) else {
            throw PetrelPLCError.malformed("PLC request URL is invalid")
        }
        components.percentEncodedPath = "/" + ([did] + suffix)
            .joined(separator: "/")
        guard let url = components.url else {
            throw PetrelPLCError.malformed("PLC request URL is invalid")
        }
        guard url.host == configuration.origin.host,
              url.scheme == configuration.origin.scheme,
              url.port == configuration.origin.port,
              url.query == nil,
              url.fragment == nil else {
            throw PetrelPLCError.malformed("PLC request URL is invalid")
        }
        return url
    }

    private func validateResponse(
        _ response: PLCHTTPResponse,
        for request: PLCHTTPRequest,
        permitsEmptyBody: Bool
    ) throws {
        guard response.redirectCount == 0,
              response.finalURL == request.url else {
            throw PetrelPLCError.unauthorized("PLC directory redirects are forbidden")
        }
        guard (200 ... 299).contains(response.status) else {
            throw PetrelPLCError.unavailable("PLC directory returned a non-success status")
        }
        guard response.body.count <= request.maximumResponseBytes else {
            throw PetrelPLCError.unavailable("PLC directory response exceeded its bound")
        }
        if permitsEmptyBody, response.body.isEmpty {
            return
        }
        guard let contentType = response.headers["content-type"],
              contentType.split(separator: ";", maxSplits: 1).first?
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased() == "application/json" else {
            throw PetrelPLCError.malformed("PLC directory response is not JSON")
        }
        try StrictJSON.validate(response.body)
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
        for request: PLCHTTPRequest
    ) throws -> PLCSubmitAcceptance {
        guard response.redirectCount == 0,
              response.finalURL == request.url else {
            throw PetrelPLCError.unauthorized("PLC directory redirects are forbidden")
        }
        guard response.body.count <= request.maximumResponseBytes else {
            throw PetrelPLCError.unavailable("PLC directory response exceeded its bound")
        }

        switch configuration.submitSuccessResponsePolicy {
        case .didPLCServer001:
            guard response.status == 200 else {
                throw PetrelPLCError.unavailable(
                    "PLC directory returned an incompatible submit status"
                )
            }
            guard response.headers["content-type"] == "text/plain; charset=utf-8",
                  response.body == Data([0x4f, 0x4b]) else {
                throw PetrelPLCError.malformed(
                    "PLC directory returned an incompatible submit response"
                )
            }
            return .verified
        case .strict:
            break
        }

        guard (200 ... 299).contains(response.status) else {
            throw PetrelPLCError.unavailable("PLC directory returned a non-success status")
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
        guard let contentType = response.headers["content-type"],
              contentType.split(separator: ";", maxSplits: 1).first?
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased() == "application/json" else {
            throw PetrelPLCError.malformed("PLC directory response is not JSON")
        }
        try StrictJSON.validate(response.body)
        return .verified
    }

    private func decodeState(_ data: Data, expectedDID: String) throws -> PLCDocumentData {
        try StrictJSON.validate(data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == [
                  "did", "rotationKeys", "verificationMethods", "alsoKnownAs", "services",
              ],
              let did = object["did"] as? String,
              did == expectedDID,
              let rotationKeys = object["rotationKeys"] as? [String],
              let verificationMethods = object["verificationMethods"] as? [String: String],
              let alsoKnownAs = object["alsoKnownAs"] as? [String],
              let rawServices = object["services"] as? [String: Any] else {
            throw PetrelPLCError.malformed("PLC document data is malformed")
        }
        var services = [String: PLCService]()
        for (name, raw) in rawServices {
            guard let value = raw as? [String: Any],
                  Set(value.keys) == ["type", "endpoint"],
                  let type = value["type"] as? String,
                  let endpoint = value["endpoint"] as? String else {
                throw PetrelPLCError.malformed("PLC document service is malformed")
            }
            services[name] = .init(type: type, endpoint: endpoint)
        }
        // Reuse regular-operation validation for every state field and key.
        _ = try PLCUnsignedRegularOperation(
            rotationKeys: rotationKeys,
            verificationMethods: verificationMethods,
            alsoKnownAs: alsoKnownAs,
            services: services,
            prev: nil
        )
        return .init(
            did: did,
            rotationKeys: rotationKeys,
            verificationMethods: verificationMethods,
            alsoKnownAs: alsoKnownAs,
            services: services
        )
    }

    private func decodeAndVerifyAudit(_ data: Data, expectedDID: String) throws -> [PLCAuditEntry] {
        try StrictJSON.validate(data)
        guard let rawEntries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !rawEntries.isEmpty,
              rawEntries.count <= 10_000 else {
            throw PetrelPLCError.malformed("PLC audit log is malformed")
        }
        struct ValidatedEntry {
            let entry: PLCAuditEntry
            let createdAt: Date
        }

        var entries = [ValidatedEntry]()
        var seenCIDs = Set<String>()
        var previousCreatedAt: Date?
        for raw in rawEntries {
            guard Set(raw.keys) == ["did", "operation", "cid", "nullified", "createdAt"],
                  let did = raw["did"] as? String,
                  did == expectedDID,
                  let operationObject = raw["operation"],
                  JSONSerialization.isValidJSONObject(operationObject),
                  let cidText = raw["cid"] as? String,
                  raw["nullified"] is Bool,
                  let createdAt = raw["createdAt"] as? String,
                  let createdAtDate = canonicalTimestampDate(createdAt),
                  previousCreatedAt.map({ createdAtDate >= $0 }) ?? true else {
                throw PetrelPLCError.malformed("PLC audit entry is malformed")
            }
            let operationData = try JSONSerialization.data(
                withJSONObject: operationObject,
                options: [.sortedKeys]
            )
            let operation = try PLCOperationCodec.decodeSignedJSON(operationData)
            let cid = try CID.parse(cidText)
            guard cid.string == cidText,
                  cid.codec == .dagCBOR,
                  cid.multihash.algorithm == Multihash.sha256Code,
                  cid.multihash.length == Multihash.sha256Length,
                  try operation.cid.string == cidText,
                  seenCIDs.insert(cidText).inserted else {
                throw PetrelPLCError.unauthorized("PLC audit operation CID is invalid")
            }
            let entry = PLCAuditEntry(
                did: did,
                operation: operation,
                cid: cidText,
                nullified: false,
                createdAt: createdAt
            )
            if entries.isEmpty {
                guard operation.prev == nil else {
                    throw PetrelPLCError.unauthorized("PLC audit does not start with genesis")
                }
                try PLCOperationCodec.verifyGenesis(operation, expectedDID: expectedDID)
            } else if operation.prev == nil {
                throw PetrelPLCError.unauthorized("PLC audit contains multiple genesis operations")
            }
            entries.append(.init(entry: entry, createdAt: createdAtDate))
            previousCreatedAt = createdAtDate
        }

        var activeIndices = [0]
        for proposedIndex in entries.indices.dropFirst() {
            let proposed = entries[proposedIndex]
            guard let proposedPrev = proposed.entry.operation.prev,
                  let parentPosition = activeIndices.firstIndex(where: {
                      entries[$0].entry.cid == proposedPrev
                  }),
                  let parentOperation = entries[activeIndices[parentPosition]]
                  .entry.operation.regular else {
                throw PetrelPLCError.unauthorized("PLC audit operation prev is not active")
            }
            let rotationKeys = parentOperation.rotationKeys
            if parentPosition == activeIndices.count - 1 {
                _ = try PLCOperationCodec.verify(
                    proposed.entry.operation,
                    authorizedRotationKeys: rotationKeys
                )
                activeIndices.append(proposedIndex)
                continue
            }

            let firstDisputed = entries[activeIndices[parentPosition + 1]]
            let disputedSignerIndex = try PLCOperationCodec.verify(
                firstDisputed.entry.operation,
                authorizedRotationKeys: rotationKeys
            )
            guard disputedSignerIndex > 0 else {
                throw PetrelPLCError.unauthorized(
                    "PLC recovery cannot supersede an equal-authority operation"
                )
            }
            _ = try PLCOperationCodec.verify(
                proposed.entry.operation,
                authorizedRotationKeys: Array(rotationKeys[..<disputedSignerIndex])
            )
            let recoveryAge = proposed.createdAt.timeIntervalSince(firstDisputed.createdAt)
            guard recoveryAge >= 0, recoveryAge <= 72 * 60 * 60 else {
                throw PetrelPLCError.unauthorized("PLC recovery exceeds the 72-hour window")
            }
            activeIndices.removeSubrange((parentPosition + 1)...)
            activeIndices.append(proposedIndex)
        }

        let activeCIDs = Set(activeIndices.map { entries[$0].entry.cid })
        return entries.map { validated in
            PLCAuditEntry(
                did: validated.entry.did,
                operation: validated.entry.operation,
                cid: validated.entry.cid,
                nullified: !activeCIDs.contains(validated.entry.cid),
                createdAt: validated.entry.createdAt
            )
        }
    }

    private func canonicalTimestampDate(_ value: String) -> Date? {
        let bytes = Array(value.utf8)
        guard bytes.count == 24,
              bytes[4] == UInt8(ascii: "-"),
              bytes[7] == UInt8(ascii: "-"),
              bytes[10] == UInt8(ascii: "T"),
              bytes[13] == UInt8(ascii: ":"),
              bytes[16] == UInt8(ascii: ":"),
              bytes[19] == UInt8(ascii: "."),
              bytes[23] == UInt8(ascii: "Z"),
              bytes.enumerated().allSatisfy({ index, byte in
                  [4, 7, 10, 13, 16, 19, 23].contains(index) ||
                      (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
              }) else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            return nil
        }
        return date
    }
}

private func plcIsLoopbackLiteral(_ host: String) -> Bool {
    let canonical = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    if canonical == "::1" { return true }
    let parts = canonical.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4,
          let first = UInt8(parts[0]),
          parts.allSatisfy({ part in
              guard let value = UInt8(part) else { return false }
              return String(value) == part
          }) else {
        return false
    }
    return first == 127
}
