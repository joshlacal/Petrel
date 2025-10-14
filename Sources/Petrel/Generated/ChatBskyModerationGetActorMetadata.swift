import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
                LogManager.logError("Decoding error for required property 'messagesSent': \(error)")

                throw error
            }
            do {
                messagesReceived = try container.decode(Int.self, forKey: .messagesReceived)

            } catch {
                LogManager.logError("Decoding error for required property 'messagesReceived': \(error)")

                throw error
            }
            do {
                convos = try container.decode(Int.self, forKey: .convos)

            } catch {
                LogManager.logError("Decoding error for required property 'convos': \(error)")

                throw error
            }
            do {
                convosStarted = try container.decode(Int.self, forKey: .convosStarted)

            } catch {
                LogManager.logError("Decoding error for required property 'convosStarted': \(error)")

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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            let messagesSentValue = try messagesSent.toCBORValue()
            map = map.adding(key: "messagesSent", value: messagesSentValue)

            let messagesReceivedValue = try messagesReceived.toCBORValue()
            map = map.adding(key: "messagesReceived", value: messagesReceivedValue)

            let convosValue = try convos.toCBORValue()
            map = map.adding(key: "convos", value: convosValue)

            let convosStartedValue = try convosStarted.toCBORValue()
            map = map.adding(key: "convosStarted", value: convosStartedValue)

            return map
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
        public let actor: DID

        public init(
            actor: DID
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            day = try container.decode(Metadata.self, forKey: .day)

            month = try container.decode(Metadata.self, forKey: .month)

            all = try container.decode(Metadata.self, forKey: .all)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(day, forKey: .day)

            try container.encode(month, forKey: .month)

            try container.encode(all, forKey: .all)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let dayValue = try day.toCBORValue()
            map = map.adding(key: "day", value: dayValue)

            let monthValue = try month.toCBORValue()
            map = map.adding(key: "month", value: monthValue)

            let allValue = try all.toCBORValue()
            map = map.adding(key: "all", value: allValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case day
            case month
            case all
        }
    }
}

public extension ATProtoClient.Chat.Bsky.Moderation {
    // MARK: - getActorMetadata

    ///
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func getActorMetadata(input: ChatBskyModerationGetActorMetadata.Parameters) async throws -> (responseCode: Int, data: ChatBskyModerationGetActorMetadata.Output?) {
        let endpoint = "chat.bsky.moderation.getActorMetadata"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.moderation.getActorMetadata")
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
                let decodedData = try decoder.decode(ChatBskyModerationGetActorMetadata.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.moderation.getActorMetadata: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
