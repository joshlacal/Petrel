import Crypto
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
#if canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Darwin)
  import Darwin
#endif
import libzstd
import Petrel
import PetrelFirehose
import PetrelJetstream

let rawDictBytes = Data("app.bsky.feed.postapp.bsky.graph.followdid:plc:{\"$type\":\"message\",\"payload\":{\"collection\":\"app.bsky.feed.post\"}}".utf8)

func compressWithDictionary(_ data: Data, dictionary: Data) throws -> Data {
  let cdict = dictionary.withUnsafeBytes { ptr in
    ZSTD_createCDict(ptr.baseAddress, ptr.count, 3)
  }
  guard let cdict else {
    throw NSError(domain: "zstd", code: 1, userInfo: [NSLocalizedDescriptionKey: "CDict failed"])
  }
  defer { ZSTD_freeCDict(cdict) }
  guard let cctx = ZSTD_createCCtx() else {
    throw NSError(domain: "zstd", code: 2, userInfo: [NSLocalizedDescriptionKey: "CCtx failed"])
  }
  defer { ZSTD_freeCCtx(cctx) }
  let bound = ZSTD_compressBound(data.count)
  var out = Data(count: bound)
  let written = out.withUnsafeMutableBytes { dst in
    data.withUnsafeBytes { src in
      ZSTD_compress_usingCDict(cctx, dst.baseAddress, dst.count, src.baseAddress, src.count, cdict)
    }
  }
  if ZSTD_isError(written) != 0 {
    throw NSError(domain: "zstd", code: 3, userInfo: [NSLocalizedDescriptionKey: "compress failed"])
  }
  out.removeSubrange(written ..< out.count)
  return out
}

func runServe() async throws {
  let idFrame = try FirehoseFrameEncoder.identityFrame(
    seq: 1,
    material: PublicFirehoseIdentityMaterial(
      did: "did:plc:swiftinterop",
      handle: "swift.interop.test",
      time: "2026-01-01T00:00:00.000Z"
    )
  )
  let acctFrame = try FirehoseFrameEncoder.accountFrame(
    seq: 2,
    material: PublicFirehoseAccountMaterial(
      did: "did:plc:swiftinterop",
      active: false,
      status: .deactivated,
      time: "2026-01-01T00:00:01.000Z"
    )
  )
  let infoFrame = try FirehoseFrameEncoder.infoFrame(name: "SwiftInfo", message: "hello-rust")

  let firehoseServer = try LoopbackWebSocketServer { _, req in
    guard req.isUpgrade else { return .http(status: 426) }
    return .accept(
      subprotocol: req.headers["sec-websocket-protocol"],
      script: [
        .binary(idFrame),
        .binary(acctFrame),
        .binary(infoFrame),
        .close(code: 1000),
      ]
    )
  }

  let jetJson1 = """
  {"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit","seq":1,"did":"did:plc:swiftjet","time":"2026-01-01T00:00:00.123456Z","rev":"3k7v2abc23456","operation":"create","collection":"app.bsky.feed.post","rkey":"3k7v2abc23456"}}
  """
  let jetJson2 = Data("""
  {"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit","seq":2,"did":"did:plc:swiftjet","time":"2026-01-01T00:00:01.654321Z","rev":"3k7v2abc23457","operation":"create","collection":"app.bsky.feed.post","rkey":"3k7v2abc23457","record":{"$type":"app.bsky.feed.post","text":"from-swift-libzstd"}}}
  """.utf8)
  let jetZstd2 = try compressWithDictionary(jetJson2, dictionary: rawDictBytes)

  let jetstreamServer = try LoopbackWebSocketServer { _, req in
    if req.path.hasSuffix(".getZstdDictionary") {
      return .http(status: 200, headers: ["Content-Type": "application/octet-stream"], body: rawDictBytes)
    }
    guard req.isUpgrade else {
      return .http(status: 426)
    }
    guard req.headers["sec-websocket-protocol"]?.contains("xrpc.v1.json") == true else {
      return .http(status: 400, body: Data("missing xrpc.v1.json".utf8))
    }
    return .accept(
      subprotocol: "xrpc.v1.json",
      script: [
        .text(jetJson1),
        .binary(jetZstd2),
        .close(code: 1000),
      ]
    )
  }

  let banner = "FIREHOSE_PORT=\(firehoseServer.port)\nJETSTREAM_PORT=\(jetstreamServer.port)\n"
  FileHandle.standardOutput.write(Data(banner.utf8))

  // Block until Rust closes our stdin pipe.
  while true {
    let chunk = FileHandle.standardInput.readData(ofLength: 1024)
    if chunk.isEmpty { break }
  }
  firehoseServer.stop()
  jetstreamServer.stop()
}

