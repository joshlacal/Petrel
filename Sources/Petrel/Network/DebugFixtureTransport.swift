#if DEBUG && canImport(Network) && canImport(Security)
    import CryptoKit
    import Foundation
    import Network
    import Security

    /// Explicit, process-local qualification transport. No environment or manifest is
    /// consumed automatically, and this entire facility is absent from release builds.
    public final class DebugFixtureTransport: @unchecked Sendable {
        public enum Failure: Error { case invalidConfiguration, alreadyInstalled, unavailable, rejected, connection }
        public struct Account: Sendable {
            public let label: String
            public let did: String
            public let deviceId: String
        }

        public let identity: String
        public let origin: URL
        public let accounts: [Account]
        let ports: [String: UInt16]
        private let certificate: SecCertificate
        private let queue = DispatchQueue(label: "blue.catbird.debug-fixture-tunnel")
        private let listener: NWListener
        private var tunnels: [UUID: FixtureTunnel] = [:] // queue-confined
        private let readyLock = NSLock()
        private var readyContinuation: CheckedContinuation<Void, Error>?
        private var proxyPort: UInt16 = 0
        private static let installationLock = NSLock()
        private nonisolated(unsafe) static var installed: DebugFixtureTransport?
        private nonisolated(unsafe) static var installationStarted = false

        /// One immutable manifest for the process lifetime. Call before constructing
        /// fixture clients; attempting replacement, including after failure, is rejected.
        public static func install(manifest: Data, certificateDER: Data) async throws -> DebugFixtureTransport {
            try installationLock.withLock {
                guard !installationStarted else { throw Failure.alreadyInstalled }
                installationStarted = true
            }
            let transport = try DebugFixtureTransport(manifest: manifest, certificateDER: certificateDER)
            try await transport.start()
            installationLock.withLock { installed = transport }
            return transport
        }

        public static var current: DebugFixtureTransport? {
            installationLock.withLock { installed }
        }

        init(manifest: Data, certificateDER: Data) throws {
            guard #available(macOS 14, iOS 17, tvOS 17, *) else { throw Failure.unavailable }
            guard manifest.count <= 16384, certificateDER.count <= 16384,
                  let certificate = SecCertificateCreateWithData(nil, certificateDER as CFData)
            else {
                throw Failure.invalidConfiguration
            }
            var parser = FixtureJSONParser(bytes: Array(manifest))
            guard let object = try parser.parse() as? [String: Any],
                  Set(object.keys) == Set(["fixtureOnly", "origin", "corsOrigin", "caPem", "tlsCertificatePem", "tlsSpkiSha256", "hosts", "accounts"]),
                  object["fixtureOnly"] as? Bool == true,
                  let originString = object["origin"] as? String,
                  let origin = URL(string: originString), let host = origin.host,
                  originString == "https://\(host)", Self.isFixtureHost(host), host.hasPrefix("gateway-"),
                  let caPath = object["caPem"] as? String, caPath.hasPrefix("/"),
                  let leafPath = object["tlsCertificatePem"] as? String, leafPath.hasPrefix("/"),
                  let spki = object["tlsSpkiSha256"] as? String,
                  let spkiBytes = Data(base64Encoded: spki), spkiBytes.count == 32, spkiBytes.base64EncodedString() == spki,
                  let cors = object["corsOrigin"] as? String, let corsURL = URL(string: cors),
                  ["http", "https"].contains(corsURL.scheme ?? ""),
                  ["127.0.0.1", "localhost", "::1"].contains(corsURL.host ?? ""),
                  corsURL.user == nil, corsURL.password == nil, corsURL.query == nil, corsURL.fragment == nil,
                  corsURL.path.isEmpty,
                  let rawAccounts = object["accounts"] as? [[String: Any]], rawAccounts.count == 2,
                  let rawHosts = object["hosts"] as? [String: String], rawHosts.count == 5
            else {
                throw Failure.invalidConfiguration
            }
            var accounts: [Account] = []
            var allowedHosts: Set<String> = [host, "chat.catbird.blue", "public.api.bsky.app"]
            for row in rawAccounts {
                guard Set(row.keys) == Set(["label", "did", "deviceId"]),
                      let label = row["label"] as? String, ["alice", "bob"].contains(label),
                      !accounts.contains(where: { $0.label == label }),
                      let did = row["did"] as? String, did.hasPrefix("did:web:"),
                      let device = row["deviceId"] as? String, UUID(uuidString: device)?.uuidString.lowercased() == device
                else {
                    throw Failure.invalidConfiguration
                }
                let accountHost = String(did.dropFirst(8))
                guard Self.isFixtureHost(accountHost), accountHost.hasPrefix(label + "-"),
                      !allowedHosts.contains(accountHost) else { throw Failure.invalidConfiguration }
                allowedHosts.insert(accountHost)
                accounts.append(Account(label: label, did: did, deviceId: device))
            }
            guard Set(rawHosts.keys) == allowedHosts else { throw Failure.invalidConfiguration }
            var ports: [String: UInt16] = [:]
            for (name, endpoint) in rawHosts {
                guard endpoint.hasPrefix("127.0.0.1:"),
                      let port = UInt16(endpoint.dropFirst(10)), port > 1023,
                      endpoint == "127.0.0.1:\(port)" else { throw Failure.invalidConfiguration }
                ports[name] = port
            }
            guard Set(ports.values).count == 1 else { throw Failure.invalidConfiguration }
            self.origin = origin
            self.accounts = accounts
            self.ports = ports
            self.certificate = certificate
            identity = SHA256.hash(data: manifest + certificateDER).map { String(format: "%02x", $0) }.joined()
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            listener = try NWListener(using: parameters)
        }

        private static func isFixtureHost(_ host: String) -> Bool {
            host.count < 254 && host.hasSuffix(".request-fixture.catbird.blue") &&
                host == host.lowercased() && host.utf8.allSatisfy { (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45 || $0 == 46 } &&
                !host.contains("..") && !host.hasPrefix(".") && !host.hasPrefix("-")
        }

        public func permits(_ url: URL) -> Bool {
            guard url.scheme == "https", let host = url.host, ports[host] != nil,
                  url.user == nil, url.password == nil, url.port == nil,
                  url.fragment == nil, !url.absoluteString.contains("\\") else { return false }
            return host == host.lowercased()
        }

        func require(_ url: URL) throws {
            guard permits(url) else { throw Failure.rejected }
        }

        /// Configures only the caller's new session. No global URLSession or proxy defaults.
        public func configure(_ configuration: URLSessionConfiguration) throws {
            guard #available(macOS 14, iOS 17, tvOS 17, *), proxyPort > 0 else { throw Failure.unavailable }
            var proxy = ProxyConfiguration(httpCONNECTProxy: .hostPort(host: .ipv4(.loopback), port: .init(rawValue: proxyPort)!))
            proxy.allowFailover = false
            configuration.proxyConfigurations = [proxy]
            configuration.urlCache = nil
            configuration.urlCredentialStorage = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 60
        }

        func approvedAddresses(for url: URL) throws -> Set<String> {
            try require(url)
            return ["127.0.0.1"]
        }

        func evaluate(_ trust: SecTrust, hostname: String) -> Bool {
            guard ports[hostname] != nil,
                  SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, hostname as CFString)) == errSecSuccess,
                  SecTrustSetAnchorCertificates(trust, [certificate] as CFArray) == errSecSuccess,
                  SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess else { return false }
            return SecTrustEvaluateWithError(trust, nil)
        }

        public func makeSession() throws -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            try configure(configuration)
            return URLSession(configuration: configuration, delegate: FixtureSessionDelegate(transport: self), delegateQueue: nil)
        }

        func start() async throws {
            try await withCheckedThrowingContinuation { continuation in
                readyLock.withLock { readyContinuation = continuation }
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        guard let port = self.listener.port else { self.finishStart(.failure(Failure.connection)); return }
                        self.proxyPort = port.rawValue
                        self.finishStart(.success(()))
                    case let .failed(error): self.finishStart(.failure(error))
                    case .cancelled: self.finishStart(.failure(Failure.connection))
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    guard let self, self.tunnels.count < 32 else { connection.cancel(); return }
                    let id = UUID()
                    let tunnel = FixtureTunnel(connection: connection, ports: self.ports, queue: self.queue) { [weak self] in self?.tunnels.removeValue(forKey: id) }
                    self.tunnels[id] = tunnel
                    tunnel.start()
                }
                listener.start(queue: queue)
                queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.finishStart(.failure(Failure.connection))
                }
            }
        }

        private func finishStart(_ result: Result<Void, Error>) {
            let continuation = readyLock.withLock { let value = readyContinuation; readyContinuation = nil; return value }
            continuation?.resume(with: result)
            if case .failure = result, continuation != nil {
                listener.cancel()
            }
        }
    }

    private final class FixtureSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let transport: DebugFixtureTransport
        init(transport: DebugFixtureTransport) {
            self.transport = transport
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let url = task.originalRequest?.url, transport.permits(url),
                  url.host == challenge.protectionSpace.host, let trust = challenge.protectionSpace.serverTrust,
                  transport.evaluate(trust, hostname: challenge.protectionSpace.host)
            else {
                completionHandler(.cancelAuthenticationChallenge, nil); return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }

    /// Serial-queue confined encrypted TCP relay. It neither terminates TLS nor reads application bodies.
    final class FixtureTunnel: @unchecked Sendable {
        let connection: NWConnection
        let ports: [String: UInt16]
        let queue: DispatchQueue
        let onClose: @Sendable () -> Void
        var upstream: NWConnection?
        var header = Data()
        var closed = false
        var connected = false
        init(connection: NWConnection, ports: [String: UInt16], queue: DispatchQueue, onClose: @escaping @Sendable () -> Void) {
            self.connection = connection; self.ports = ports; self.queue = queue; self.onClose = onClose
        }

        func start() {
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                if case .ready = state {
                    self.readHeader()
                }
                if case .failed = state {
                    self.close()
                }
                if case .cancelled = state {
                    self.close()
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 10) {
                [weak self] in if self?.connected == false {
                    self?.close()
                }
            }
            queue.asyncAfter(deadline: .now() + 120) { [weak self] in self?.close() }
        }

        func readHeader() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8193) { [weak self] bytes, _, complete, error in
                guard let self, !self.closed else { return }
                if let bytes {
                    self.header.append(bytes)
                }
                guard error == nil, !complete, self.header.count <= 8192 else { self.close(); return }
                guard let end = self.header.range(of: Data("\r\n\r\n".utf8)) else { self.readHeader(); return }
                guard end.upperBound == self.header.endIndex,
                      let host = try? Self.authority(self.header), let port = self.ports[host] else { self.close(); return }
                self.connect(port: port)
            }
        }

        static func authority(_ data: Data) throws -> String {
            guard data.count <= 8192, let text = String(data: data, encoding: .ascii),
                  let endRange = text.range(of: "\r\n\r\n"), endRange.upperBound == text.endIndex else { throw DebugFixtureTransport.Failure.rejected }
            let lines = String(text[..<endRange.lowerBound]).components(separatedBy: "\r\n")
            guard let first = lines.first else { throw DebugFixtureTransport.Failure.rejected }
            let words = first.split(separator: " ", omittingEmptySubsequences: false)
            guard words.count == 3, words[0] == "CONNECT", words[2] == "HTTP/1.1", words[1].hasSuffix(":443") else { throw DebugFixtureTransport.Failure.rejected }
            let authority = String(words[1]), host = String(words[1].dropLast(4))
            guard !host.isEmpty, host == host.lowercased(), host.utf8.allSatisfy({ (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45 || $0 == 46 }),
                  !host.contains(".."), !host.hasPrefix("."), !host.hasSuffix("."), host.contains(where: { $0.isLetter }) else { throw DebugFixtureTransport.Failure.rejected }
            var names = Set<String>(), sawHost = false
            for line in lines.dropFirst() {
                guard let colon = line.firstIndex(of: ":") else { throw DebugFixtureTransport.Failure.rejected }
                let name = String(line[..<colon]).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                guard ["host", "user-agent", "proxy-connection", "connection"].contains(name), names.insert(name).inserted,
                      !value.contains("\r"), !value.contains("\n") else { throw DebugFixtureTransport.Failure.rejected }
                if name == "host" {
                    // URLSession sends a portless Host for the standard 443 authority; accept either
                    // exact form and nothing else. Non-443 CONNECT ports stay rejected by the
                    // `hasSuffix(":443")` guard above, so a portless Host cannot mask a mismatch.
                    guard value == authority || value == host else { throw DebugFixtureTransport.Failure.rejected }; sawHost = true
                }
            }
            guard sawHost else { throw DebugFixtureTransport.Failure.rejected }
            return host
        }

        func connect(port: UInt16) {
            let peer = NWConnection(host: .ipv4(.loopback), port: .init(rawValue: port)!, using: .tcp)
            upstream = peer
            peer.stateUpdateHandler = { [weak self] state in
                guard let self, !self.closed else { return }
                switch state {
                case .ready:
                    self.connection.send(content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8), completion: .contentProcessed { [weak self] error in
                        guard let self, error == nil, !self.closed else { self?.close(); return }
                        self.connected = true
                        self.relay(self.connection, to: peer); self.relay(peer, to: self.connection)
                    })
                case .failed, .cancelled: self.close()
                default: break
                }
            }
            peer.start(queue: queue)
        }

        func relay(_ source: NWConnection, to destination: NWConnection) {
            source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] bytes, _, complete, error in
                guard let self, !self.closed, error == nil else { self?.close(); return }
                guard let bytes, !bytes.isEmpty else { self.close(); return }
                destination.send(content: bytes, completion: .contentProcessed { [weak self] error in
                    guard let self, !self.closed, error == nil, !complete else { self?.close(); return }
                    self.relay(source, to: destination)
                })
            }
        }

        func close() {
            guard !closed else { return }; closed = true
            connection.cancel(); upstream?.cancel(); onClose()
        }
    }

    /// Only the JSON kinds used by the manifest are accepted, with raw duplicate-key rejection.
    private struct FixtureJSONParser {
        let bytes: [UInt8]
        var offset = 0
        mutating func parse() throws -> Any {
            let result = try value(depth: 0); whitespace()
            guard offset == bytes.count else { throw DebugFixtureTransport.Failure.invalidConfiguration }
            return result
        }

        mutating func whitespace() {
            while offset < bytes.count, [9, 10, 13, 32].contains(bytes[offset]) {
                offset += 1
            }
        }

        mutating func value(depth: Int) throws -> Any {
            whitespace(); guard depth < 12, offset < bytes.count else { throw DebugFixtureTransport.Failure.invalidConfiguration }
            switch bytes[offset] {
            case 34: return try string()
            case 123:
                offset += 1; whitespace(); var object: [String: Any] = [:]
                if take(125) {
                    return object
                }
                while true {
                    whitespace(); let key = try string(); whitespace()
                    guard take(58), object[key] == nil else { throw DebugFixtureTransport.Failure.invalidConfiguration }
                    object[key] = try value(depth: depth + 1); whitespace()
                    if take(125) {
                        return object
                    }
                    guard take(44), object.count < 32 else { throw DebugFixtureTransport.Failure.invalidConfiguration }
                }
            case 91:
                offset += 1; whitespace(); var array: [Any] = []
                if take(93) {
                    return array
                }
                while true {
                    try array.append(value(depth: depth + 1)); whitespace()
                    if take(93) {
                        return array
                    }
                    guard take(44), array.count < 32 else { throw DebugFixtureTransport.Failure.invalidConfiguration }
                }
            default:
                for (literal, result) in [("true", true), ("false", false)] {
                    let token = Array(literal.utf8)
                    if bytes[offset...].starts(with: token) {
                        offset += token.count; return result
                    }
                }
                throw DebugFixtureTransport.Failure.invalidConfiguration
            }
        }

        mutating func take(_ byte: UInt8) -> Bool {
            guard offset < bytes.count, bytes[offset] == byte else { return false }; offset += 1; return true
        }

        mutating func string() throws -> String {
            let start = offset
            guard take(34) else { throw DebugFixtureTransport.Failure.invalidConfiguration }
            var escaped = false
            while offset < bytes.count {
                let byte = bytes[offset]; offset += 1
                if byte == 34 && !escaped {
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start ..< offset]))
                }
                if byte == 92 && !escaped {
                    escaped = true
                } else {
                    escaped = false
                }
            }
            throw DebugFixtureTransport.Failure.invalidConfiguration
        }
    }
#endif
