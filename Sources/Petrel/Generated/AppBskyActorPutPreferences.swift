import Foundation

// lexicon: 1, id: app.bsky.actor.putPreferences

public enum AppBskyActorPutPreferences {
    public static let typeIdentifier = "app.bsky.actor.putPreferences"
    public struct Input: ATProtocolCodable {
        public let preferences: AppBskyActorDefs.Preferences

        // Standard public initializer
        public init(preferences: AppBskyActorDefs.Preferences) {
            self.preferences = preferences
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            preferences = try container.decode(AppBskyActorDefs.Preferences.self, forKey: .preferences)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(preferences, forKey: .preferences)
        }

        private enum CodingKeys: String, CodingKey {
            case preferences
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let preferencesValue = try (preferences as? DAGCBOREncodable)?.toCBORValue() ?? preferences
            map = map.adding(key: "preferences", value: preferencesValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Actor {
    /// Set the private preferences attached to the account.
    func putPreferences(
        input: AppBskyActorPutPreferences.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.actor.putPreferences"

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
