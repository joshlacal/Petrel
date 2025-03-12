import Foundation

// lexicon: 1, id: chat.bsky.moderation.getActorMetadata

public enum ChatBskyModerationGetActorMetadata {
    public static let typeIdentifier = "chat.bsky.moderation.getActorMetadata"

    public struct Metadata: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.moderation.getActorMetadata#metadata"
        public let messagesSent: Int
        public let messagesReceived: Int
        public let convos: Int
        public let convosStarted: Int

        // Standard initializer
        public init(
            messagesSent: Int, messagesReceived: Int, convos: Int, convosStarted: Int
        ) {
            self.messagesSent = messagesSent
            self.messagesReceived = messagesReceived
            self.convos = convos
            self.convosStarted = convosStarted
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                messagesSent = try container.decode(Int.self, forKey: .messagesSent)

            } catch {
                LogManager.logError("Decoding error for property 'messagesSent': \(error)")
                throw error
            }
            do {
                messagesReceived = try container.decode(Int.self, forKey: .messagesReceived)

            } catch {
                LogManager.logError("Decoding error for property 'messagesReceived': \(error)")
                throw error
            }
            do {
                convos = try container.decode(Int.self, forKey: .convos)

            } catch {
                LogManager.logError("Decoding error for property 'convos': \(error)")
                throw error
            }
            do {
                convosStarted = try container.decode(Int.self, forKey: .convosStarted)

            } catch {
                LogManager.logError("Decoding error for property 'convosStarted': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(messagesSent, forKey: .messagesSent)

            try container.encode(messagesReceived, forKey: .messagesReceived)

            try container.encode(convos, forKey: .convos)

            try container.encode(convosStarted, forKey: .convosStarted)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(messagesSent)
            hasher.combine(messagesReceived)
            hasher.combine(convos)
            hasher.combine(convosStarted)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if messagesSent != other.messagesSent {
                return false
            }

            if messagesReceived != other.messagesReceived {
                return false
            }

            if convos != other.convos {
                return false
            }

            if convosStarted != other.convosStarted {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case messagesSent
            case messagesReceived
            case convos
            case convosStarted
        }
    }

    public struct Parameters: Parametrizable {
        public let actor: String

        public init(
            actor: String
        ) {
            self.actor = actor
        }
    }

    public struct Output: ATProtocolCodable {
        public let day: Metadata

        public let month: Metadata

        public let all: Metadata

        // Standard public initializer
        public init(
            day: Metadata,

            month: Metadata,

            all: Metadata

        ) {
            self.day = day

            self.month = month

            self.all = all
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Moderation {
    ///
    func getActorMetadata(input: ChatBskyModerationGetActorMetadata.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetActorMetadata.Output?) {
        let endpoint = "chat.bsky.moderation.getActorMetadata"

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
        let decodedData = try? decoder.decode(ChatBskyModerationGetActorMetadata.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
