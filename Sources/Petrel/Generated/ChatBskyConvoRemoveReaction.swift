import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// lexicon: 1, id: chat.bsky.convo.removeReaction

public enum ChatBskyConvoRemoveReaction {
    public static let typeIdentifier = "chat.bsky.convo.removeReaction"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let messageId: String
        public let value: String

        // Standard public initializer
        public init(convoId: String, messageId: String, value: String) {
            self.convoId = convoId
            self.messageId = messageId
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            convoId = try container.decode(String.self, forKey: .convoId)

            messageId = try container.decode(String.self, forKey: .messageId)

            value = try container.decode(String.self, forKey: .value)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(messageId, forKey: .messageId)

            try container.encode(value, forKey: .value)
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case messageId
            case value
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)

            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let message: ChatBskyConvoDefs.MessageView

        // Standard public initializer
        public init(
            message: ChatBskyConvoDefs.MessageView

        ) {
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            message = try container.decode(ChatBskyConvoDefs.MessageView.self, forKey: .message)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(message, forKey: .message)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case message
        }
    }

    public enum Error: String, Swift.Error, CustomStringConvertible {
        case reactionMessageDeleted = "ReactionMessageDeleted.Indicates that the message has been deleted and reactions can no longer be added/removed."
        case reactionInvalidValue = "ReactionInvalidValue.Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji."
        public var description: String {
            return rawValue
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - removeReaction

    /// Removes an emoji reaction from a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in that reaction not being present, even if it already wasn't.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func removeReaction(
        input: ChatBskyConvoRemoveReaction.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoRemoveReaction.Output?) {
        let endpoint = "chat.bsky.convo.removeReaction"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.removeReaction")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
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
                let decodedData = try decoder.decode(ChatBskyConvoRemoveReaction.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.removeReaction: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
