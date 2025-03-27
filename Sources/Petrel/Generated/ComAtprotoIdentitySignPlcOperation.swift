import Foundation



// lexicon: 1, id: com.atproto.identity.signPlcOperation


public struct ComAtprotoIdentitySignPlcOperation { 

    public static let typeIdentifier = "com.atproto.identity.signPlcOperation"
public struct Input: ATProtocolCodable {
            public let token: String?
            public let rotationKeys: [String]?
            public let alsoKnownAs: [String]?
            public let verificationMethods: ATProtocolValueContainer?
            public let services: ATProtocolValueContainer?

            // Standard public initializer
            public init(token: String? = nil, rotationKeys: [String]? = nil, alsoKnownAs: [String]? = nil, verificationMethods: ATProtocolValueContainer? = nil, services: ATProtocolValueContainer? = nil) {
                self.token = token
                self.rotationKeys = rotationKeys
                self.alsoKnownAs = alsoKnownAs
                self.verificationMethods = verificationMethods
                self.services = services
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.token = try container.decodeIfPresent(String.self, forKey: .token)
                
                
                self.rotationKeys = try container.decodeIfPresent([String].self, forKey: .rotationKeys)
                
                
                self.alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs)
                
                
                self.verificationMethods = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .verificationMethods)
                
                
                self.services = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .services)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                if let value = token {
                    
                    try container.encode(value, forKey: .token)
                    
                }
                
                
                if let value = rotationKeys {
                    
                    if !value.isEmpty {
                        try container.encode(value, forKey: .rotationKeys)
                    }
                    
                }
                
                
                if let value = alsoKnownAs {
                    
                    if !value.isEmpty {
                        try container.encode(value, forKey: .alsoKnownAs)
                    }
                    
                }
                
                
                if let value = verificationMethods {
                    
                    try container.encode(value, forKey: .verificationMethods)
                    
                }
                
                
                if let value = services {
                    
                    try container.encode(value, forKey: .services)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case token
                case rotationKeys
                case alsoKnownAs
                case verificationMethods
                case services
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let operation: ATProtocolValueContainer
        
        
        
        // Standard public initializer
        public init(
            
            operation: ATProtocolValueContainer
            
            
        ) {
            
            self.operation = operation
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.operation = try container.decode(ATProtocolValueContainer.self, forKey: .operation)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(operation, forKey: .operation)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case operation
            
        }
    }




}

extension ATProtoClient.Com.Atproto.Identity {
    /// Signs a PLC operation to update some value(s) in the requesting DID's document.
    public func signPlcOperation(
        
        input: ComAtprotoIdentitySignPlcOperation.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?) {
        let endpoint = "com.atproto.identity.signPlcOperation"
        
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
        let decodedData = try? decoder.decode(ComAtprotoIdentitySignPlcOperation.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
