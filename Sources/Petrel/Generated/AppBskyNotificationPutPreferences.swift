import Foundation

// lexicon: 1, id: app.bsky.notification.putPreferences

public enum AppBskyNotificationPutPreferences {
    public static let typeIdentifier = "app.bsky.notification.putPreferences"
    public struct Input: ATProtocolCodable {
        public let priority: Bool

        // Standard public initializer
        public init(priority: Bool) {
            self.priority = priority
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            priority = try container.decode(Bool.self, forKey: .priority)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(priority, forKey: .priority)
        }

        private enum CodingKeys: String, CodingKey {
            case priority
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let priorityValue = try (priority as? DAGCBOREncodable)?.toCBORValue() ?? priority
            map = map.adding(key: "priority", value: priorityValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Set notification-related preferences for an account. Requires auth.
    func putPreferences(
        input: AppBskyNotificationPutPreferences.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.notification.putPreferences"

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
