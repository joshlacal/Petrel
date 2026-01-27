import Foundation



// lexicon: 1, id: blue.catbird.mls.addReaction


public struct BlueCatbirdMlsAddReaction { 

    public static let typeIdentifier = "blue.catbird.mls.addReaction"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let messageId: String
            public let reaction: String

            // Standard public initializer
            public init(convoId: String, messageId: String, reaction: String) {
                self.convoId = convoId
                self.messageId = messageId
                self.reaction = reaction
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.messageId = try container.decode(String.self, forKey: .messageId)
                
                
                self.reaction = try container.decode(String.self, forKey: .reaction)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(messageId, forKey: .messageId)
                
                
                try container.encode(reaction, forKey: .reaction)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case messageId
                case reaction
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let messageIdValue = try messageId.toCBORValue()
                map = map.adding(key: "messageId", value: messageIdValue)
                
                
                
                let reactionValue = try reaction.toCBORValue()
                map = map.adding(key: "reaction", value: reactionValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let reactedAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            reactedAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.success = success
            
            self.reactedAt = reactedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.reactedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .reactedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reactedAt, forKey: .reactedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            
            
            if let value = reactedAt {
                // Encode optional property even if it's an empty array for CBOR
                let reactedAtValue = try value.toCBORValue()
                map = map.adding(key: "reactedAt", value: reactedAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case reactedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notFound = "NotFound.Message or conversation not found"
                case notMember = "NotMember.User is not a member of the conversation"
                case alreadyReacted = "AlreadyReacted.User has already added this reaction to the message"
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

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - addReaction

    /// Add a reaction (emoji) to a message in an MLS conversation
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func addReaction(
        
        input: BlueCatbirdMlsAddReaction.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsAddReaction.Output?) {
        let endpoint = "blue.catbird.mls.addReaction"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.addReaction")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsAddReaction.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.addReaction: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

