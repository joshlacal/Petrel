import Foundation

// lexicon: 1, id: app.bsky.graph.unmuteActor

public enum AppBskyGraphUnmuteActor {
    public static let typeIdentifier = "app.bsky.graph.unmuteActor"
    public struct Input: ATProtocolCodable {
        public let actor: String

        // Standard public initializer
        public init(actor: String) {
            self.actor = actor
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            actor = try container.decode(String.self, forKey: .actor)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(actor, forKey: .actor)
        }

        private enum CodingKeys: String, CodingKey {
            case actor
        }
    }
}

public extension ATProtoClient.App.Bsky.Graph {
    /// Unmutes the specified account. Requires auth.
    func unmuteActor(
        input: AppBskyGraphUnmuteActor.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteActor"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
    }
}
