import Foundation



// lexicon: 1, id: blue.catbird.mls.sendMessage


public struct BlueCatbirdMlsSendMessage { 

    public static let typeIdentifier = "blue.catbird.mls.sendMessage"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let msgId: String
            public let idempotencyKey: String?
            public let ciphertext: Bytes
            public let epoch: Int
            public let paddedSize: Int

            // Standard public initializer
            public init(convoId: String, msgId: String, idempotencyKey: String? = nil, ciphertext: Bytes, epoch: Int, paddedSize: Int) {
                self.convoId = convoId
                self.msgId = msgId
                self.idempotencyKey = idempotencyKey
                self.ciphertext = ciphertext
                self.epoch = epoch
                self.paddedSize = paddedSize
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.msgId = try container.decode(String.self, forKey: .msgId)
                
                
                self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
                
                
                self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
                
                
                self.epoch = try container.decode(Int.self, forKey: .epoch)
                
                
                self.paddedSize = try container.decode(Int.self, forKey: .paddedSize)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(msgId, forKey: .msgId)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
                
                
                try container.encode(ciphertext, forKey: .ciphertext)
                
                
                try container.encode(epoch, forKey: .epoch)
                
                
                try container.encode(paddedSize, forKey: .paddedSize)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case msgId
                case idempotencyKey
                case ciphertext
                case epoch
                case paddedSize
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let msgIdValue = try msgId.toCBORValue()
                map = map.adding(key: "msgId", value: msgIdValue)
                
                
                
                if let value = idempotencyKey {
                    // Encode optional property even if it's an empty array for CBOR
                    let idempotencyKeyValue = try value.toCBORValue()
                    map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
                }
                
                
                
                let ciphertextValue = try ciphertext.toCBORValue()
                map = map.adding(key: "ciphertext", value: ciphertextValue)
                
                
                
                let epochValue = try epoch.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
                
                
                
                let paddedSizeValue = try paddedSize.toCBORValue()
                map = map.adding(key: "paddedSize", value: paddedSizeValue)
                
                

                return map
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
                /// Conversation not found
                case convoNotFound = "ConvoNotFound"
                /// Caller is not a member of the conversation
                case notMember = "NotMember"
                /// Payload or attachment pointer is invalid
                case invalidAsset = "InvalidAsset"
                /// Message epoch does not match current conversation epoch
                case epochMismatch = "EpochMismatch"
                /// Message exceeds maximum size policy
                case messageTooLarge = "MessageTooLarge"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - sendMessage

    /// Send an encrypted message to an MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func sendMessage(
        
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
        if (200...299).contains(responseCode) {
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
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsSendMessage.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

