import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import PetrelOAuthServer

/// An ``OAuthRemoteTransport`` that connects only to an address the fetcher
/// approved, built on SwiftNIO. Use it for client metadata and JWKS fetches.
///
/// `URLSession` resolves the host name again when it connects, so a host whose
/// DNS answers change between the fetcher's check and the connection (DNS
/// rebinding) can steer it to a private address. This transport never resolves
/// a name: it opens the TCP connection to a literal member of `approvedPeers`,
/// then verifies TLS for the URL's host name (SNI and certificate name check)
/// exactly as a name-based connection would. Redirects are never followed, the
/// body is bounded while it arrives, and the address connected to is reported
/// as ``OAuthRemoteHTTPResponse/connectedPeerAddress``.
///
/// Works the same on Apple platforms and Linux.
public struct PinnedNIOOAuthRemoteTransport: OAuthRemoteTransport {
  private let group: any EventLoopGroup
  private let tlsContext: NIOSSLContext
  private let userAgent: String

  /// Creates the transport.
  ///
  /// - Parameters:
  ///   - eventLoopGroup: the event loops connections run on.
  ///   - trustRoots: the certificate authorities trusted for TLS; the
  ///     platform's by default.
  ///   - userAgent: the `User-Agent` request header.
  /// - Throws: when the TLS context cannot be created.
  public init(
    eventLoopGroup: any EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
    trustRoots: NIOSSLTrustRoots = .default,
    userAgent: String = "PetrelOAuthServer"
  ) throws {
    var configuration = TLSConfiguration.makeClientConfiguration()
    configuration.trustRoots = trustRoots
    configuration.certificateVerification = .fullVerification
    self.group = eventLoopGroup
    self.tlsContext = try NIOSSLContext(configuration: configuration)
    self.userAgent = userAgent
  }

  /// Always true: every connection goes to a literal approved address.
  public var pinsConnectionsToApprovedPeers: Bool { true }

  /// Fetches `url` from the first member of `approvedPeers` that accepts a
  /// connection, in a stable order.
  public func get(
    url: URL,
    approvedPeers: Set<OAuthIPAddress>,
    timeout: TimeInterval,
    maximumBodyBytes: Int
  ) async throws -> OAuthRemoteHTTPResponse {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
      let host = components.host, !host.isEmpty
    else {
      throw OAuthServerError.unauthorized("OAuth remote URL is malformed")
    }
    let port = components.port ?? (scheme == "https" ? 443 : 80)
    let peers = approvedPeers.sorted { $0.description < $1.description }
    guard !peers.isEmpty else {
      throw OAuthServerError.unauthorized("OAuth remote fetch has no approved address")
    }
    var target = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
    if let query = components.percentEncodedQuery { target += "?" + query }
    let defaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
    let hostHeader = (host.contains(":") ? "[\(host)]" : host) + (defaultPort ? "" : ":\(port)")
    let deadline = NIODeadline.now() + .nanoseconds(Int64(timeout * 1_000_000_000))

    var lastError: (any Error)?
    for peer in peers {
      try Task.checkCancellation()
      let address: SocketAddress
      do {
        address = try SocketAddress(ipAddress: peer.description, port: port)
      } catch {
        lastError = error
        continue
      }
      // The collector is in the pipeline from the start, so it sees a TLS
      // handshake failure, which can happen before the request is written.
      let loop = group.next()
      let promise = loop.makePromise(of: Received.self)
      let channel: any Channel
      do {
        channel = try await connect(
          to: address, host: scheme == "https" ? host : nil, on: loop,
          promise: promise, maximumBodyBytes: maximumBodyBytes,
          deadline: deadline
        )
      } catch {
        promise.fail(error)
        lastError = error
        continue
      }
      let response = try await exchange(
        on: channel, promise: promise, target: target, hostHeader: hostHeader, deadline: deadline
      )
      return OAuthRemoteHTTPResponse(
        status: response.status, headers: response.headers, body: response.body,
        responseURL: url, redirectCount: 0, connectedPeerAddress: peer
      )
    }
    if lastError is CancellationError { throw CancellationError() }
    throw OAuthServerError.unavailable("OAuth remote host could not be reached")
  }

