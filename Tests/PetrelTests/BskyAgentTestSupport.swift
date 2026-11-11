import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// Offline transport for the Bluesky helper tests.
//
// Every test gets its own loopback port. `BskyStubURLProtocol` intercepts the
// requests the real `NetworkService` sends to that port and hands them to the
// test's handler, so the helpers are exercised through the production request
// pipeline (URL building, header merging, proxy selection, error mapping)
// without any network.

/// One request as it left `NetworkService`.
struct BskyStubRequest: Sendable {
    let method: String
    /// The lexicon method, taken from the `/xrpc/<nsid>` path.
    let nsid: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data

    /// The body parsed as JSON; `nil` when there is none or it is not JSON.
    var json: BskyJSON? {
        body.isEmpty ? nil : try? BskyJSON.parse(body)
    }

    func header(_ name: String) -> String? {
        headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }

    func query(_ name: String) -> [String] {
        queryItems.filter { $0.name == name }.compactMap(\.value)
    }
}

struct BskyStubResponse: Sendable {
    var status = 200
    var body = Data()
    var headers: [String: String] = ["Content-Type": "application/json"]

    static func json(_ value: BskyJSON, status: Int = 200, headers: [String: String] = [:]) -> BskyStubResponse {
        var response = BskyStubResponse(status: status)
        // The tree is built from literals, so serialization cannot fail.
        response.body = (try? value.serialized()) ?? Data()
        response.headers.merge(headers) { _, new in new }
        return response
    }

    static func error(_ status: Int, _ name: String, _ message: String? = nil) -> BskyStubResponse {
        var object: [String: BskyJSON] = ["error": .string(name)]
        if let message { object["message"] = .string(message) }
        return json(.object(object), status: status)
    }

    static let empty = BskyStubResponse()
}

/// A scripted server bound to one loopback port.
final class BskyStubServer: @unchecked Sendable {
    typealias Handler = @Sendable (BskyStubRequest) -> BskyStubResponse

    let port: Int
    private let lock = NSLock()
    private var recorded: [BskyStubRequest] = []
    private var handler: Handler

    private static let registryLock = NSLock()
    private nonisolated(unsafe) static var registry: [Int: BskyStubServer] = [:]
    private nonisolated(unsafe) static var nextPort = 48100

    init(handler: @escaping Handler = { _ in .error(501, "MethodNotImplemented") }) {
        self.handler = handler
        port = Self.registryLock.withLock {
            Self.nextPort += 1
            return Self.nextPort
        }
        Self.registryLock.withLock { Self.registry[port] = self }
    }

    deinit {
        Self.registryLock.withLock { Self.registry[port] = nil }
    }

    static func server(forPort port: Int) -> BskyStubServer? {
        registryLock.withLock { registry[port] }
    }

    var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    /// Every request received so far, in order.
    var requests: [BskyStubRequest] {
        lock.withLock { recorded }
    }

    func requests(to nsid: String) -> [BskyStubRequest] {
        requests.filter { $0.nsid == nsid }
    }

    func setHandler(_ handler: @escaping Handler) {
        lock.withLock { self.handler = handler }
    }

    func respond(to request: BskyStubRequest) -> BskyStubResponse {
        let handler = lock.withLock { () -> Handler in
            recorded.append(request)
            return self.handler
        }
        return handler(request)
    }

    /// A network service whose requests reach this server. Built while the
    /// stub protocol is installed, because a session captures its protocol
    /// classes at creation.
    func makeNetworkService() async -> NetworkService {
        let service = await withSerializedStorageOverrideTest {
            NetworkService.setNetworkTestProtocolClasses([BskyStubURLProtocol.self])
            let service = NetworkService(baseURL: baseURL)
            NetworkService.setNetworkTestProtocolClasses(nil)
            return service
        }
        await service.setServiceDID("did:web:api.bsky.app#bsky_appview", for: "app.bsky")
        await service.setServiceDID("did:web:api.bsky.chat#bsky_chat", for: "chat.bsky")
        return service
    }

    /// An agent acting as `did` (or signed out when `nil`) against this server.
    func makeAgent(did: String? = BskyStubServer.alice) async throws -> BskyAgent {
        try await BskyAgent(networkService: makeNetworkService(), did: did.map { try DID(didString: $0) })
    }

