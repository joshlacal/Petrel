import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.notification.registerPush

public enum AppBskyNotificationRegisterPush {
    public static let typeIdentifier = "app.bsky.notification.registerPush"
    public struct Input: ATProtocolCodable {
        public let serviceDid: String
        public let token: String
        public let platform: String
        public let appId: String

        // Standard public initializer
        public init(serviceDid: String, token: String, platform: String, appId: String) {
            self.serviceDid = serviceDid
            self.token = token
            self.platform = platform
            self.appId = appId
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
    func registerPush(
        input: AppBskyNotificationRegisterPush.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.notification.registerPush"

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