// Lightweight POSIX RFC 6455 WebSocket client so consume works identically on macOS and Linux.
final class PosixWebSocketSession: FirehoseWebSocketSession, @unchecked Sendable {
  private let fd: Int32
  private let textFrames: FirehoseWebSocketOptions.TextFrameHandling
  private var buffer = Data()
  private let lock = NSLock()
  private var isClosed = false

  init(url: URL, subprotocols: [String], textFrames: FirehoseWebSocketOptions.TextFrameHandling) throws {
    guard let host = url.host, let port = url.port ?? (url.scheme == "wss" ? 443 : 80) as Int? else {
      throw FirehoseSubscriptionError.connectionClosed
    }
    let sock = Self.connectTCP(host: host, port: UInt16(port))
    guard sock >= 0 else { throw FirehoseSubscriptionError.connectionClosed }
    self.fd = sock
    self.textFrames = textFrames

    var path = url.path.isEmpty ? "/" : url.path
    if let query = url.query, !query.isEmpty { path += "?\(query)" }
    var keyBytes = [UInt8](repeating: 0, count: 16)
    for i in 0 ..< keyBytes.count { keyBytes[i] = UInt8.random(in: 0 ... 255) }
    let key = Data(keyBytes).base64EncodedString()
    var req = "GET \(path) HTTP/1.1\r\nHost: \(host):\(port)\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: \(key)\r\nSec-WebSocket-Version: 13\r\n"
    if !subprotocols.isEmpty {
      req += "Sec-WebSocket-Protocol: \(subprotocols.joined(separator: ", "))\r\n"
    }
    req += "\r\n"
    try Self.writeAll(fd: sock, data: Data(req.utf8))

    // Read HTTP response headers
    while true {
      if let range = buffer.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) {
        let headerData = buffer[..<range.lowerBound]
        buffer.removeSubrange(..<range.upperBound)
        let headerText = String(decoding: headerData, as: UTF8.self)
        guard headerText.contains(" 101 ") else {
          Self.closeFD(sock)
          throw FirehoseSubscriptionError.upgradeRejected(status: 400, retryAfter: nil)
        }
        break
      }
      let chunk = try Self.readSome(fd: sock)
      if chunk.isEmpty {
        Self.closeFD(sock)
        throw FirehoseSubscriptionError.connectionClosed
      }
      buffer.append(chunk)
    }
  }

  deinit { Self.closeFD(fd) }

  func receiveMessage() async throws -> Data {
    while true {
      let (opcode, payload) = try readNextFrame()
      switch opcode {
      case 0x1:
        guard textFrames == .utf8Data else {
          throw FirehoseSubscriptionError.unsupportedMessageFormat
        }
        return payload
      case 0x2:
        return payload
      case 0x8:
        throw FirehoseSubscriptionError.connectionClosed
      case 0x9:
        try sendFrame(opcode: 0xA, payload: payload)
      case 0xA:
        continue
      default:
        continue
      }
    }
  }

  func close() async {
    let shouldClose = lock.withLock {
      let wasOpen = !isClosed
      isClosed = true
      return wasOpen
    }
    if shouldClose { Self.closeFD(fd) }
  }

  private func sendFrame(opcode: UInt8, payload: Data) throws {
    var out = Data([0x80 | opcode])
    let mask = [UInt8(0x11), 0x22, 0x33, 0x44]
    let count = payload.count
    if count < 126 {
      out.append(0x80 | UInt8(count))
    } else if count <= 0xFFFF {
      out.append(0x80 | 126)
      out.append(UInt8((count >> 8) & 0xFF))
      out.append(UInt8(count & 0xFF))
    } else {
      out.append(0x80 | 127)
      for shift in stride(from: 56, through: 0, by: -8) {
        out.append(UInt8((count >> shift) & 0xFF))
      }
    }
    out.append(contentsOf: mask)
    for (idx, b) in payload.enumerated() {
      out.append(b ^ mask[idx % 4])
    }
    try Self.writeAll(fd: fd, data: out)
  }

  private func readNextFrame() throws -> (UInt8, Data) {
    let head = try readExact(2)
    let opcode = head[0] & 0x0F
    let masked = (head[1] & 0x80) != 0
    var len = Int(head[1] & 0x7F)
    if len == 126 {
      let ext = try readExact(2)
      len = (Int(ext[0]) << 8) | Int(ext[1])
    } else if len == 127 {
      let ext = try readExact(8)
      var v = 0
      for b in ext { v = (v << 8) | Int(b) }
      len = v
    }
    let maskKey = masked ? Array(try readExact(4)) : []
    var payload = try readExact(len)
    if masked {
      for i in 0 ..< payload.count { payload[i] ^= maskKey[i % 4] }
    }
    return (opcode, payload)
  }

  private func readExact(_ n: Int) throws -> Data {
    while buffer.count < n {
      let chunk = try Self.readSome(fd: fd)
      if chunk.isEmpty { throw FirehoseSubscriptionError.connectionClosed }
      buffer.append(chunk)
    }
    let out = Data(buffer.prefix(n))
    buffer.removeFirst(n)
    return out
  }

  private static func readSome(fd: Int32) throws -> Data {
    var tmp = [UInt8](repeating: 0, count: 4096)
    #if canImport(Darwin)
      let n = Darwin.recv(fd, &tmp, tmp.count, 0)
    #else
      let n = Glibc.recv(fd, &tmp, tmp.count, 0)
    #endif
    if n < 0 { throw FirehoseSubscriptionError.connectionClosed }
    return Data(tmp.prefix(n))
  }

  private static func writeAll(fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { ptr in
      guard let base = ptr.baseAddress else { return }
      var offset = 0
      while offset < data.count {
        #if canImport(Darwin)
          let sent = Darwin.send(fd, base.advanced(by: offset), data.count - offset, 0)
        #else
          let sent = Glibc.send(fd, base.advanced(by: offset), data.count - offset, 0)
        #endif
        if sent <= 0 { throw FirehoseSubscriptionError.connectionClosed }
        offset += sent
      }
    }
  }

  private static func connectTCP(host: String, port: UInt16) -> Int32 {
    #if canImport(Darwin)
      let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    #else
      let fd = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #endif
    guard fd >= 0 else { return -1 }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr(host == "localhost" ? "127.0.0.1" : host)
    let res = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        #if canImport(Darwin)
          return Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        #else
          return Glibc.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        #endif
      }
    }
    if res != 0 {
      closeFD(fd)
      return -1
    }
    return fd
  }

  private static func closeFD(_ fd: Int32) {
    #if canImport(Darwin)
      Darwin.close(fd)
    #else
      Glibc.close(fd)
    #endif
  }
}