    /// An unauthenticated client against this server, for client-level header tests.
    func makeClient() async -> ATProtoClient {
        await withSerializedStorageOverrideTest {
            NetworkService.setNetworkTestProtocolClasses([BskyStubURLProtocol.self])
            let client = await ATProtoClient(baseURL: baseURL)
            NetworkService.setNetworkTestProtocolClasses(nil)
            return client
        }
    }

    static let alice = "did:plc:alice"
}

final class BskyStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host == "127.0.0.1", let port = url.port else { return false }
        return BskyStubServer.server(forPort: port) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let port = url.port, let server = BskyStubServer.server(forPort: port) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let recorded = BskyStubRequest(
            method: request.httpMethod ?? "GET",
            nsid: url.path.replacingOccurrences(of: "/xrpc/", with: ""),
            queryItems: components?.queryItems ?? [],
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.body(of: request)
        )
        let response = server.respond(to: recorded)
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Inside a `URLProtocol` the body arrives as a stream, not as `httpBody`.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// An in-memory PDS: a record store with compare-and-swap, handle resolution,
/// blob upload, preferences, and the AppView procedures the helpers call.
final class BskyFakePDS: @unchecked Sendable {
    struct StoredRecord {
        var value: BskyJSON
        var cid: String
    }

    let server: BskyStubServer
    private let lock = NSLock()
    private var records: [String: StoredRecord] = [:] // keyed by at:// URI
    private var counter = 0
    private var handles: [String: String] = [:]
    private var preferences: [BskyJSON] = []
    /// Runs just before a `putRecord` is applied; lets a test simulate another writer.
    private var beforePut: (@Sendable (BskyFakePDS) -> Void)?
    /// Canned responses for methods the store does not model, keyed by NSID.
    private var canned: [String: BskyStubResponse] = [:]

    init() {
        server = BskyStubServer()
        server.setHandler { [unowned self] request in
            self.handle(request)
        }
    }

    // MARK: Test-side controls

    func setHandle(_ handle: String, did: String) {
        lock.withLock { handles[handle] = did }
    }

    func setResponse(_ response: BskyStubResponse, for nsid: String) {
        lock.withLock { canned[nsid] = response }
    }

    func setPreferences(_ preferences: [BskyJSON]) {
        lock.withLock { self.preferences = preferences }
    }

    var storedPreferences: [BskyJSON] {
        lock.withLock { preferences }
    }

    func onBeforePut(_ hook: (@Sendable (BskyFakePDS) -> Void)?) {
        lock.withLock { beforePut = hook }
    }

    func record(at uri: String) -> StoredRecord? {
        lock.withLock { records[uri] }
    }

    var recordURIs: [String] {
        lock.withLock { records.keys.sorted() }
    }

    /// Writes a record directly, as another client would.
    @discardableResult
    func seed(_ uri: String, _ value: BskyJSON) -> String {
        lock.withLock { store(uri, value) }
    }

    private func store(_ uri: String, _ value: BskyJSON) -> String {
        counter += 1
        let cid = CID.fromDAGCBOR(Data("\(uri)#\(counter)".utf8)).string
        records[uri] = StoredRecord(value: value, cid: cid)
        return cid
    }

    // MARK: Request handling

