import Foundation

// lexicon: 1, id: chat.bsky.convo.sendMessageBatch

public enum ChatBskyConvoSendMessageBatch {
    public static let typeIdentifier = "chat.bsky.convo.sendMessageBatch"

    public struct BatchItem: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.convo.sendMessageBatch#batchItem"
        public let convoId: String
        public let message: ChatBskyConvoDefs.MessageInput

        public init(
            convoId: String, message: ChatBskyConvoDefs.MessageInput
        ) {
            self.convoId = convoId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                message = try container.decode(ChatBskyConvoDefs.MessageInput.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
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

        /// Standard public initializer
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

    public struct Output: ATProtocolCodable {
        public let items: [ChatBskyConvoDefs.MessageView]

        /// Standard public initializer
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

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.sendMessageBatch")
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
                let decodedData = try decoder.decode(ChatBskyConvoSendMessageBatch.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.sendMessageBatch: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
