import Foundation



// lexicon: 1, id: com.atproto.server.deleteAccount


public struct ComAtprotoServerDeleteAccount { 

    public static let typeIdentifier = "com.atproto.server.deleteAccount"
public struct Input: ATProtocolCodable {
            public let did: DID
            public let password: String
            public let token: String

            // Standard public initializer
            public init(did: DID, password: String, token: String) {
                self.did = did
                self.password = password
                self.token = token
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
                self.password = try container.decode(String.self, forKey: .password)
                
                
                self.token = try container.decode(String.self, forKey: .token)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(did, forKey: .did)
                
                
                try container.encode(password, forKey: .password)
                
                
                try container.encode(token, forKey: .token)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case did
                case password
                case token
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
                map = map.adding(key: "did", value: didValue)
                
                
                
                
                let passwordValue = try (password as? DAGCBOREncodable)?.toCBORValue() ?? password
                map = map.adding(key: "password", value: passwordValue)
                
                
                
                
                let tokenValue = try (token as? DAGCBOREncodable)?.toCBORValue() ?? token
                map = map.adding(key: "token", value: tokenValue)
                
                
                
                return map
            }
        }        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case expiredToken = "ExpiredToken."
                case invalidToken = "InvalidToken."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    /// Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.
    public func deleteAccount(
        
        input: ComAtprotoServerDeleteAccount.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.deleteAccount"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
