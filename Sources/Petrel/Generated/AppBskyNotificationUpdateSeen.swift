import Foundation

// lexicon: 1, id: app.bsky.notification.updateSeen

public enum AppBskyNotificationUpdateSeen {
    public static let typeIdentifier = "app.bsky.notification.updateSeen"
    public struct Input: ATProtocolCodable {
        public let seenAt: ATProtocolDate

        // Standard public initializer
        public init(seenAt: ATProtocolDate) {
            self.seenAt = seenAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            seenAt = try container.decode(ATProtocolDate.self, forKey: .seenAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(seenAt, forKey: .seenAt)
        }

        private enum CodingKeys: String, CodingKey {
            case seenAt
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let seenAtValue = try (seenAt as? DAGCBOREncodable)?.toCBORValue() ?? seenAt
            map = map.adding(key: "seenAt", value: seenAtValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Notify server that the requesting account has seen notifications. Requires auth.
    func updateSeen(
        input: AppBskyNotificationUpdateSeen.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.notification.updateSeen"

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
