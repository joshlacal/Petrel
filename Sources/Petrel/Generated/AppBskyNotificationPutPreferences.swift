import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.notification.putPreferences

public enum AppBskyNotificationPutPreferences {
    public static let typeIdentifier = "app.bsky.notification.putPreferences"
    public struct Input: ATProtocolCodable {
        public let priority: Bool

        // Standard public initializer
        public init(priority: Bool) {
            self.priority = priority
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
