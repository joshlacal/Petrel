//
//  NetworkResponseLimitScopeTests.swift
//  PetrelTests
//

import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Answers every request on one loopback port with `body`. Only that port is
/// intercepted, so no other suite's requests reach this protocol.
private final class ResponseLimitScopeURLProtocol: URLProtocol {
    static let port = 47292
    private static let lock = NSLock()
    private nonisolated(unsafe) static var body = Data()

    static func setBody(_ data: Data) {
        lock.withLock { body = data }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "127.0.0.1" && request.url?.port == port
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = Self.lock.withLock { Self.body }
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/octet-stream"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private let loopbackBaseURL = URL(string: "http://127.0.0.1:\(ResponseLimitScopeURLProtocol.port)")!
private let raisedLimits = NetworkResponseLimits(
    maximumWireBytes: SpaceSTAR.defaultMaximumArchiveBytes,
    maximumDecodedBytes: SpaceSTAR.defaultMaximumArchiveBytes
)

private func isResponseLimitExceeded(_ error: Error) -> Bool {
    if case .responseLimitExceeded = error as? NetworkError {
        return true
    }
    return false
}

/// Builds the client while the mock is installed, as the session captures its
/// protocol classes at creation.
private func withLoopbackClient<T>(_ body: (ATProtoClient) async throws -> T) async throws -> T {
    try await withSerializedStorageOverrideTest {
        NetworkService.setNetworkTestProtocolClasses([ResponseLimitScopeURLProtocol.self])
        let client = await ATProtoClient(baseURL: loopbackBaseURL)
        NetworkService.setNetworkTestProtocolClasses(nil)
        defer { ResponseLimitScopeURLProtocol.setBody(Data()) }
        return try await body(client)
    }
}

@Suite("NetworkService response limit scopes", .serialized)
struct NetworkResponseLimitScopeTests {
    @Test("A generated call admits a response above 10 MiB only inside withResponseLimits")
    func generatedCallHonorsScopedLimits() async throws {
        try await withLoopbackClient { client in
            let large = Data(repeating: 0x5A, count: 11 * 1_048_576)
            #expect(large.count > NetworkResponseLimits.default.maximumWireBytes)
            ResponseLimitScopeURLProtocol.setBody(large)
            let input = try ComAtprotoSpaceGetBlob.Parameters(
                space: SpaceRef(uriString: "at://did:plc:owner/space/com.example.drive/self"),
                repo: DID(didString: "did:plc:owner"),
                cid: CID.fromDAGCBOR(Data("response-limit-scope".utf8))
            )

            do {
                _ = try await client.com.atproto.space.getBlob(input: input)
                Issue.record("Expected the default 10 MiB limit to refuse the blob")
            } catch {
                #expect(isResponseLimitExceeded(error), "unexpected error \(error)")
            }

            let (responseCode, output) = try await NetworkService.withResponseLimits(raisedLimits) {
                try await client.com.atproto.space.getBlob(input: input)
            }
            #expect(responseCode == 200)
            #expect(output?.data == large)

            let tooSmall = NetworkResponseLimits(maximumWireBytes: large.count - 1, maximumDecodedBytes: large.count - 1)
            do {
                _ = try await NetworkService.withResponseLimits(tooSmall) {
                    try await client.com.atproto.space.getBlob(input: input)
                }
                Issue.record("Expected a scoped limit below the blob size to refuse it")
            } catch {
                #expect(isResponseLimitExceeded(error), "unexpected error \(error)")
            }

            // The scope ends with the operation: the default limit applies again.
            do {
                _ = try await client.com.atproto.space.getBlob(input: input)
                Issue.record("Expected the default limit to apply again after the scope")
            } catch {
                #expect(isResponseLimitExceeded(error), "unexpected error \(error)")
            }
        }
    }

    @Test("Refresh-path and post-refresh retry requests honor the scope too")
    func otherRequestPathsHonorScopedLimits() async throws {
        try await withLoopbackClient { client in
            let large = Data(repeating: 0x33, count: 11 * 1_048_576)
            ResponseLimitScopeURLProtocol.setBody(large)
            let networkService = await client.networkService
            let request = URLRequest(url: loopbackBaseURL.appendingPathComponent("xrpc/com.example.large"))

            // performRequest(skipTokenRefresh: true) skips deduplication; request(_:)
            // is the path an auth provider uses to retry after a refresh.
            let paths: [(String, @Sendable () async throws -> Data)] = [
                ("skipTokenRefresh", { try await networkService.performRequest(request, skipTokenRefresh: true).0 }),
                ("retry", { try await networkService.request(request).0 }),
            ]
            for (name, send) in paths {
                do {
                    _ = try await send()
                    Issue.record("\(name): expected the default limit to refuse the response")
                } catch {
                    #expect(isResponseLimitExceeded(error), "\(name): unexpected error \(error)")
                }
                let data = try await NetworkService.withResponseLimits(raisedLimits) {
                    try await send()
                }
                #expect(data == large, "\(name)")
            }
        }
    }

    @Test("Scoped limits are clamped to 0...128 MiB, and nested scopes replace and restore them")
    func scopedLimitsAreClamped() async {
        let ceiling = SpaceSTAR.defaultMaximumArchiveBytes
        #expect(ceiling == 128 * 1_048_576)
        let huge = NetworkResponseLimits(
            maximumWireBytes: .max,
            maximumDecodedBytes: .max,
            maximumExpansionRatio: .max,
            maximumDiagnosticBytes: .max
        )
        let clamped = NetworkResponseLimits(
            maximumWireBytes: ceiling,
            maximumDecodedBytes: ceiling,
            maximumExpansionRatio: ceiling,
            maximumDiagnosticBytes: ceiling
        )
        #expect(NetworkService.clampedScopedResponseLimits(huge) == clamped)
        #expect(NetworkService.clampedScopedResponseLimits(.default) == .default)
        #expect(NetworkService.clampedScopedResponseLimits(NetworkResponseLimits(
            maximumWireBytes: -1,
            maximumDecodedBytes: -1,
            maximumExpansionRatio: -1,
            maximumDiagnosticBytes: -1
        )) == NetworkResponseLimits(
            maximumWireBytes: 0,
            maximumDecodedBytes: 0,
            maximumExpansionRatio: 0,
            maximumDiagnosticBytes: 0
        ))

        #expect(NetworkService.scopedResponseLimits == nil)
        await NetworkService.withResponseLimits(huge) {
            #expect(NetworkService.scopedResponseLimits == clamped)
            await NetworkService.withResponseLimits(.default) {
                #expect(NetworkService.scopedResponseLimits == .default)
            }
            #expect(NetworkService.scopedResponseLimits == clamped)
        }
        #expect(NetworkService.scopedResponseLimits == nil)
    }
}
