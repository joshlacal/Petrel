import Foundation



// lexicon: 1, id: com.atproto.server.getSession


public struct ComAtprotoServerGetSession { 

    public static let typeIdentifier = "com.atproto.server.getSession"
    
public struct Output: ATProtocolCodable {
        
        
        public let handle: String
        
        public let did: String
        
        public let email: String?
        
        public let emailConfirmed: Bool?
        
        public let emailAuthFactor: Bool?
        
        public let didDoc: DIDDocument?
        
        public let active: Bool?
        
        public let status: String?
        
        
        
        // Standard public initializer
        public init(
            
            handle: String,
            
            did: String,
            
            email: String? = nil,
            
            emailConfirmed: Bool? = nil,
            
            emailAuthFactor: Bool? = nil,
            
            didDoc: DIDDocument? = nil,
            
            active: Bool? = nil,
            
            status: String? = nil
            
            
        ) {
            
            self.handle = handle
            
            self.did = did
            
            self.email = email
            
            self.emailConfirmed = emailConfirmed
            
            self.emailAuthFactor = emailAuthFactor
            
            self.didDoc = didDoc
            
            self.active = active
            
            self.status = status
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.handle = try container.decode(String.self, forKey: .handle)
            
            
            self.did = try container.decode(String.self, forKey: .did)
            
            
            self.email = try container.decodeIfPresent(String.self, forKey: .email)
            
            
            self.emailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .emailConfirmed)
            
            
            self.emailAuthFactor = try container.decodeIfPresent(Bool.self, forKey: .emailAuthFactor)
            
            
            self.didDoc = try container.decodeIfPresent(DIDDocument.self, forKey: .didDoc)
            
            
            self.active = try container.decodeIfPresent(Bool.self, forKey: .active)
            
            
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(did, forKey: .did)
            
            
            if let value = email {
                
                try container.encode(value, forKey: .email)
                
            }
            
            
            if let value = emailConfirmed {
                
                try container.encode(value, forKey: .emailConfirmed)
                
            }
            
            
            if let value = emailAuthFactor {
                
                try container.encode(value, forKey: .emailAuthFactor)
                
            }
            
            
            if let value = didDoc {
                
                try container.encode(value, forKey: .didDoc)
                
            }
            
            
            if let value = active {
                
                try container.encode(value, forKey: .active)
                
            }
            
            
            if let value = status {
                
                try container.encode(value, forKey: .status)
                
            }
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case handle
            case did
            case email
            case emailConfirmed
            case emailAuthFactor
            case didDoc
            case active
            case status
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Server {
    /// Get information about the current auth session. Requires auth.
    public func getSession() async throws -> (responseCode: Int, data: ComAtprotoServerGetSession.Output?) {
        let endpoint = "com.atproto.server.getSession"
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        let decodedData = try? decoder.decode(ComAtprotoServerGetSession.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
