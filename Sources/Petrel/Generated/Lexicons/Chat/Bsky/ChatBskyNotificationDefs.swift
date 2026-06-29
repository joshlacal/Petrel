import Foundation

// lexicon: 1, id: chat.bsky.notification.defs

public enum ChatBskyNotificationDefs {
    public static let typeIdentifier = "chat.bsky.notification.defs"

    public struct Preferences: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.notification.defs#preferences"
        public let chat: ChatPreference
        public let chatRequest: ChatPreference

        public init(
            chat: ChatPreference, chatRequest: ChatPreference
        ) {
            self.chat = chat
            self.chatRequest = chatRequest
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                chat = try container.decode(ChatPreference.self, forKey: .chat)
            } catch {
                LogManager.logError("Decoding error for required property 'chat': \(error)")
                throw error
            }
            do {
                chatRequest = try container.decode(ChatPreference.self, forKey: .chatRequest)
            } catch {
                LogManager.logError("Decoding error for required property 'chatRequest': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(chat, forKey: .chat)
            try container.encode(chatRequest, forKey: .chatRequest)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(chat)
            hasher.combine(chatRequest)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if chat != other.chat {
                return false
            }
            if chatRequest != other.chatRequest {
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
            let chatValue = try chat.toCBORValue()
            map = map.adding(key: "chat", value: chatValue)
            let chatRequestValue = try chatRequest.toCBORValue()
            map = map.adding(key: "chatRequest", value: chatRequestValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case chat
            case chatRequest
        }
    }

    public struct ChatPreference: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "chat.bsky.notification.defs#chatPreference"
        public let include: String
        public let push: Bool

        public init(
            include: String, push: Bool
        ) {
            self.include = include
            self.push = push
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                include = try container.decode(String.self, forKey: .include)
            } catch {
                LogManager.logError("Decoding error for required property 'include': \(error)")
                throw error
            }
            do {
                push = try container.decode(Bool.self, forKey: .push)
            } catch {
                LogManager.logError("Decoding error for required property 'push': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(include, forKey: .include)
            try container.encode(push, forKey: .push)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(include)
            hasher.combine(push)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if include != other.include {
                return false
            }
            if push != other.push {
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
            let includeValue = try include.toCBORValue()
            map = map.adding(key: "include", value: includeValue)
            let pushValue = try push.toCBORValue()
            map = map.adding(key: "push", value: pushValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case include
            case push
        }
    }
}
