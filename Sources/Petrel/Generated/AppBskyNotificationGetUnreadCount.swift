import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.notification.getUnreadCount

public enum AppBskyNotificationGetUnreadCount {
    public static let typeIdentifier = "app.bsky.notification.getUnreadCount"
    public struct Parameters: Parametrizable {
        public let priority: Bool?
        public let seenAt: ATProtocolDate?

        public init(
            priority: Bool? = nil,
            seenAt: ATProtocolDate? = nil
        ) {
            self.priority = priority
            self.seenAt = seenAt
        }
    }

    public struct Output: ATProtocolCodable {
        public let count: Int

        // Standard public initializer
        public init(
            count: Int

        ) {
            self.count = count
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Count the number of unread notifications for the requesting account. Requires auth.
    func getUnreadCount(input: AppBskyNotificationGetUnreadCount.Parameters) async throws -> (responseCode: Int, data: AppBskyNotificationGetUnreadCount.Output?) {
        let endpoint = "app.bsky.notification.getUnreadCount"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(AppBskyNotificationGetUnreadCount.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
