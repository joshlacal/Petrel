import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.notification.updateSeen

public enum AppBskyNotificationUpdateSeen {
    public static let typeIdentifier = "app.bsky.notification.updateSeen"
    public struct Input: ATProtocolCodable {
        public let seenAt: ATProtocolDate

        // Standard public initializer
        public init(seenAt: ATProtocolDate) {
            self.seenAt = seenAt
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    /// Notify server that the requesting account has seen notifications. Requires auth.
    func updateSeen(
        input: AppBskyNotificationUpdateSeen.Input,

        duringInitialSetup: Bool = false
    ) async throws -> Int {
        let endpoint = "/app.bsky.notification.updateSeen"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: requestData,
            queryItems: nil
        )

        let (_, response) = try await networkManager.performRequest(urlRequest, retryCount: 0, duringInitialSetup: duringInitialSetup)
        let responseCode = response.statusCode

        return responseCode
    }
}
