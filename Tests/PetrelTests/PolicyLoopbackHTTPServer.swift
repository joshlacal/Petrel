#if canImport(Darwin) || canImport(Glibc)
    import Dispatch
    import Foundation
    #if canImport(Darwin)
        import Darwin
    #else
        import Glibc
    #endif

    /// A small real HTTP transport for policy tests, including URLSession redirects.
    final class PolicyLoopbackHTTPServer: @unchecked Sendable {
        struct Request {
            let path: String
            let headers: [String: String]
        }

        struct Response {
            let statusCode: Int
            let headers: [String: String]
            let body: Data

            init(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
                self.statusCode = statusCode
                self.headers = headers
                self.body = body
            }
        }

        private final class State: @unchecked Sendable {
            let lock = NSLock()
            let completion = DispatchGroup()
            let queueKey = DispatchSpecificKey<Bool>()
            var listener: Int32
            var stopped = false
            var capturedRequests: [Request] = []

            init(listener: Int32) {
                self.listener = listener
            }

            var isStopped: Bool {
                lock.lock()
                defer { lock.unlock() }
                return stopped
            }

            func record(_ request: Request) {
                lock.lock()
                defer { lock.unlock() }
                capturedRequests.append(request)
            }
        }

        let baseURL: URL
        private let state: State
        private let queue: DispatchQueue

        var requests: [Request] {
            state.lock.lock()
            defer { state.lock.unlock() }
            return state.capturedRequests
        }

        /// Handlers run synchronously on the server queue and should return promptly.
        init(handler: @escaping @Sendable (Request) -> Response) throws {
            #if canImport(Darwin)
                let descriptor = socket(AF_INET, SOCK_STREAM, 0)
            #else
                let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
            #endif
            guard descriptor >= 0 else { throw Self.socketError() }
            var ownsDescriptor = true
            defer {
                if ownsDescriptor { _ = close(descriptor) }
            }

            try Self.makeNonblocking(descriptor)
            var address = sockaddr_in()
            #if canImport(Darwin)
                address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            #endif
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = 0
            address.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
            let bindResult = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0, listen(descriptor, 16) == 0 else {
                throw Self.socketError()
            }
            var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let nameResult = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(descriptor, $0, &addressLength)
                }
            }
            guard nameResult == 0 else { throw Self.socketError() }

            baseURL = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))")!
            let state = State(listener: descriptor)
            self.state = state
            queue = DispatchQueue(label: "PetrelTests.PolicyLoopbackHTTPServer")
            queue.setSpecific(key: state.queueKey, value: true)
            state.completion.enter()
            ownsDescriptor = false
            // Capture the separate state, so the worker cannot keep this server alive.
            queue.async {
                Self.serve(descriptor, state: state, handler: handler)
            }
        }

        deinit {
            stop()
        }

        func stop() {
            state.lock.lock()
            state.stopped = true
            if state.listener >= 0 {
                _ = shutdown(state.listener, Int32(SHUT_RDWR))
            }
            state.lock.unlock()
            // A handler may stop its own server; it must first return to the loop.
            if DispatchQueue.getSpecific(key: state.queueKey) != true {
                state.completion.wait()
            }
        }

        private static func serve(
            _ listener: Int32,
            state: State,
            handler: @Sendable (Request) -> Response
        ) {
            defer {
                // Only this queue closes descriptors. The lock serializes this close
                // with stop(), preventing shutdown of a subsequently reused fd.
                state.lock.lock()
                _ = close(listener)
                state.listener = -1
                state.stopped = true
                state.lock.unlock()
                state.completion.leave()
            }
            while !state.isStopped {
                // Polling also bounds shutdown on platforms where shutting down a
                // listening socket does not wake accept(). accept itself never blocks.
                let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
                guard waitUntilReady(listener, event: Int16(POLLIN), deadline: deadline, state: state) else {
                    continue
                }
                let client = accept(listener, nil, nil)
                guard client >= 0 else {
                    if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                    return
                }
                handle(client, state: state, handler: handler)
            }
        }

        private static func handle(
            _ client: Int32,
            state: State,
            handler: @Sendable (Request) -> Response
        ) {
            defer { _ = close(client) }
            guard !state.isStopped else { return }
            do {
                try makeNonblocking(client)
                var timeout = timeval(tv_sec: 2, tv_usec: 0)
                let size = socklen_t(MemoryLayout<timeval>.size)
                guard setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, size) == 0,
                      setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, size) == 0
                else { return }
                #if canImport(Darwin)
                    var noSignal: Int32 = 1
                    guard setsockopt(
                        client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal,
                        socklen_t(MemoryLayout<Int32>.size)
                    ) == 0 else { return }
                #endif
            } catch {
                return
            }

            // An absolute deadline also bounds clients that trickle bytes forever.
            let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
            guard let request = readRequest(client, deadline: deadline, state: state) else { return }
            state.record(request)
            guard !state.isStopped else { return }
            let response = handler(request)
            writeResponse(response, to: client, deadline: deadline, state: state)
        }

        private static func readRequest(_ client: Int32, deadline: UInt64, state: State) -> Request? {
            let limit = 16 * 1024
            let terminator = Data("\r\n\r\n".utf8)
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while data.count < limit {
                guard waitUntilReady(client, event: Int16(POLLIN), deadline: deadline, state: state) else {
                    return nil
                }
                let remaining = limit - data.count
                let count = buffer.withUnsafeMutableBytes {
                    recv(client, $0.baseAddress, min($0.count, remaining), 0)
                }
                if count < 0 {
                    if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                    return nil
                }
                guard count > 0 else { return nil }
                data.append(contentsOf: buffer.prefix(count))
                if let end = data.range(of: terminator) {
                    guard let head = String(data: data[..<end.lowerBound], encoding: .utf8) else { return nil }
                    return parseRequest(head)
                }
            }
            return nil
        }

        private static func parseRequest(_ head: String) -> Request? {
            let lines = head.components(separatedBy: "\r\n")
            guard let first = lines.first else { return nil }
            let parts = first.split(separator: " ", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "GET", parts[1].hasPrefix("/"),
                  parts[2] == "HTTP/1.1" || parts[2] == "HTTP/1.0"
            else { return nil }
            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let colon = line.firstIndex(of: ":") else { return nil }
                let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                guard !name.isEmpty else { return nil }
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if let previous = headers[name] {
                    headers[name] = previous + ", " + value
                } else {
                    headers[name] = value
                }
            }
            // This fixture supports bodyless GET requests only. Do not record a
            // header block as a complete request if it declares an unread body.
            guard headers["transfer-encoding"] == nil,
                  headers["content-length"] == nil || headers["content-length"] == "0"
            else { return nil }
            return Request(path: String(parts[1]), headers: headers)
        }

        private static func writeResponse(_ response: Response, to client: Int32, deadline: UInt64, state: State) {
            var head = "HTTP/1.1 \(response.statusCode) Response\r\n"
            for (name, value) in response.headers.sorted(by: { $0.key < $1.key }) {
                guard name.lowercased() != "content-length", name.lowercased() != "connection",
                      !name.contains("\r"), !name.contains("\n"),
                      !value.contains("\r"), !value.contains("\n")
                else { continue }
                head += "\(name): \(value)\r\n"
            }
            head += "Content-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
            var data = Data(head.utf8)
            data.append(response.body)
            data.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return }
                var offset = 0
                while offset < bytes.count {
                    guard waitUntilReady(client, event: Int16(POLLOUT), deadline: deadline, state: state) else {
                        return
                    }
                    #if canImport(Darwin)
                        let count = send(client, base.advanced(by: offset), bytes.count - offset, 0)
                    #else
                        let count = send(client, base.advanced(by: offset), bytes.count - offset, Int32(MSG_NOSIGNAL))
                    #endif
                    if count < 0 {
                        if errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK { continue }
                        return
                    }
                    guard count > 0 else { return }
                    offset += count
                }
            }
        }

        private static func waitUntilReady(
            _ descriptor: Int32,
            event: Int16,
            deadline: UInt64,
            state: State
        ) -> Bool {
            while !state.isStopped {
                let now = DispatchTime.now().uptimeNanoseconds
                guard now < deadline else { return false }
                let milliseconds = Int32(min(100, (deadline - now + 999_999) / 1_000_000))
                var descriptorState = pollfd(fd: descriptor, events: event, revents: 0)
                let result = poll(&descriptorState, 1, milliseconds)
                if result > 0 { return descriptorState.revents & event != 0 }
                if result < 0, errno != EINTR { return false }
            }
            return false
        }

        private static func makeNonblocking(_ descriptor: Int32) throws {
            let flags = fcntl(descriptor, F_GETFL, 0)
            guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
                throw socketError()
            }
        }

        private static func socketError() -> POSIXError {
            POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
#endif
