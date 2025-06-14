import Foundation

// lexicon: 1, id: app.bsky.graph.muteThread

public enum AppBskyGraphMuteThread {
    public static let typeIdentifier = "app.bsky.graph.muteThread"
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
    // MARK: - muteThread

    /// Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func muteThread(
        input: AppBskyGraphMuteThread.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.muteThread"

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

        let (_, response) = try await networkService.performRequest(urlRequest)

        let responseCode = response.statusCode
        return responseCode
    }
}
