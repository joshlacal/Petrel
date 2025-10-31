import Foundation



// lexicon: 1, id: blue.catbird.mls.sendMessage


public struct BlueCatbirdMlsSendMessage { 

    public static let typeIdentifier = "blue.catbird.mls.sendMessage"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let ciphertext: Bytes
            public let epoch: Int
            public let senderDid: DID
            public let embedType: String?
            public let embedUri: URI?

            // Standard public initializer
            public init(convoId: String, ciphertext: Bytes, epoch: Int, senderDid: DID, embedType: String? = nil, embedUri: URI? = nil) {
                self.convoId = convoId
                self.ciphertext = ciphertext
                self.epoch = epoch
                self.senderDid = senderDid
                self.embedType = embedType
                self.embedUri = embedUri
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
                
                
                self.epoch = try container.decode(Int.self, forKey: .epoch)
                
                
                self.senderDid = try container.decode(DID.self, forKey: .senderDid)
                
                
                self.embedType = try container.decodeIfPresent(String.self, forKey: .embedType)
                
                
                self.embedUri = try container.decodeIfPresent(URI.self, forKey: .embedUri)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(ciphertext, forKey: .ciphertext)
                
                
                try container.encode(epoch, forKey: .epoch)
                
                
                try container.encode(senderDid, forKey: .senderDid)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(embedType, forKey: .embedType)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(embedUri, forKey: .embedUri)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case ciphertext
                case epoch
                case senderDid
                case embedType
                case embedUri
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let ciphertextValue = try ciphertext.toCBORValue()
                map = map.adding(key: "ciphertext", value: ciphertextValue)
                
                
                
                let epochValue = try epoch.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
                
                
                
                let senderDidValue = try senderDid.toCBORValue()
                map = map.adding(key: "senderDid", value: senderDidValue)
                
                
                
                if let value = embedType {
                    // Encode optional property even if it's an empty array for CBOR
                    let embedTypeValue = try value.toCBORValue()
                    map = map.adding(key: "embedType", value: embedTypeValue)
                }
                
                
                
                if let value = embedUri {
                    // Encode optional property even if it's an empty array for CBOR
                    let embedUriValue = try value.toCBORValue()
                    map = map.adding(key: "embedUri", value: embedUriValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let messageId: String
        
        public let receivedAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            messageId: String,
            
            receivedAt: ATProtocolDate
            
            
        ) {
            
            
            self.messageId = messageId
            
            self.receivedAt = receivedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.messageId = try container.decode(String.self, forKey: .messageId)
            
            
            self.receivedAt = try container.decode(ATProtocolDate.self, forKey: .receivedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(messageId, forKey: .messageId)
            
            
            try container.encode(receivedAt, forKey: .receivedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)
            
            
            
            let receivedAtValue = try receivedAt.toCBORValue()
            map = map.adding(key: "receivedAt", value: receivedAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case messageId
            case receivedAt
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case invalidAsset = "InvalidAsset.Payload or attachment pointer is invalid"
                case epochMismatch = "EpochMismatch.Message epoch does not match current conversation epoch"
                case messageTooLarge = "MessageTooLarge.Message exceeds maximum size policy"
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
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

