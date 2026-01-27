import Foundation

// lexicon: 1, id: blue.catbird.mls.sendMessage

public enum BlueCatbirdMlsSendMessage {
    public static let typeIdentifier = "blue.catbird.mls.sendMessage"
    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let msgId: String
        public let idempotencyKey: String?
        public let ciphertext: Bytes
        public let epoch: Int
        public let paddedSize: Int
        public let delivery: String?

        /// Standard public initializer
        public init(convoId: String, msgId: String, idempotencyKey: String? = nil, ciphertext: Bytes, epoch: Int, paddedSize: Int, delivery: String? = nil) {
            self.convoId = convoId
            self.msgId = msgId
            self.idempotencyKey = idempotencyKey
            self.ciphertext = ciphertext
            self.epoch = epoch
            self.paddedSize = paddedSize
            self.delivery = delivery
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            msgId = try container.decode(String.self, forKey: .msgId)
            idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
            epoch = try container.decode(Int.self, forKey: .epoch)
            paddedSize = try container.decode(Int.self, forKey: .paddedSize)
            delivery = try container.decodeIfPresent(String.self, forKey: .delivery)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(msgId, forKey: .msgId)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(paddedSize, forKey: .paddedSize)
            try container.encodeIfPresent(delivery, forKey: .delivery)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let msgIdValue = try msgId.toCBORValue()
            map = map.adding(key: "msgId", value: msgIdValue)
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let paddedSizeValue = try paddedSize.toCBORValue()
            map = map.adding(key: "paddedSize", value: paddedSizeValue)
            if let value = delivery {
                let deliveryValue = try value.toCBORValue()
                map = map.adding(key: "delivery", value: deliveryValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case msgId
            case idempotencyKey
            case ciphertext
            case epoch
            case paddedSize
            case delivery
        }
    }

    public struct Output: ATProtocolCodable {
        public let messageId: String

        public let receivedAt: ATProtocolDate

        public let seq: Int

        public let epoch: Int

        /// Standard public initializer
        public init(
            messageId: String,

            receivedAt: ATProtocolDate,

            seq: Int,

            epoch: Int

        ) {
            self.messageId = messageId

            self.receivedAt = receivedAt

            self.seq = seq

            self.epoch = epoch
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            messageId = try container.decode(String.self, forKey: .messageId)

            receivedAt = try container.decode(ATProtocolDate.self, forKey: .receivedAt)

            seq = try container.decode(Int.self, forKey: .seq)

            epoch = try container.decode(Int.self, forKey: .epoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(messageId, forKey: .messageId)

            try container.encode(receivedAt, forKey: .receivedAt)

            try container.encode(seq, forKey: .seq)

            try container.encode(epoch, forKey: .epoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)

            let receivedAtValue = try receivedAt.toCBORValue()
            map = map.adding(key: "receivedAt", value: receivedAtValue)

            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)

            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case messageId
            case receivedAt
            case seq
            case epoch
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of the conversation"
        case invalidAsset = "InvalidAsset.Payload or attachment pointer is invalid"
        case epochMismatch = "EpochMismatch.Message epoch does not match current conversation epoch"
        case messageTooLarge = "MessageTooLarge.Message exceeds maximum size policy"
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - sendMessage

    /// Send an encrypted message to an MLS conversation
    ///
    /// - Parameter input: The input parameters for the request
    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func sendMessage(
        input: BlueCatbirdMlsSendMessage.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsSendMessage.Output?) {
        let endpoint = "blue.catbird.mls.sendMessage"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.sendMessage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsSendMessage.Output.self, from: responseData)

                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.sendMessage: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}
