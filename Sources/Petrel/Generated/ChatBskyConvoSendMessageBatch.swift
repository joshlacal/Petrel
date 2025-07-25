import Foundation

// lexicon: 1, id: chat.bsky.convo.sendMessageBatch

public enum ChatBskyConvoSendMessageBatch {
    public static let typeIdentifier = "chat.bsky.convo.sendMessageBatch"

    public struct BatchItem: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.sendMessageBatch#batchItem"
        public let convoId: String
        public let message: ChatBskyConvoDefs.MessageInput

        // Standard initializer
        public init(
            convoId: String, message: ChatBskyConvoDefs.MessageInput
        ) {
            self.convoId = convoId
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                convoId = try container.decode(String.self, forKey: .convoId)

            } catch {
                LogManager.logError("Decoding error for property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(ChatBskyConvoDefs.MessageInput.self, forKey: .message)

            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(convoId, forKey: .convoId)

            try container.encode(message, forKey: .message)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(message)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if convoId != other.convoId {
                return false
            }

            if message != other.message {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)

            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case message
        }
    }

    public struct Input: ATProtocolCodable {
        public let items: [BatchItem]

        // Standard public initializer
        public init(items: [BatchItem]) {
            self.items = items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            items = try container.decode([BatchItem].self, forKey: .items)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(items, forKey: .items)
        }

        private enum CodingKeys: String, CodingKey {
            case items
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)

            return map
        }
    }

    public struct Output: ATProtocolCodable {
        public let items: [ChatBskyConvoDefs.MessageView]

        // Standard public initializer
        public init(
            items: [ChatBskyConvoDefs.MessageView]

        ) {
            self.items = items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            items = try container.decode([ChatBskyConvoDefs.MessageView].self, forKey: .items)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(items, forKey: .items)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case items
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - sendMessageBatch

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func sendMessageBatch(
        input: ChatBskyConvoSendMessageBatch.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoSendMessageBatch.Output?) {
        let endpoint = "chat.bsky.convo.sendMessageBatch"

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

        // Chat endpoint - use proxy header
        let proxyHeaders = ["atproto-proxy": "did:web:api.bsky.chat#bsky_chat"]
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)

        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ChatBskyConvoSendMessageBatch.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
