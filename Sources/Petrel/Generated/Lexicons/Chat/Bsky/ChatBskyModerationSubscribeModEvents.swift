import Foundation



// lexicon: 1, id: chat.bsky.moderation.subscribeModEvents


public struct ChatBskyModerationSubscribeModEvents { 

    public static let typeIdentifier = "chat.bsky.moderation.subscribeModEvents"
        
public struct EventConvoFirstMessage: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage"
            public let convoId: String
            public let createdAt: ATProtocolDate
            public let messageId: String?
            public let recipients: [DID]
            public let rev: String
            public let user: DID

        public init(
            convoId: String, createdAt: ATProtocolDate, messageId: String?, recipients: [DID], rev: String, user: DID
        ) {
            self.convoId = convoId
            self.createdAt = createdAt
            self.messageId = messageId
            self.recipients = recipients
            self.rev = rev
            self.user = user
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'messageId': \(error)")
                throw error
            }
            do {
                self.recipients = try container.decode([DID].self, forKey: .recipients)
            } catch {
                LogManager.logError("Decoding error for required property 'recipients': \(error)")
                throw error
            }
            do {
                self.rev = try container.decode(String.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
            do {
                self.user = try container.decode(DID.self, forKey: .user)
            } catch {
                LogManager.logError("Decoding error for required property 'user': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(messageId, forKey: .messageId)
            try container.encode(recipients, forKey: .recipients)
            try container.encode(rev, forKey: .rev)
            try container.encode(user, forKey: .user)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(createdAt)
            if let value = messageId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(recipients)
            hasher.combine(rev)
            hasher.combine(user)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if messageId != other.messageId {
                return false
            }
            if recipients != other.recipients {
                return false
            }
            if rev != other.rev {
                return false
            }
            if user != other.user {
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
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = messageId {
                let messageIdValue = try value.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
            }
            let recipientsValue = try recipients.toCBORValue()
            map = map.adding(key: "recipients", value: recipientsValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            let userValue = try user.toCBORValue()
            map = map.adding(key: "user", value: userValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case createdAt
            case messageId
            case recipients
            case rev
            case user
        }
    }    
public struct Parameters: Parametrizable {
        public let cursor: String?
        
        public init(
            cursor: String? = nil
            ) {
            self.cursor = cursor
            
        }
    }
public enum Message: Codable, Sendable {

    case eventConvoFirstMessage(EventConvoFirstMessage)


    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {

        case "chat.bsky.moderation.subscribeModEvents#eventConvoFirstMessage":
            let value = try EventConvoFirstMessage(from: decoder)
            self = .eventConvoFirstMessage(value)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {

        case .eventConvoFirstMessage(let value):
            try value.encode(to: encoder)

        }
    }
}        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case futureCursor = "FutureCursor."
                case consumerTooSlow = "ConsumerTooSlow.If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}


                           

/// Subscribe to stream of chat events targeted to moderation. Private endpoint.

extension ATProtoClient.Chat.Bsky.Moderation {
    
    public func subscribeModEvents(
        cursor: String? = nil
    ) async throws -> AsyncThrowingStream<ChatBskyModerationSubscribeModEvents.Message, Error> {
        let params = ChatBskyModerationSubscribeModEvents.Parameters(cursor: cursor)
        return try await self.networkService.subscribe(
            endpoint: "chat.bsky.moderation.subscribeModEvents",
            parameters: params
        )
    }

    /// Alternative signature accepting input struct
    public func subscribeModEvents(input: ChatBskyModerationSubscribeModEvents.Parameters) async throws -> AsyncThrowingStream<ChatBskyModerationSubscribeModEvents.Message, Error> {
        return try await self.networkService.subscribe(
            endpoint: "chat.bsky.moderation.subscribeModEvents",
            parameters: input
        )
    }
    
}
