import Foundation

// lexicon: 1, id: app.bsky.graph.muteActorList

public enum AppBskyGraphMuteActorList {
    public static let typeIdentifier = "app.bsky.graph.muteActorList"
    public struct Input: ATProtocolCodable {
        public let list: ATProtocolURI

        // Standard public initializer
        public init(list: ATProtocolURI) {
            self.list = list
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            list = try container.decode(ATProtocolURI.self, forKey: .list)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(list, forKey: .list)
        }

        private enum CodingKeys: String, CodingKey {
            case list
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    // MARK: - muteActorList

    /// Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func muteActorList(
        input: AppBskyGraphMuteActorList.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.muteActorList"

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
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.muteActorList")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        return responseCode
    }
}
