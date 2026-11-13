import Darwin
import Foundation
import LoopbackOAuthFeature
import Testing

@Suite("LoopbackCallbackServer")
struct LoopbackCallbackServerTests {
    @Test("Cancelling the Task awaiting waitForCallback() resumes promptly with CancellationError")
    func cancellingWaitTaskResumesWithCancellationError() async throws {
        let port = try Self.findAvailableLoopbackPort()
        let server = try LoopbackCallbackServer(port: port)

        let waitTask = Task {
            try await server.waitForCallback()
        }

        try await Self.waitUntilListening(server)
        waitTask.cancel()

        let outcome = try await Self.awaitWithin(seconds: 2.0) {
            await waitTask.result
        }

        switch outcome {
        case let .success(url):
            Issue.record("Expected CancellationError, but waitForCallback() returned \(url)")
        case let .failure(error):
            #expect(error is CancellationError)
        }
    }

    @Test("Calling stop() before a redirect arrives resumes waitForCallback() with cancelledBeforeCallback")
    func stoppingServerBeforeRedirectResumesWithCancelledBeforeCallback() async throws {
        let port = try Self.findAvailableLoopbackPort()
        let server = try LoopbackCallbackServer(port: port)

        let waitTask = Task {
            try await server.waitForCallback()
        }

        try await Self.waitUntilListening(server)
        await server.stop()

        let outcome = try await Self.awaitWithin(seconds: 2.0) {
            await waitTask.result
        }

        switch outcome {
        case let .success(url):
            Issue.record("Expected ServerError.cancelledBeforeCallback, got \(url)")
        case let .failure(error):
            #expect(error as? LoopbackCallbackServer.ServerError == .cancelledBeforeCallback)
        }
    }

    @Test("Valid GET /callback redirect receives HTTP 200 OK and resolves the callback URL")
    func validRedirectResolvesCallbackURL() async throws {
        let port = try Self.findAvailableLoopbackPort()
        let server = try LoopbackCallbackServer(port: port)

        let waitTask = Task {
            try await server.waitForCallback()
        }

        try await Self.waitUntilListening(server)

        let rawResponse = try await Task.detached {
            try Self.sendLoopbackHTTPRequest(
                port: port,
                request: "GET /callback?code=123&state=abc HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n\r\n"
            )
        }.value

        #expect(rawResponse.hasPrefix("HTTP/1.1 200 OK\r\n"))

        let resolvedURL = try await Self.awaitWithin(seconds: 2.0) {
            try await waitTask.value
        }
        #expect(resolvedURL == URL(string: "http://127.0.0.1:\(port)/callback?code=123&state=abc"))
    }