struct PosixWebSocketFactory: FirehoseWebSocketSessionFactory {
  let options: FirehoseWebSocketOptions

  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    try await makeSession(url: url, subprotocols: [])
  }

  func makeSession(url: URL, subprotocols: [String]) async throws -> any FirehoseWebSocketSession {
    try PosixWebSocketSession(url: url, subprotocols: subprotocols, textFrames: options.textFrames)
  }
}

func runConsume(firehoseURL: URL, jetstreamURL: URL) async throws {
  let firehoseSub = FirehoseSubscription(
    configuration: FirehoseSubscriptionConfiguration(
      url: firehoseURL,
      sessionFactory: PosixWebSocketFactory(options: FirehoseWebSocketOptions())
    )
  )
  var firehoseCount = 0
  for try await item in firehoseSub.events() {
    switch item {
    case let .event(.identity(id)):
      precondition(id.seq == 1 && id.did == "did:plc:rustinterop")
      firehoseCount += 1
    case let .event(.account(acct)):
      precondition(acct.seq == 2 && acct.status == "suspended")
      firehoseCount += 1
    case let .event(.info(info)):
      precondition(info.name == "RustInfo")
      firehoseCount += 1
    default:
      fatalError("unexpected firehose event: \(item)")
    }
    if firehoseCount == 3 { break }
  }
  precondition(firehoseCount == 3)

  var jetConfig = JetstreamSubscriptionConfiguration(
    url: jetstreamURL,
    compression: true,
    sessionFactory: PosixWebSocketFactory(options: .jetstream)
  )
  jetConfig.httpTransport = URLSessionJetstreamHTTPTransport()
  let jetSub = JetstreamSubscription(configuration: jetConfig)
  var jetCount = 0
  for try await item in jetSub.events() {
    switch item {
    case let .event(.commit(commit)):
      jetCount += 1
      if commit.seq == 1 {
        precondition(commit.did == "did:plc:rustjet")
      } else {
        precondition(commit.seq == 7 && commit.did == "did:plc:abc")
      }
    default:
      fatalError("unexpected jetstream event: \(item)")
    }
    if jetCount == 2 { break }
  }
  precondition(jetCount == 2)
  print("SWIFT_CONSUME_OK")
}

@main
struct ProbeMain {
  static func main() async throws {
    let args = CommandLine.arguments
    if args.count >= 2, args[1] == "serve" {
      try await runServe()
    } else if args.count >= 6, args[1] == "consume", args[2] == "--firehose-url", args[4] == "--jetstream-url" {
      let fUrl = URL(string: args[3])!
      let jUrl = URL(string: args[5])!
      try await runConsume(firehoseURL: fUrl, jetstreamURL: jUrl)
    } else {
      FileHandle.standardError.write(
        Data("Usage: petrel-swift-stream-probe <serve | consume --firehose-url URL --jetstream-url URL>\n".utf8)
      )
      exit(2)
    }
  }
}
