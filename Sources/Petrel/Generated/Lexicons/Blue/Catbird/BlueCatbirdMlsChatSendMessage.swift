import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.sendMessage


public struct BlueCatbirdMlsChatSendMessage { 

    public static let typeIdentifier = "blue.catbird.mlsChat.sendMessage"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let msgId: String
        public let ciphertext: Bytes
        public let epoch: Int
        public let paddedSize: Int
        public let delivery: String?
        public let action: String?
        public let reactionEmoji: String?
        public let targetMessageId: String?
        public let confirmationTag: Bytes?

        /// Standard public initializer
        public init(convoId: String, msgId: String, ciphertext: Bytes, epoch: Int, paddedSize: Int, delivery: String? = nil, action: String? = nil, reactionEmoji: String? = nil, targetMessageId: String? = nil, confirmationTag: Bytes? = nil) {
            self.convoId = convoId
            self.msgId = msgId
            self.ciphertext = ciphertext
            self.epoch = epoch
            self.paddedSize = paddedSize
            self.delivery = delivery
            self.action = action
            self.reactionEmoji = reactionEmoji
            self.targetMessageId = targetMessageId
            self.confirmationTag = confirmationTag
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.msgId = try container.decode(String.self, forKey: .msgId)
            self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            self.paddedSize = try container.decode(Int.self, forKey: .paddedSize)
            self.delivery = try container.decodeIfPresent(String.self, forKey: .delivery)
            self.action = try container.decodeIfPresent(String.self, forKey: .action)
            self.reactionEmoji = try container.decodeIfPresent(String.self, forKey: .reactionEmoji)
            self.targetMessageId = try container.decodeIfPresent(String.self, forKey: .targetMessageId)
            self.confirmationTag = try container.decodeIfPresent(Bytes.self, forKey: .confirmationTag)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(msgId, forKey: .msgId)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(paddedSize, forKey: .paddedSize)
            try container.encodeIfPresent(delivery, forKey: .delivery)
            try container.encodeIfPresent(action, forKey: .action)
            try container.encodeIfPresent(reactionEmoji, forKey: .reactionEmoji)
            try container.encodeIfPresent(targetMessageId, forKey: .targetMessageId)
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let msgIdValue = try msgId.toCBORValue()
            map = map.adding(key: "msgId", value: msgIdValue)
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
            if let value = action {
                let actionValue = try value.toCBORValue()
                map = map.adding(key: "action", value: actionValue)
            }
            if let value = reactionEmoji {
                let reactionEmojiValue = try value.toCBORValue()
                map = map.adding(key: "reactionEmoji", value: reactionEmojiValue)
            }
            if let value = targetMessageId {
                let targetMessageIdValue = try value.toCBORValue()
                map = map.adding(key: "targetMessageId", value: targetMessageIdValue)
            }
            if let value = confirmationTag {
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case msgId
            case ciphertext
            case epoch
            case paddedSize
            case delivery
            case action
            case reactionEmoji
            case targetMessageId
            case confirmationTag
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let messageId: String
        
        public let receivedAt: ATProtocolDate
        
        public let seq: Int
        
        public let epoch: Int
        
        
        
        // Standard public initializer
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
            
            self.messageId = try container.decode(String.self, forKey: .messageId)
            
            
            self.receivedAt = try container.decode(ATProtocolDate.self, forKey: .receivedAt)
            
            
            self.seq = try container.decode(Int.self, forKey: .seq)
            
            
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            
            
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
                case epochMismatch = "EpochMismatch.Message epoch does not match current conversation epoch"
                case messageTooLarge = "MessageTooLarge.Message exceeds maximum size policy"
                case invalidReaction = "InvalidReaction.Missing reactionEmoji or targetMessageId for reaction action"
                case invalidAsset = "InvalidAsset.Payload or attachment pointer is invalid"
                case treeStateDiverged = "TreeStateDiverged.Client MLS tree state does not match server canonical tree. Client must re-join via external commit."
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

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - sendMessage

    /// Send an encrypted message with optional reaction support (consolidates sendMessage + reaction sub-actions) Send an encrypted message to an MLS conversation. Supports application messages, reactions (add/remove), and ephemeral delivery. The msgId serves as the idempotency key.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func sendMessage(
        
        input: BlueCatbirdMlsChatSendMessage.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatSendMessage.Output?) {
        let endpoint = "blue.catbird.mlsChat.sendMessage"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.sendMessage")
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
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsChatSendMessage.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.sendMessage: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

