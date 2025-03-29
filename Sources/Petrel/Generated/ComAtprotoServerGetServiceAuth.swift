import Foundation



// lexicon: 1, id: com.atproto.server.getServiceAuth


public struct ComAtprotoServerGetServiceAuth { 

    public static let typeIdentifier = "com.atproto.server.getServiceAuth"    
public struct Parameters: Parametrizable {
        public let aud: DID
        public let exp: Int?
        public let lxm: NSID?
        
        public init(
            aud: DID, 
            exp: Int? = nil, 
            lxm: NSID? = nil
            ) {
            self.aud = aud
            self.exp = exp
            self.lxm = lxm
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let token: String
        
        
        
        // Standard public initializer
        public init(
            
            token: String
            
            
        ) {
            
            self.token = token
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.token = try container.decode(String.self, forKey: .token)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(token, forKey: .token)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let tokenValue = try (token as? DAGCBOREncodable)?.toCBORValue() ?? token
            map = map.adding(key: "token", value: tokenValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case token
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case badExpiration = "BadExpiration.Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Server {
    /// Get a signed token on behalf of the requesting DID for the requested service.
    public func getServiceAuth(input: ComAtprotoServerGetServiceAuth.Parameters) async throws -> (responseCode: Int, data: ComAtprotoServerGetServiceAuth.Output?) {
        let endpoint = "com.atproto.server.getServiceAuth"
        
        
        let queryItems = input.asQueryItems()
        
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
        let decodedData = try? decoder.decode(ComAtprotoServerGetServiceAuth.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
