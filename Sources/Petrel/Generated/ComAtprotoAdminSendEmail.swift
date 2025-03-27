import Foundation



// lexicon: 1, id: com.atproto.admin.sendEmail


public struct ComAtprotoAdminSendEmail { 

    public static let typeIdentifier = "com.atproto.admin.sendEmail"
public struct Input: ATProtocolCodable {
            public let recipientDid: String
            public let content: String
            public let subject: String?
            public let senderDid: String
            public let comment: String?

            // Standard public initializer
            public init(recipientDid: String, content: String, subject: String? = nil, senderDid: String, comment: String? = nil) {
                self.recipientDid = recipientDid
                self.content = content
                self.subject = subject
                self.senderDid = senderDid
                self.comment = comment
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.recipientDid = try container.decode(String.self, forKey: .recipientDid)
                
                
                self.content = try container.decode(String.self, forKey: .content)
                
                
                self.subject = try container.decodeIfPresent(String.self, forKey: .subject)
                
                
                self.senderDid = try container.decode(String.self, forKey: .senderDid)
                
                
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
                           
