import Foundation

// lexicon: 1, id: chat.bsky.convo.getConvoAvailability

public enum ChatBskyConvoGetConvoAvailability {
    public static let typeIdentifier = "chat.bsky.convo.getConvoAvailability"
    public struct Parameters: Parametrizable {
        public let members: [DID]

        public init(
            members: [DID]
        ) {
            self.members = members
        }
    }

    public struct Output: ATProtocolCodable {
        public let canChat: Bool

        public let convo: ChatBskyConvoDefs.ConvoView?

        /// Standard public initializer
        public init(
            canChat: Bool,

            convo: ChatBskyConvoDefs.ConvoView? = nil

        ) {
            self.canChat = canChat

            self.convo = convo
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            canChat = try container.decode(Bool.self, forKey: .canChat)

            convo = try container.decodeIfPresent(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(canChat, forKey: .canChat)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(convo, forKey: .convo)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let canChatValue = try canChat.toCBORValue()
            map = map.adding(key: "canChat", value: canChatValue)

            if let value = convo {
                // Encode optional property even if it's an empty array for CBOR
                let convoValue = try value.toCBORValue()
                map = map.adding(key: "convo", value: convoValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case canChat
            case convo
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getConvoAvailability

    /// Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getConvoAvailability(input: ChatBskyConvoGetConvoAvailability.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvoAvailability.Output?) {
        let endpoint = "chat.bsky.convo.getConvoAvailability"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getConvoAvailability")
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
                let decodedData = try decoder.decode(ChatBskyConvoGetConvoAvailability.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getConvoAvailability: \(error)")
                return (responseCode, nil)
            }
        } else {
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