  private func connect(
    to address: SocketAddress,
    host: String?,
    on loop: any EventLoop,
    promise: EventLoopPromise<Received>,
    maximumBodyBytes: Int,
    deadline: NIODeadline
  ) async throws -> any Channel {
    let tlsContext = tlsContext
    let remaining = deadline - .now()
    guard remaining > .zero else { throw OAuthServerError.unavailable("OAuth remote fetch timed out") }
    return try await ClientBootstrap(group: loop)
      .connectTimeout(remaining)
      .channelInitializer { channel in
        channel.eventLoop.makeCompletedFuture {
          if let host {
            // SNI and the certificate name check both use the URL's host,
            // not the address connected to.
            let handler = try NIOSSLClientHandler(context: tlsContext, serverHostname: host)
            try channel.pipeline.syncOperations.addHandler(handler)
          }
          try channel.pipeline.syncOperations.addHTTPClientHandlers()
          try channel.pipeline.syncOperations.addHandler(
            ResponseCollector(promise: promise, maximumBodyBytes: maximumBodyBytes)
          )
        }
      }
      .connect(to: address)
      .get()
  }

  private struct Received: Sendable {
    var status: Int
    var headers: [String: [String]]
    var body: Data
  }

  private func exchange(
    on channel: any Channel,
    promise: EventLoopPromise<Received>,
    target: String,
    hostHeader: String,
    deadline: NIODeadline
  ) async throws -> Received {
    let timeout = channel.eventLoop.scheduleTask(deadline: deadline) {
      promise.fail(OAuthServerError.unavailable("OAuth remote fetch timed out"))
    }
    promise.futureResult.whenComplete { _ in
      timeout.cancel()
      channel.close(promise: nil)
    }
    let userAgent = userAgent
    return try await withTaskCancellationHandler {
      try await channel.eventLoop.flatSubmit {
        var head = HTTPRequestHead(version: .http1_1, method: .GET, uri: target)
        head.headers.add(name: "Host", value: hostHeader)
        head.headers.add(name: "Accept", value: "application/json")
        head.headers.add(name: "User-Agent", value: userAgent)
        head.headers.add(name: "Connection", value: "close")
        channel.write(HTTPClientRequestPart.head(head), promise: nil)
        channel.writeAndFlush(HTTPClientRequestPart.end(nil)).whenFailure { promise.fail($0) }
        return promise.futureResult
      }.get()
    } onCancel: {
      promise.fail(CancellationError())
    }
  }

  /// Collects one response, refusing a body over the limit as it arrives.
  private final class ResponseCollector: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPClientResponsePart

    private let promise: EventLoopPromise<Received>
    private let maximumBodyBytes: Int
    private var received: Received?

    init(promise: EventLoopPromise<Received>, maximumBodyBytes: Int) {
      self.promise = promise
      self.maximumBodyBytes = maximumBodyBytes
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      switch unwrapInboundIn(data) {
      case let .head(head):
        var headers: [String: [String]] = [:]
        for (name, value) in head.headers {
          headers[name.lowercased(), default: []].append(value)
        }
        received = Received(status: Int(head.status.code), headers: headers, body: Data())
      case var .body(buffer):
        guard received != nil else { return }
        guard received!.body.count + buffer.readableBytes <= maximumBodyBytes else {
          promise.fail(OAuthServerError.unauthorized("OAuth remote document body is out of bounds"))
          context.close(promise: nil)
          return
        }
        if let bytes = buffer.readBytes(length: buffer.readableBytes) {
          received!.body.append(contentsOf: bytes)
        }
      case .end:
        if let received {
          promise.succeed(received)
        } else {
          promise.fail(OAuthServerError.unavailable("OAuth remote response was incomplete"))
        }
      }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
      promise.fail(error)
      context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
      promise.fail(OAuthServerError.unavailable("OAuth remote connection closed early"))
      context.fireChannelInactive()
    }
  }
}