    @Test("Fragmented multi-segment GET /callback request accumulates until CRLF and preserves all query parameters")
    func fragmentedRedirectRequestAccumulatesCompleteRequestLine() async throws {
        let port = try Self.findAvailableLoopbackPort()
        let server = try LoopbackCallbackServer(port: port)

        let waitTask = Task {
            try await server.waitForCallback()
        }

        try await Self.waitUntilListening(server)

        let chunks = [
            "GET /callb",
            "ack?code=frag_code_987&state=state_xyz",
            "&iss=https%3A%2F%2Fbsky.social HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n\r\n",
        ]
        let rawResponse = try await Task.detached {
            try Self.sendFragmentedLoopbackHTTPRequest(
                port: port,
                chunks: chunks,
                interChunkDelayMicroseconds: 20_000
            )
        }.value

        #expect(rawResponse.hasPrefix("HTTP/1.1 200 OK\r\n"))

        let resolvedURL = try await Self.awaitWithin(seconds: 2.0) {
            try await waitTask.value
        }
        #expect(
            resolvedURL
                == URL(
                    string: "http://127.0.0.1:\(port)/callback?code=frag_code_987&state=state_xyz&iss=https%3A%2F%2Fbsky.social"
                )
        )
    }

    @Test("Aborted preconnects and unrelated paths do not tear down the listener before the real callback arrives")
    func preconnectAbortAndUnrelatedPathKeepListenerAliveUntilValidCallback() async throws {
        let port = try Self.findAvailableLoopbackPort()
        let server = try LoopbackCallbackServer(port: port)

        let waitTask = Task {
            try await server.waitForCallback()
        }

        try await Self.waitUntilListening(server)

        // 1. Browser TCP preconnect that closes immediately without sending bytes.
        try await Task.detached {
            try Self.openAndImmediatelyCloseLoopbackSocket(port: port)
        }.value

        // 2. Unrelated `/favicon.ico` probe and prefix-collision `/callback-extra` both get HTTP 400.
        let faviconResponse = try await Task.detached {
            try Self.sendLoopbackHTTPRequest(
                port: port,
                request: "GET /favicon.ico HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n\r\n"
            )
        }.value
        #expect(faviconResponse.hasPrefix("HTTP/1.1 400 Bad Request\r\n"))

        let prefixCollisionResponse = try await Task.detached {
            try Self.sendLoopbackHTTPRequest(
                port: port,
                request: "GET /callback-extra?code=wrong HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n\r\n"
            )
        }.value
        #expect(prefixCollisionResponse.hasPrefix("HTTP/1.1 400 Bad Request\r\n"))

        // 3. Subsequent valid OAuth redirect succeeds on the same waitForCallback() call.
        let okResponse = try await Task.detached {
            try Self.sendLoopbackHTTPRequest(
                port: port,
                request: "GET /callback?code=real_code&state=real_state HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\nConnection: close\r\n\r\n"
            )
        }.value
        #expect(okResponse.hasPrefix("HTTP/1.1 200 OK\r\n"))

        let resolvedURL = try await Self.awaitWithin(seconds: 2.0) {
            try await waitTask.value
        }
        #expect(resolvedURL == URL(string: "http://127.0.0.1:\(port)/callback?code=real_code&state=real_state"))
    }

    // MARK: - Helpers

    private struct TimeoutError: Error {}

    private static func waitUntilListening(_ server: LoopbackCallbackServer) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if await server.isListening {
                return
            }
            try await Task.sleep(for: .milliseconds(15))
        }
        throw TimeoutError()
    }

    private static func awaitWithin<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    private static func findAvailableLoopbackPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EADDRINUSE)
        }

        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard nameResult == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        return Int(UInt16(bigEndian: boundAddr.sin_port))
    }

    private static func sendLoopbackHTTPRequest(port: Int, request: String) throws -> String {
        try sendFragmentedLoopbackHTTPRequest(
            port: port,
            chunks: [request],
            interChunkDelayMicroseconds: 0
        )
    }

    private static func sendFragmentedLoopbackHTTPRequest(
        port: Int,
        chunks: [String],
        interChunkDelayMicroseconds: useconds_t
    ) throws -> String {
        let fd = try openConnectedLoopbackSocket(port: port)
        defer { close(fd) }

        var noDelay: Int32 = 1
        _ = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &noDelay, socklen_t(MemoryLayout<Int32>.size))

        for (index, chunk) in chunks.enumerated() {
            if index > 0 && interChunkDelayMicroseconds > 0 {
                usleep(interChunkDelayMicroseconds)
            }
            let chunkBytes = Array(chunk.utf8)
            let sent = chunkBytes.withUnsafeBufferPointer { buf in
                send(fd, buf.baseAddress, buf.count, 0)
            }
            guard sent == chunkBytes.count else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
        }

        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count > 0 {
                responseData.append(buffer, count: count)
            } else {
                break
            }
        }
        return String(decoding: responseData, as: UTF8.self)
    }

    private static func openAndImmediatelyCloseLoopbackSocket(port: Int) throws {
        let fd = try openConnectedLoopbackSocket(port: port)
        close(fd)
        usleep(15_000)
    }

    private static func openConnectedLoopbackSocket(port: Int) throws -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else {
            let err = errno
            close(fd)
            throw POSIXError(.init(rawValue: err) ?? .ECONNREFUSED)
        }
        return fd
    }
}
