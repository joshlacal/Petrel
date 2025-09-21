import Foundation

// lexicon: 1, id: app.bsky.notification.listActivitySubscriptions

public enum AppBskyNotificationListActivitySubscriptions {
    public static let typeIdentifier = "app.bsky.notification.listActivitySubscriptions"
    public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?

        public init(
            limit: Int? = nil,
            cursor: String? = nil
        ) {
            self.limit = limit
            self.cursor = cursor
        }
    }

    public struct Output: ATProtocolCodable {
        public let cursor: String?

        public let subscriptions: [AppBskyActorDefs.ProfileView]

        // Standard public initializer
        public init(
            cursor: String? = nil,

            subscriptions: [AppBskyActorDefs.ProfileView]

        ) {
            self.cursor = cursor

            self.subscriptions = subscriptions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            cursor = try container.decodeIfPresent(String.self, forKey: .cursor)

            subscriptions = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .subscriptions)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)

            try container.encode(subscriptions, forKey: .subscriptions)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }

            let subscriptionsValue = try subscriptions.toCBORValue()
            map = map.adding(key: "subscriptions", value: subscriptionsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case cursor
            case subscriptions
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    // MARK: - listActivitySubscriptions

    /// Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func listActivitySubscriptions(input: AppBskyNotificationListActivitySubscriptions.Parameters) async throws -> (responseCode: Int, data: AppBskyNotificationListActivitySubscriptions.Output?) {
        let endpoint = "app.bsky.notification.listActivitySubscriptions"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)

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
                let decodedData = try decoder.decode(AppBskyNotificationListActivitySubscriptions.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.notification.listActivitySubscriptions: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
