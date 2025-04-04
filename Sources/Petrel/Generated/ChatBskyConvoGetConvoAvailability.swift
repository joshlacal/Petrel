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

        // Standard public initializer
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

            let canChatValue = try (canChat as? DAGCBOREncodable)?.toCBORValue() ?? canChat
            map = map.adding(key: "canChat", value: canChatValue)

            if let value = convo {
                // Encode optional property even if it's an empty array for CBOR

                let convoValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
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
    /// Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
    func getConvoAvailability(input: ChatBskyConvoGetConvoAvailability.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvoAvailability.Output?) {
        let endpoint = "chat.bsky.convo.getConvoAvailability"

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

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoGetConvoAvailability.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
