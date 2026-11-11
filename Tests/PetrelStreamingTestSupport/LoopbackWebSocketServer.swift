import Crypto
import Foundation
#if canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Darwin)
  import Darwin
#endif

/// A minimal RFC 6455 server on a real loopback TCP socket, for exercising the WebSocket
/// transports against actual framing instead of an in-memory fake.
///
/// It is test support only: blocking I/O, one thread per connection, no TLS, no
/// fragmentation, no extensions.
public final class LoopbackWebSocketServer: @unchecked Sendable {
  /// One HTTP request line plus headers, as received.
  public struct Request: Sendable {
    /// Request target, including the query string.
    public let target: String
    /// Header fields with lowercased names.
    public let headers: [String: String]

    public var isUpgrade: Bool {
      headers["upgrade"]?.lowercased() == "websocket"
    }

    public var path: String {
      String(target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    public var queryItems: [URLQueryItem] {
      URLComponents(string: "http://loopback" + target)?.queryItems ?? []
    }

    public func query(_ name: String) -> String? {
      queryItems.first(where: { $0.name == name })?.value
    }
  }

  /// One step of a connection script, executed in order after the handshake.
  public enum Step: Sendable {
    case binary(Data)
    case text(String)
    /// Sleep before the next step.
    case wait(TimeInterval)
    /// Block until the client has sent at least this many text messages on this connection.
    case awaitClientText(count: Int)
    /// Send a close frame, then close the socket.
    case close(code: UInt16)
    /// Close the TCP connection without a close frame.
    case drop
  }

  public enum Response: Sendable {
    /// Complete the handshake, run `script`, then keep the connection open until the client
    /// leaves (unless the script ended with `.close` or `.drop`).
    case accept(subprotocol: String? = nil, script: [Step])
    /// Answer with a plain HTTP response instead of upgrading.
    case http(status: Int, headers: [String: String] = [:], body: Data = Data())
  }

  private let listener: Int32
  public let port: UInt16
  private let handler: @Sendable (_ connection: Int, _ request: Request) -> Response
  private let lock = NSCondition()
  private var stopped = false
  private var connectionCount = 0
  private var recordedRequests: [Request] = []
  private var clientTexts: [Int: [String]] = [:]
  private var pongs = 0
  private var pings = 0
  private var openSockets: Set<Int32> = []

  /// Starts listening on `127.0.0.1` at an ephemeral port. `handler` is called once per
  /// accepted TCP connection with a zero-based connection index.
  public init(handler: @escaping @Sendable (_ connection: Int, _ request: Request) -> Response) throws {
    self.handler = handler
    #if canImport(Glibc) || canImport(Musl)
      let streamType = Int32(SOCK_STREAM.rawValue)
    #else
      let streamType = SOCK_STREAM
    #endif
    let fd = socket(AF_INET, streamType, 0)
    guard fd >= 0 else { throw POSIXError(.EIO) }
    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: UInt32(0x7F00_0001).bigEndian)
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bound == 0, listen(fd, 16) == 0 else {
      _ = Self.closeSocket(fd)
      throw POSIXError(.EADDRINUSE)
    }
    var actual = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &actual) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        getsockname(fd, $0, &length)
      }
    }
    listener = fd
    port = UInt16(bigEndian: actual.sin_port)

    let thread = Thread { [self] in acceptLoop() }
    thread.name = "LoopbackWebSocketServer.accept"
    thread.start()
  }

  deinit {
    stop()
  }

  /// `ws://127.0.0.1:<port><pathAndQuery>`
  public func webSocketURL(_ pathAndQuery: String = "/") -> URL {
    URL(string: "ws://127.0.0.1:\(port)\(pathAndQuery)")!
  }

  /// `http://127.0.0.1:<port><pathAndQuery>`
  public func httpURL(_ pathAndQuery: String = "/") -> URL {
    URL(string: "http://127.0.0.1:\(port)\(pathAndQuery)")!
  }

  public func stop() {
    lock.lock()
    let wasStopped = stopped
    stopped = true
    let sockets = openSockets
    openSockets.removeAll()
    lock.broadcast()
    lock.unlock()
    guard !wasStopped else { return }
    _ = Self.closeSocket(listener)
    for socket in sockets {
      shutdown(socket, Int32(SHUT_RDWR))
    }
  }

  /// Every request received so far, in arrival order.
  public var requests: [Request] {
    lock.lock()
    defer { lock.unlock() }
    return recordedRequests
  }

  /// Requests that asked for a WebSocket upgrade.
  public var upgradeRequests: [Request] {
    requests.filter(\.isUpgrade)
  }

  /// Text messages the client sent, across all connections, in arrival order per connection.
  public var receivedTexts: [String] {
    lock.lock()
    defer { lock.unlock() }
    return clientTexts.keys.sorted().flatMap { clientTexts[$0] ?? [] }
  }

  /// Number of ping frames received from clients.
  public var pingCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return pings
  }

  // MARK: - Connection handling

  private func acceptLoop() {
    while true {
      let client = accept(listener, nil, nil)
      if client < 0 {
        lock.lock()
        let done = stopped
        lock.unlock()
        if done { return }
        if errno == EINTR { continue }
        return
      }
      #if canImport(Darwin)
        var yes: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
      #endif
      lock.lock()
      let index = connectionCount
      connectionCount += 1
      openSockets.insert(client)
      lock.unlock()
      let thread = Thread { [self] in
        serve(client, index: index)
        lock.lock()
        openSockets.remove(client)
        lock.unlock()
        _ = Self.closeSocket(client)
      }
      thread.name = "LoopbackWebSocketServer.connection.\(index)"
      thread.start()
    }
  }

  private func serve(_ socket: Int32, index: Int) {
    guard let request = readRequest(socket) else { return }
    lock.lock()
    recordedRequests.append(request)
    lock.unlock()

    switch handler(index, request) {
    case let .http(status, headers, body):
      var head = "HTTP/1.1 \(status) \(Self.reason(status))\r\n"
      var fields = headers
      fields["Content-Length"] = String(body.count)
      fields["Connection"] = "close"
      for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
        head += "\(name): \(value)\r\n"
      }
      head += "\r\n"
      _ = sendAll(socket, Data(head.utf8) + body)

    case let .accept(subprotocol, script):
      guard request.isUpgrade, let key = request.headers["sec-websocket-key"] else {
        _ = sendAll(socket, Data("HTTP/1.1 426 Upgrade Required\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
        return
      }
      let digest = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
      var head = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
      head += "Sec-WebSocket-Accept: \(Data(digest).base64EncodedString())\r\n"
      if let subprotocol {
        head += "Sec-WebSocket-Protocol: \(subprotocol)\r\n"
      }
      head += "\r\n"
      guard sendAll(socket, Data(head.utf8)) else { return }

      let writeLock = NSLock()
      let readerDone = DispatchSemaphore(value: 0)
      let reader = Thread { [self] in
        readFrames(socket, index: index, writeLock: writeLock)
        readerDone.signal()
      }
      reader.start()

      var open = true
      scriptLoop: for step in script {
        switch step {
        case let .binary(data):
          open = sendFrame(socket, opcode: 0x2, payload: data, writeLock: writeLock)
        case let .text(text):
          open = sendFrame(socket, opcode: 0x1, payload: Data(text.utf8), writeLock: writeLock)
        case let .wait(interval):
          Thread.sleep(forTimeInterval: interval)
        case let .awaitClientText(count):
          lock.lock()
          while !stopped, (clientTexts[index]?.count ?? 0) < count {
            if !lock.wait(until: Date().addingTimeInterval(10)) { break }
          }
          lock.unlock()
        case let .close(code):
          var payload = Data()
          payload.append(UInt8(code >> 8))
          payload.append(UInt8(code & 0xFF))
          _ = sendFrame(socket, opcode: 0x8, payload: payload, writeLock: writeLock)
          open = false
        case .drop:
          open = false
        }
        if !open { break scriptLoop }
      }
      if !open {
        shutdown(socket, Int32(SHUT_RDWR))
      }
      // Hold the connection until the client leaves or the server stops.
      readerDone.wait()
    }
  }

  private func readFrames(_ socket: Int32, index: Int, writeLock: NSLock) {
    while true {
      guard let header = readExactly(socket, 2) else { return }
      let opcode = header[0] & 0x0F
      let masked = header[1] & 0x80 != 0
      var length = UInt64(header[1] & 0x7F)
      if length == 126 {
        guard let ext = readExactly(socket, 2) else { return }
        length = UInt64(ext[0]) << 8 | UInt64(ext[1])
      } else if length == 127 {
        guard let ext = readExactly(socket, 8) else { return }
        length = ext.reduce(0) { $0 << 8 | UInt64($1) }
      }
      var mask: [UInt8] = []
      if masked {
        guard let key = readExactly(socket, 4) else { return }
        mask = key
      }
      guard length <= 16_000_000, var payload = readExactly(socket, Int(length)) else { return }
      if masked {
        for i in payload.indices {
          payload[i] ^= mask[i % 4]
        }
      }
      switch opcode {
      case 0x1:
        lock.lock()
        clientTexts[index, default: []].append(String(decoding: payload, as: UTF8.self))
        lock.broadcast()
        lock.unlock()
      case 0x8:
        _ = sendFrame(socket, opcode: 0x8, payload: Data(payload.prefix(2)), writeLock: writeLock)
        return
      case 0x9:
        lock.lock()
        pings += 1
        lock.unlock()
        _ = sendFrame(socket, opcode: 0xA, payload: Data(payload), writeLock: writeLock)
      case 0xA:
        lock.lock()
        pongs += 1
        lock.unlock()
      default:
        break
      }
    }
  }

  // MARK: - Wire helpers

  private func readRequest(_ socket: Int32) -> Request? {
    var buffer: [UInt8] = []
    var byte: UInt8 = 0
    let terminator: [UInt8] = [13, 10, 13, 10]
    while buffer.count < 65_536 {
      let count = recv(socket, &byte, 1, 0)
      if count <= 0 { return nil }
      buffer.append(byte)
      if buffer.count >= 4, Array(buffer.suffix(4)) == terminator { break }
    }
    let text = String(decoding: buffer, as: UTF8.self)
    let lines = text.components(separatedBy: "\r\n")
    let requestLine = lines.first?.split(separator: " ") ?? []
    guard requestLine.count >= 2 else { return nil }
    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      guard let colon = line.firstIndex(of: ":") else { continue }
      let name = line[..<colon].lowercased()
      let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      headers[name] = value
    }
    return Request(target: String(requestLine[1]), headers: headers)
  }

  private func readExactly(_ socket: Int32, _ count: Int) -> [UInt8]? {
    var buffer = [UInt8](repeating: 0, count: count)
    var offset = 0
    while offset < count {
      let received = buffer.withUnsafeMutableBytes { pointer in
        recv(socket, pointer.baseAddress!.advanced(by: offset), count - offset, 0)
      }
      if received <= 0 {
        if received < 0, errno == EINTR { continue }
        return nil
      }
      offset += received
    }
    return buffer
  }

  private func sendFrame(_ socket: Int32, opcode: UInt8, payload: Data, writeLock: NSLock) -> Bool {
    var frame = Data([0x80 | opcode])
    if payload.count < 126 {
      frame.append(UInt8(payload.count))
    } else if payload.count <= 0xFFFF {
      frame.append(126)
      frame.append(UInt8(payload.count >> 8))
      frame.append(UInt8(payload.count & 0xFF))
    } else {
      frame.append(127)
      for shift in stride(from: 56, through: 0, by: -8) {
        frame.append(UInt8((UInt64(payload.count) >> UInt64(shift)) & 0xFF))
      }
    }
    frame.append(payload)
    writeLock.lock()
    defer { writeLock.unlock() }
    return sendAll(socket, frame)
  }

  private func sendAll(_ socket: Int32, _ data: Data) -> Bool {
    #if canImport(Glibc) || canImport(Musl)
      let flags = Int32(MSG_NOSIGNAL)
    #else
      let flags: Int32 = 0
    #endif
    var offset = 0
    let bytes = [UInt8](data)
    while offset < bytes.count {
      let sent = bytes.withUnsafeBytes { pointer in
        send(socket, pointer.baseAddress!.advanced(by: offset), bytes.count - offset, flags)
      }
      if sent <= 0 {
        if sent < 0, errno == EINTR { continue }
        return false
      }
      offset += sent
    }
    return true
  }

  private static func closeSocket(_ socket: Int32) -> Int32 {
    close(socket)
  }

  private static func reason(_ status: Int) -> String {
    switch status {
    case 200: "OK"
    case 400: "Bad Request"
    case 401: "Unauthorized"
    case 404: "Not Found"
    case 426: "Upgrade Required"
    case 429: "Too Many Requests"
    case 501: "Not Implemented"
    case 503: "Service Unavailable"
    default: "Status"
    }
  }
}