    private func handle(_ request: BskyStubRequest) -> BskyStubResponse {
        if let response = lock.withLock({ canned[request.nsid] }) {
            return response
        }
        let body = request.json
        switch request.nsid {
        case "com.atproto.repo.createRecord":
            guard let repo = body?["repo"]?.stringValue,
                  let collection = body?["collection"]?.stringValue,
                  let record = body?["record"]
            else { return .error(400, "InvalidRequest") }
            return lock.withLock {
                let rkey = body?["rkey"]?.stringValue ?? "3kfake\(String(format: "%07d", counter + 1))"
                let uri = "at://\(repo)/\(collection)/\(rkey)"
                let cid = store(uri, record)
                return .json(.object(["uri": .string(uri), "cid": .string(cid)]))
            }

        case "com.atproto.repo.putRecord":
            guard let repo = body?["repo"]?.stringValue,
                  let collection = body?["collection"]?.stringValue,
                  let rkey = body?["rkey"]?.stringValue,
                  let record = body?["record"]
            else { return .error(400, "InvalidRequest") }
            let hook = lock.withLock { beforePut }
            hook?(self)
            return lock.withLock {
                let uri = "at://\(repo)/\(collection)/\(rkey)"
                if let swap = body?["swapRecord"] {
                    let current = records[uri]?.cid
                    let expected = swap.stringValue // nil for JSON null: "must not exist"
                    if current != expected {
                        return .error(400, "InvalidSwap", "Record was at \(current ?? "null")")
                    }
                }
                let cid = store(uri, record)
                return .json(.object(["uri": .string(uri), "cid": .string(cid)]))
            }

        case "com.atproto.repo.deleteRecord":
            guard let repo = body?["repo"]?.stringValue,
                  let collection = body?["collection"]?.stringValue,
                  let rkey = body?["rkey"]?.stringValue
            else { return .error(400, "InvalidRequest") }
            lock.withLock { records["at://\(repo)/\(collection)/\(rkey)"] = nil }
            return .json(.object([:]))

        case "com.atproto.repo.getRecord":
            guard let repo = request.query("repo").first,
                  let collection = request.query("collection").first,
                  let rkey = request.query("rkey").first
            else { return .error(400, "InvalidRequest") }
            let uri = "at://\(repo)/\(collection)/\(rkey)"
            guard let stored = lock.withLock({ records[uri] }) else {
                return .error(400, "RecordNotFound", "Could not locate record: \(uri)")
            }
            return .json(.object(["uri": .string(uri), "cid": .string(stored.cid), "value": stored.value]))

        case "com.atproto.identity.resolveHandle":
            guard let handle = request.query("handle").first,
                  let did = lock.withLock({ handles[handle] })
            else { return .error(400, "InvalidRequest", "Unable to resolve handle") }
            return .json(.object(["did": .string(did)]))

        case "com.atproto.repo.uploadBlob":
            let cid = CID.fromDAGCBOR(request.body).string
            return .json(.object(["blob": .object([
                "$type": .string("blob"),
                "ref": .object(["$link": .string(cid)]),
                "mimeType": .string(request.header("Content-Type") ?? ""),
                "size": .integer(request.body.count),
            ])]))

        case "app.bsky.actor.getPreferences":
            return .json(.object(["preferences": .array(lock.withLock { preferences })]))

        case "app.bsky.actor.putPreferences":
            guard let preferences = body?["preferences"]?.arrayValue else { return .error(400, "InvalidRequest") }
            lock.withLock { self.preferences = preferences }
            return .empty

        case "app.bsky.graph.muteActor", "app.bsky.graph.unmuteActor",
             "app.bsky.graph.muteActorList", "app.bsky.graph.unmuteActorList",
             "app.bsky.graph.muteThread", "app.bsky.graph.unmuteThread",
             "app.bsky.notification.updateSeen":
            return .empty

        default:
            return .error(501, "MethodNotImplemented", request.nsid)
        }
    }
}

extension BskyJSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral
{
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .integer(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: BskyJSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, BskyJSON)...) {
        self = .object(Dictionary(elements) { _, new in new })
    }

    public init(nilLiteral _: ()) { self = .null }
}

extension BskyJSON {
    /// Structural equality that tolerates one thing: `$type` keys present in
    /// `self` but absent from `expected`. The generated encoders stamp a
    /// `$type` on nested objects (`app.bsky.feed.post#replyRef`, …), which is
    /// valid but not something these tests are about. Any other extra key,
    /// missing key or differing value is a mismatch.
    func matchesAllowingExtraTypes(_ expected: BskyJSON) -> Bool {
        switch (self, expected) {
        case let (.object(actual), .object(wanted)):
            guard Set(actual.keys).subtracting(["$type"]) == Set(wanted.keys).subtracting(["$type"]) else {
                return false
            }
            return wanted.allSatisfy { key, value in
                actual[key]?.matchesAllowingExtraTypes(value) ?? false
            }
        case let (.array(actual), .array(wanted)):
            return actual.count == wanted.count
                && zip(actual, wanted).allSatisfy { $0.matchesAllowingExtraTypes($1) }
        default:
            return self == expected
        }
    }
}

/// Asserts that a record (or part of one) sent on the wire is `expected`,
/// allowing extra nested `$type` discriminators.
func expectRecord(
    _ actual: BskyJSON?,
    _ expected: BskyJSON,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let matches = actual?.matchesAllowingExtraTypes(expected) ?? false
    #expect(
        matches,
        "expected \(expected), got \(actual.map { "\($0)" } ?? "nil")",
        sourceLocation: sourceLocation
    )
}
