#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCrypto
@testable import PetrelPLC

/// The vendored sample of the public PLC directory. See
/// `Vectors/plc-directory/README.md` for provenance.
enum PLCVectors {
    static let directory: URL = {
        guard let url = Bundle.module.url(forResource: "Vectors", withExtension: nil) else {
            fatalError("PetrelPLCTests resources are missing the Vectors directory")
        }
        return url.appendingPathComponent("plc-directory")
    }()

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(relativePath))
    }

    static func exportEntries(_ fileName: String) throws -> [PLCExportEntry] {
        try PLCExportEntry.decode(jsonLines: data(fileName))
    }

    static func auditLogJSON(did: String) throws -> Data {
        try data("audit/" + did.replacingOccurrences(of: ":", with: "_") + ".json")
    }

    /// Export lines, as `GET /export` returned them, for the operations of
    /// the vendored identities: once in the legacy format and, for some,
    /// once in the sequenced format.
    static let exportFiles = ["export-legacy.jsonl", "export-sequenced.jsonl"]

    /// Identities of organisations and services.
    enum Organisation {
        /// `bsky.app`
        static let bskyApp = "did:plc:z72i7hdynmk6r22z27h6tvur"
        /// `atproto.com`, the specification's own example
        static let atprotoCom = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
        /// `moderation.bsky.app`, a labeler
        static let moderation = "did:plc:ar7c4by46qjdydhdevvrndac"
        /// `safety.bsky.app`
        static let safety = "did:plc:eon2iu7v3x2ukgxkqaf7e5np"
        /// `support.bsky.team`, registered with a legacy `create` operation
        static let support = "did:plc:oc6vwdlmk2kqyida5i74d3p5"
        /// `status.bsky.app`
        static let status = "did:plc:4dtbz2ivhp5app3sbntcccxc"
        /// A repository identity on `knot1.tangled.sh`, first registered
        /// with no verification methods
        static let tangledKnotRepository = "did:plc:hymtrrab3tb62ktcluou37ce"
    }

    /// Identities created by test scripts against the public directory.
    enum TestIdentity {
        /// Handle `tombstone`, PDS `https://localhost`: ends in a tombstone
        static let tombstoned = "did:plc:5qepwfemd2p3ts3phpzjvmsi"
        /// `example.test`: a tombstone nullified by a recovery
        static let recovered = "did:plc:n7eilcz7ouze6kj5hwvyt4ju"
        /// `example.test`: the same recovery shape
        static let recoveredAgain = "did:plc:xgj5yvayzto5fx3qq2o7ichg"
        /// `testman.test` on `localhost:4989`: legacy `create`, P-256 keys
        static let legacyP256 = "did:plc:k525d5my7ob3divsqd5ogf7b"
        /// A 7 kB data-URI alias on PDS `https://uwu`, P-256 keys
        static let large = "did:plc:nlkuhfcmtu7jluphj37j5o4f"
    }

    static var auditLogDIDs: [String] {
        get throws {
            try FileManager.default
                .contentsOfDirectory(atPath: directory.appendingPathComponent("audit").path)
                .filter { $0.hasSuffix(".json") }
                .map { $0.dropLast(".json".count).replacingOccurrences(of: "_", with: ":") }
                .sorted()
        }
    }
}

func plcTestTimestamp(milliseconds: Int64) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1_000))
}

