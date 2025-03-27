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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case message
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = convoId as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = message as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = convoId as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    convoId = updatedValue
                }
            }

            if let loadable = message as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? ChatBskyConvoDefs.MessageInput {
                    message = updatedValue
                }
            }
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

        private enum CodingKeys: String, CodingKey {
            case items
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Convo {
    ///
    func sendMessageBatch(
        input: ChatBskyConvoSendMessageBatch.Input

    ) async throws -> (responseCode: Int, data: ChatBskyConvoSendMessageBatch.Output?) {
        let endpoint = "chat.bsky.convo.sendMessageBatch"

        var headers: [String: String] = [:]

        headers["Content-Type"] = "application/json"

        headers["Accept"] = "application/json"

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ChatBskyConvoSendMessageBatch.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
