import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Whether this platform's `URLSession` can open WebSockets at all.
///
/// On Apple platforms it always can. On Linux, swift-corelibs-foundation needs a libcurl built
/// with WebSocket support; the Swift 6.1 Ubuntu 22.04 image (libcurl 7.81) fails every
/// `URLSessionWebSocketTask` with `URLError(.unsupportedURL)`. Real-socket tests are skipped
/// there instead of failing, and the typed-error path is covered by unit tests.
public actor URLSessionWebSocketAvailability {
  public static let shared = URLSessionWebSocketAvailability()
  private var cached: Bool?

  public func isAvailable() async -> Bool {
    if let cached { return cached }
    #if canImport(FoundationNetworking)
      let result = await probe()
    #else
      let result = true
    #endif
    cached = result
    return result
  }

  private func probe() async -> Bool {
    guard let server = try? LoopbackWebSocketServer(handler: { _, _ in
      .accept(script: [.binary(Data([0x01])), .close(code: 1000)])
    }) else { return false }
    defer { server.stop() }
    let task = URLSession(configuration: .ephemeral).webSocketTask(with: server.webSocketURL("/probe"))
    task.resume()
    defer { task.cancel(with: .normalClosure, reason: nil) }
    do {
      _ = try await task.receive()
      return true
    } catch {
      return false
    }
  }
}
