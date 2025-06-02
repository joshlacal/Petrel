import Foundation

// lexicon: 1, id: app.bsky.notification.registerPush

public enum AppBskyNotificationRegisterPush {
    public static let typeIdentifier = "app.bsky.notification.registerPush"
    public struct Input: ATProtocolCodable {
        public let serviceDid: DID
        public let token: String
        public let platform: String
        public let appId: String

        // Standard public initializer
        public init(serviceDid: DID, token: String, platform: String, appId: String) {
            self.serviceDid = serviceDid
            self.token = token
            self.platform = platform
            self.appId = appId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            serviceDid = try container.decode(DID.self, forKey: .serviceDid)

            token = try container.decode(String.self, forKey: .token)

            platform = try container.decode(String.self, forKey: .platform)

            appId = try container.decode(String.self, forKey: .appId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(serviceDid, forKey: .serviceDid)

            try container.encode(token, forKey: .token)

            try container.encode(platform, forKey: .platform)

            try container.encode(appId, forKey: .appId)
        }

        private enum CodingKeys: String, CodingKey {
            case serviceDid
            case token
            case platform
            case appId
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let serviceDidValue = try serviceDid.toCBORValue()
            map = map.adding(key: "serviceDid", value: serviceDidValue)

            let tokenValue = try token.toCBORValue()
            map = map.adding(key: "token", value: tokenValue)

            let platformValue = try platform.toCBORValue()
            map = map.adding(key: "platform", value: platformValue)

            let appIdValue = try appId.toCBORValue()
            map = map.adding(key: "appId", value: appIdValue)

            return map
        }
    }
}

public extension ATProtoClient.App.Bsky.Notification {
    // MARK: - registerPush

    /// Register to receive push notifications, via a specified service, for the requesting account. Requires auth.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func registerPush(
        input: AppBskyNotificationRegisterPush.Input

    ) async throws -> Int {
        let endpoint = "app.bsky.notification.registerPush"

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
