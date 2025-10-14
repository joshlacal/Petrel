import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.graph.unmuteThread

public enum AppBskyGraphUnmuteThread {
    public static let typeIdentifier = "app.bsky.graph.unmuteThread"
    public struct Input: ATProtocolCodable {
        public let root: ATProtocolURI

        // Standard public initializer
        public init(root: ATProtocolURI) {
            self.root = root
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            root = try container.decode(ATProtocolURI.self, forKey: .root)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(root, forKey: .root)
        }

        private enum CodingKeys: String, CodingKey {
            case root
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let rootValue = try root.toCBORValue()
            map = map.adding(key: "root", value: rootValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - unmuteThread

    /// Unmutes the specified thread. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func unmuteThread(
        input: AppBskyGraphUnmuteThread.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteThread"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.unmuteThread")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        return responseCode
    }
}
