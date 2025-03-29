import Foundation



// lexicon: 1, id: com.atproto.admin.sendEmail


public struct ComAtprotoAdminSendEmail { 

    public static let typeIdentifier = "com.atproto.admin.sendEmail"
public struct Input: ATProtocolCodable {
            public let recipientDid: DID
            public let content: String
            public let subject: String?
            public let senderDid: DID
            public let comment: String?

            // Standard public initializer
            public init(recipientDid: DID, content: String, subject: String? = nil, senderDid: DID, comment: String? = nil) {
                self.recipientDid = recipientDid
                self.content = content
                self.subject = subject
                self.senderDid = senderDid
                self.comment = comment
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.recipientDid = try container.decode(DID.self, forKey: .recipientDid)
                
                
                self.content = try container.decode(String.self, forKey: .content)
                
                
                self.subject = try container.decodeIfPresent(String.self, forKey: .subject)
                
                
                self.senderDid = try container.decode(DID.self, forKey: .senderDid)
                
                
                self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(recipientDid, forKey: .recipientDid)
                
                
                try container.encode(content, forKey: .content)
                
                
                if let value = subject {
                    
                    try container.encode(value, forKey: .subject)
                    
                }
                
                
                try container.encode(senderDid, forKey: .senderDid)
                
                
                if let value = comment {
                    
                    try container.encode(value, forKey: .comment)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case recipientDid
                case content
                case subject
                case senderDid
                case comment
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let recipientDidValue = try (recipientDid as? DAGCBOREncodable)?.toCBORValue() ?? recipientDid
                map = map.adding(key: "recipientDid", value: recipientDidValue)
                
                
                
                
                let contentValue = try (content as? DAGCBOREncodable)?.toCBORValue() ?? content
                map = map.adding(key: "content", value: contentValue)
                
                
                
                if let value = subject {
                    
                    
                    let subjectValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "subject", value: subjectValue)
                    
                }
                
                
                
                
                let senderDidValue = try (senderDid as? DAGCBOREncodable)?.toCBORValue() ?? senderDid
                map = map.adding(key: "senderDid", value: senderDidValue)
                
                
                
                if let value = comment {
                    
                    
                    let commentValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "comment", value: commentValue)
                    
                }
                
                
                
                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let sent: Bool
        
        
        
        // Standard public initializer
        public init(
            
            sent: Bool
            
            
        ) {
            
            self.sent = sent
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.sent = try container.decode(Bool.self, forKey: .sent)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(sent, forKey: .sent)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let sentValue = try (sent as? DAGCBOREncodable)?.toCBORValue() ?? sent
            map = map.adding(key: "sent", value: sentValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case sent
            
        }
    }




}

extension ATProtoClient.Com.Atproto.Admin {
    /// Send email to a user's account email address.
    public func sendEmail(
        
        input: ComAtprotoAdminSendEmail.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoAdminSendEmail.Output?) {
        let endpoint = "com.atproto.admin.sendEmail"
        
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
        let decodedData = try? decoder.decode(ComAtprotoAdminSendEmail.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
