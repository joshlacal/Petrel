#if DEBUG
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    @testable import Petrel
    import Synchronization
    import Testing

    /// `NetworkService.withCallOptions` promises its options for every XRPC request sent
    /// inside it. Generated subscriptions (`subscribeLabels`, `subscribeRepos`) open a
    /// WebSocket rather than an HTTP request, and used to ignore the scope entirely.
    @Suite("Scoped call options reach subscriptions")
    struct SubscriptionCallOptionsTests {
        static let labelerURL = URL(string: "https://labeler.example.com")!

        /// A WebSocket task that records nothing and ends at once.
        final class ClosedWebSocketTask: WebSocketTaskProtocol, @unchecked Sendable {
            func resume() {}
            func receive() async throws -> URLSessionWebSocketTask.Message {
                throw URLError(.networkConnectionLost)
            }

            func cancel(with _: URLSessionWebSocketTask.CloseCode, reason _: Data?) {}
        }

        /// Opens `subscribeLabels` inside `options` and returns the request the socket was
        /// opened with.
        private func openedRequest(
            options: XRPCCallOptions,
            configure: (NetworkService) async -> Void = { _ in }
        ) async throws -> URLRequest {
            let captured = Mutex<URLRequest?>(nil)
            return try await withSerializedStorageOverrideTest {
                NetworkService.dnsResolverOverride = { host in
                    ["pds.example.com", "labeler.example.com", "api.example.com"].contains(host) ? ["93.184.216.34"] : nil
                }
                NetworkService.webSocketTaskOverride = { request in
                    captured.withLock { $0 = request }
                    return ClosedWebSocketTask()
                }
                defer {
                    NetworkService.dnsResolverOverride = nil
                    NetworkService.webSocketTaskOverride = nil
                }

                let service = try NetworkService(baseURL: #require(URL(string: "https://pds.example.com")))
                await configure(service)
                let label = ATProtoClient.Com(networkService: service).atproto.label
                let stream = try await NetworkService.withCallOptions(options) {
                    try await label.subscribeLabels()
                }
                do {
                    for try await _ in stream {}
                } catch {}
                return try #require(captured.withLock { $0 })
            }
        }

        @Test("A scoped service is where the socket connects")
        func scopedServiceIsTheHost() async throws {
            let request = try await openedRequest(
                options: XRPCCallOptions(service: Self.labelerURL)
            )
            #expect(request.url?.absoluteString == "wss://labeler.example.com/xrpc/com.atproto.label.subscribeLabels")
        }

        @Test("Scoped headers and labelers are sent on the upgrade request")
        func scopedHeadersAreSent() async throws {
            let request = try await openedRequest(
                options: XRPCCallOptions(
                    headers: ["X-Widget-Trace": "trace-1"],
                    acceptLabelers: [XRPCLabeler(did: "did:plc:labeler", redact: true)]
                )
            )
            #expect(request.value(forHTTPHeaderField: "x-widget-trace") == "trace-1")
            #expect(request.value(forHTTPHeaderField: "atproto-accept-labelers") == "did:plc:labeler;redact")
        }

        @Test("A scoped proxy routes through the PDS instead of the client's default service")
        func scopedProxyRoutesThroughThePDS() async throws {
            let request = try await openedRequest(
                options: XRPCCallOptions(proxy: "did:web:mod.example.com#atproto_labeler"),
                configure: { await $0.setServiceDID("did:web:api.example.com#atproto_labeler", for: "com.atproto.label") }
            )
            #expect(request.url?.host == "pds.example.com")
            #expect(request.value(forHTTPHeaderField: "atproto-proxy") == "did:web:mod.example.com#atproto_labeler")
        }

        @Test("Without a scope the default routing is unchanged")
        func defaultRoutingIsUnchanged() async throws {
            let request = try await openedRequest(
                options: XRPCCallOptions(),
                configure: { await $0.setServiceDID("did:web:api.example.com#atproto_labeler", for: "com.atproto.label") }
            )
            #expect(request.url?.absoluteString == "wss://api.example.com/xrpc/com.atproto.label.subscribeLabels")
            #expect(request.value(forHTTPHeaderField: "atproto-proxy") == nil)
        }
    }
#endif