/// An in-memory stand-in for a PLC directory, speaking the reference
/// server's HTTP interface through `PLCHTTPTransport`.
///
/// It serves every read route, accepts `POST /:did` under the directory's
/// acceptance rules, and answers errors in the reference server's shapes,
/// so that a `PLCDirectoryClient` can be driven end to end without a
/// network.
actor FakePLCDirectory: PLCHTTPTransport {
    struct Sequenced {
        let sequence: UInt64
        let did: String
        let cid: String
    }

    private var logs = [String: [PLCAuditEntry]]()
    private var sequence = [Sequenced]()
    private var clock: Int64 = 1_767_225_600_000 // 2026-01-01T00:00:00.000Z
    private var injected = [String: [PLCHTTPResponse]]()
    private(set) var requests = [PLCHTTPRequest]()

    var postCount: Int {
        requests.filter { $0.method == .post }.count
    }

    func advance(hours: Double) {
        clock += Int64(hours * 3_600_000)
    }

    /// Loads a real audit log as recorded from the public directory.
    func seed(did: String, auditLogJSON: Data) throws {
        let entries = try PLCAuditLogVerifier.decode(auditLogJSON, did: did)
        logs[did] = entries
        for entry in entries {
            sequence.append(.init(sequence: UInt64(sequence.count + 1), did: did, cid: entry.cid))
        }
    }

    /// Makes the next request for `path` (for example `/export` or
    /// `/did:plc:…/log/audit`) return `response` instead of being served.
    func inject(_ response: PLCHTTPResponse, forPath path: String) {
        injected[path, default: []].append(response)
    }

    func entries(did: String) -> [PLCAuditEntry] {
        logs[did] ?? []
    }

    func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse {
        requests.append(request)
        let path = request.url.path
        if var queue = injected[path], !queue.isEmpty {
            let response = queue.removeFirst()
            injected[path] = queue
            return PLCHTTPResponse(
                status: response.status,
                headers: response.headers,
                body: response.body,
                finalURL: response.finalURL ?? request.url,
                redirectCount: response.redirectCount
            )
        }
        let response = try route(request)
        return PLCHTTPResponse(
            status: response.status,
            headers: response.headers,
            body: response.body,
            finalURL: request.url,
            redirectCount: 0
        )
    }

    private func route(_ request: PLCHTTPRequest) throws -> PLCHTTPResponse {
        let parts = request.url.path.split(separator: "/").map(String.init)
        guard let first = parts.first else { return message(404, "not found") }
        if first == "export", parts.count == 1, request.method == .get {
            return try export(request)
        }
        let did = first
        guard did.hasPrefix("did:plc:"), did.utf8.count == 32 else {
            return message(400, "Resolution of non-PLC DIDs not supported: \(did)")
        }
        if request.method == .post {
            guard parts.count == 1, let body = request.body else { return message(404, "not found") }
            return try accept(did: did, body: body)
        }
        guard let log = logs[did], !log.isEmpty else {
            return message(404, "DID not registered: \(did)")
        }
        let active = log.filter { !$0.nullified }
        guard let head = active.last else {
            return message(404, "DID not registered: \(did)")
        }
        switch Array(parts.dropFirst()) {
        case []:
            guard let data = head.operation.documentData(did: did) else {
                return message(404, "DID not available: \(did)")
            }
            return try json(didDocumentObject(data), contentType: "application/did+ld+json; charset=utf-8")
        case ["data"]:
            guard let data = head.operation.documentData(did: did) else {
                return message(404, "DID not available: \(did)")
            }
            return try json([
                "did": did,
                "rotationKeys": data.rotationKeys,
                "verificationMethods": data.verificationMethods,
                "alsoKnownAs": data.alsoKnownAs,
                "services": data.services.mapValues { ["type": $0.type, "endpoint": $0.endpoint] },
            ])
        case ["log"]:
            return try json(active.map { try operationObject($0.operation) })
        case ["log", "audit"]:
            return try json(log.map { try auditObject($0) })
        case ["log", "last"]:
            return try json(operationObject(head.operation))
        default:
            return message(404, "not found")
        }
    }

    private func accept(did: String, body: Data) throws -> PLCHTTPResponse {
        let operation: PLCSignedOperation
        do {
            operation = try PLCOperationCodec.decodeSignedJSON(body)
            try PLCOperationCodec.validateForSubmission(operation, limits: .referenceDirectory)
        } catch {
            return message(400, "Not a valid operation: \(error)")
        }
        clock += 1_000
        let existing = logs[did] ?? []
        let candidate = try existing + [PLCAuditEntry(
            did: did,
            operation: operation,
            cid: operation.cid.string,
            nullified: false,
            createdAt: plcTestTimestamp(milliseconds: clock)
        )]
        do {
            let verified = try PLCAuditLogVerifier.verify(candidate, did: did)
            logs[did] = verified.entries
            try sequence.append(.init(
                sequence: UInt64(sequence.count + 1), did: did, cid: operation.cid.string
            ))
        } catch {
            return message(400, "Invalid operation: \(error)")
        }
        return PLCHTTPResponse(
            status: 200,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: Data("OK".utf8)
        )
    }

    private func export(_ request: PLCHTTPRequest) throws -> PLCHTTPResponse {
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let count = min(items.first { $0.name == "count" }?.value.flatMap(Int.init) ?? 1_000, 1_000)
        let after = items.first { $0.name == "after" }?.value
        var lines = [Data]()
        for item in sequence {
            guard lines.count < count,
                  let entry = logs[item.did]?.first(where: { $0.cid == item.cid }) else { continue }
            var object = try auditObject(entry)
            if let after, let afterSequence = UInt64(after) {
                guard item.sequence > afterSequence else { continue }
                object["seq"] = item.sequence
                object["type"] = "sequenced_op"
                object["nullified"] = nil
            } else if let after {
                guard entry.createdAt > after else { continue }
            }
            try lines.append(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
        }
        return PLCHTTPResponse(
            status: 200,
            headers: ["content-type": "application/jsonlines"],
            body: Data(lines.joined(separator: Data("\n".utf8)))
        )
    }

    private func operationObject(_ operation: PLCSignedOperation) throws -> Any {
        try JSONSerialization.jsonObject(with: operation.canonicalJSON)
    }

    private func auditObject(_ entry: PLCAuditEntry) throws -> [String: Any] {
        try [
            "did": entry.did,
            "operation": operationObject(entry.operation),
            "cid": entry.cid,
            "nullified": entry.nullified,
            "createdAt": entry.createdAt,
        ]
    }

    /// The reference library's `formatDidDoc`, written out independently of
    /// `PLCDIDDocument.init(data:)`.
    private func didDocumentObject(_ data: PLCDocumentData) -> [String: Any] {
        var context = ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"]
        var methods = [[String: String]]()
        for (id, key) in data.verificationMethods.sorted(by: { $0.key < $1.key }) {
            let suite: String? = key.hasPrefix("did:key:zDn")
                ? "https://w3id.org/security/suites/ecdsa-2019/v1"
                : key.hasPrefix("did:key:zQ3s")
                ? "https://w3id.org/security/suites/secp256k1-2019/v1"
                : nil
            if let suite, !context.contains(suite) { context.append(suite) }
            methods.append([
                "id": "\(data.did)#\(id)",
                "type": "Multikey",
                "controller": data.did,
                "publicKeyMultibase": String(key.dropFirst("did:key:".count)),
            ])
        }
        return [
            "@context": context,
            "id": data.did,
            "alsoKnownAs": data.alsoKnownAs,
            "verificationMethod": methods,
            "service": data.services.sorted(by: { $0.key < $1.key }).map { id, service in
                ["id": "#\(id)", "type": service.type, "serviceEndpoint": service.endpoint]
            },
        ]
    }

    private func json(
        _ object: Any,
        contentType: String = "application/json; charset=utf-8"
    ) throws -> PLCHTTPResponse {
        try PLCHTTPResponse(
            status: 200,
            headers: ["content-type": contentType],
            body: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    private func message(_ status: Int, _ text: String) -> PLCHTTPResponse {
        // The reference server's error body.
        let body = (try? JSONSerialization.data(withJSONObject: ["message": text])) ?? Data()
        return PLCHTTPResponse(
            status: status,
            headers: ["content-type": "application/json; charset=utf-8"],
            body: body
        )
    }
}

/// The directory under test in stubbed tests: `https://plc.test`.
/// The timeout for HTTP exchanges answered in-process by a `URLProtocol`
/// stub. Nothing on the other end is slow, but a loaded CI runner can freeze
/// the whole test process (stalls of 87 to 129 s have been seen), and a
/// `URLRequest` timeout that fires during the freeze fails the exchange
/// before the stub answers. Ten minutes outlasts any stall seen; it is above
/// the 30 second ceiling the public API enforces, so stubbed tests build
/// their transport and configuration through the internal seams below.
/// These tests are about bounds and cancellation, not timeouts;
/// `testURLSessionPLCTransportReportsATimeout` covers the timeout.
let stubbedExchangeTimeout: TimeInterval = 10 * 60

/// A `URLSessionPLCTransport` over `configuration` that accepts
/// ``stubbedExchangeTimeout``.
func stubbedURLSessionTransport(configuration: URLSessionConfiguration) throws -> URLSessionPLCTransport {
    try URLSessionPLCTransport(
        maximumTimeout: stubbedExchangeTimeout,
        configuration: configuration,
        timeoutCeiling: stubbedExchangeTimeout
    )
}

func plcTestClient(
    _ directory: FakePLCDirectory,
    limits: PLCOperationLimits = .specification
) throws -> PLCDirectoryClient {
    try PLCDirectoryClient(
        configuration: .production(
            origin: URL(string: "https://plc.test")!,
            operationLimits: limits
        ),
        transport: directory
    )
}

/// A fresh atproto identity's key material.
struct PLCTestIdentity {
    let signingKey = K256Keypair.generate()
    let primaryRotationKey = K256Keypair.generate()
    let secondaryRotationKey = P256Keypair.generate()

    var rotationKeys: [String] { [primaryRotationKey.didKey, secondaryRotationKey.didKey] }

    func genesis(handle: String = "alice.example.com") async throws -> (did: String, operation: PLCSignedOperation) {
        let unsigned = try PLCATProfile.genesisOperation(
            handle: handle,
            signingKey: signingKey.didKey,
            rotationKeys: rotationKeys,
            pdsEndpoint: "https://pds.example.com"
        )
        let operation = try await PLCOperationCodec.sign(.regular(unsigned), with: primaryRotationKey)
        return try (PLCOperationCodec.genesisDID(for: operation), operation)
    }
}

/// Builds an audit log entry list from operations and explicit timestamps.
func plcAuditEntries(
    did: String,
    _ operations: [(operation: PLCSignedOperation, createdAt: String)]
) throws -> [PLCAuditEntry] {
    try operations.map { item in
        try PLCAuditEntry(
            did: did,
            operation: item.operation,
            cid: item.operation.cid.string,
            nullified: false,
            createdAt: item.createdAt
        )
    }
}

/// Runs `operation` and returns the `PetrelPLCError` it throws, if any.
func plcError(_ operation: () async throws -> Void) async -> PetrelPLCError? {
    do {
        try await operation()
        return nil
    } catch let error as PetrelPLCError {
        return error
    } catch {
        return nil
    }
}

/// A TCP listener on 127.0.0.1 that never accepts: the kernel completes
/// connections into the backlog, the client sends its request, and nothing
/// ever answers.
final class SilentLoopbackListener: @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var descriptor: Int32

    init() throws {
        #if canImport(Darwin)
            let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #else
            let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #endif
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        var address = sockaddr_in()
        #if canImport(Darwin)
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, length) == 0
                    && listen(descriptor, 16) == 0
                    && getsockname(descriptor, $0, &length) == 0
            }
        }
        guard bound else {
            _ = Self.closeDescriptor(descriptor)
            throw POSIXError(.EADDRNOTAVAIL)
        }
        self.descriptor = descriptor
        url = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))")!
    }

    deinit { close() }

    func close() {
        lock.withLock {
            if descriptor >= 0 {
                _ = Self.closeDescriptor(descriptor)
                descriptor = -1
            }
        }
    }

    private static func closeDescriptor(_ descriptor: Int32) -> Int32 {
        #if canImport(Darwin)
            Darwin.close(descriptor)
        #else
            Glibc.close(descriptor)
        #endif
    }
}
