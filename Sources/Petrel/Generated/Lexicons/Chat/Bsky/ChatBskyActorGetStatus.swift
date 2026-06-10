import Foundation

// lexicon: 1, id: chat.bsky.actor.getStatus

public enum ChatBskyActorGetStatus {
    public static let typeIdentifier = "chat.bsky.actor.getStatus"

    public struct Output: ATProtocolCodable {
        public let chatDisabled: Bool

        public let canCreateGroups: Bool

        public let groupMemberLimit: Int

        /// Standard public initializer
        public init(
            chatDisabled: Bool,

            canCreateGroups: Bool,

            groupMemberLimit: Int

        ) {
            self.chatDisabled = chatDisabled

            self.canCreateGroups = canCreateGroups

            self.groupMemberLimit = groupMemberLimit
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            chatDisabled = try container.decode(Bool.self, forKey: .chatDisabled)

            canCreateGroups = try container.decode(Bool.self, forKey: .canCreateGroups)

            groupMemberLimit = try container.decode(Int.self, forKey: .groupMemberLimit)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(chatDisabled, forKey: .chatDisabled)

            try container.encode(canCreateGroups, forKey: .canCreateGroups)

            try container.encode(groupMemberLimit, forKey: .groupMemberLimit)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let chatDisabledValue = try chatDisabled.toCBORValue()
            map = map.adding(key: "chatDisabled", value: chatDisabledValue)

            let canCreateGroupsValue = try canCreateGroups.toCBORValue()
            map = map.adding(key: "canCreateGroups", value: canCreateGroupsValue)

            let groupMemberLimitValue = try groupMemberLimit.toCBORValue()
            map = map.adding(key: "groupMemberLimit", value: groupMemberLimitValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case chatDisabled
            case canCreateGroups
            case groupMemberLimit
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Actor {
    // MARK: - getStatus

    /// Get the authenticated viewer's chat status: whether their account is chat-disabled and whether their group-membership additions are restricted to accounts they follow.
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getStatus() async throws -> (responseCode: Int, data: ChatBskyActorGetStatus.Output?) {
        let endpoint = "chat.bsky.actor.getStatus"

        let queryItems: [URLQueryItem]? = nil

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.actor.getStatus")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyActorGetStatus.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.actor.getStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
