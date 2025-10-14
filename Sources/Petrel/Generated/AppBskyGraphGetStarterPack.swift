import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: app.bsky.graph.getStarterPack

public enum AppBskyGraphGetStarterPack {
    public static let typeIdentifier = "app.bsky.graph.getStarterPack"
    public struct Parameters: Parametrizable {
        public let starterPack: ATProtocolURI

        public init(
            starterPack: ATProtocolURI
        ) {
            self.starterPack = starterPack
        }
    }

    public struct Output: ATProtocolCodable {
        public let starterPack: AppBskyGraphDefs.StarterPackView

        // Standard public initializer
        public init(
            starterPack: AppBskyGraphDefs.StarterPackView

        ) {
            self.starterPack = starterPack
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            starterPack = try container.decode(AppBskyGraphDefs.StarterPackView.self, forKey: .starterPack)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(starterPack, forKey: .starterPack)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let starterPackValue = try starterPack.toCBORValue()
            map = map.adding(key: "starterPack", value: starterPackValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case starterPack
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getStarterPack

    /// Gets a view of a starter pack.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getStarterPack(input: AppBskyGraphGetStarterPack.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPack.Output?) {
        let endpoint = "app.bsky.graph.getStarterPack"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.getStarterPack")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200 ... 299).contains(responseCode) {
            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyGraphGetStarterPack.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getStarterPack: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
