import Foundation



// lexicon: 1, id: com.atproto.identity.refreshIdentity


public struct ComAtprotoIdentityRefreshIdentity { 

    public static let typeIdentifier = "com.atproto.identity.refreshIdentity"
public struct Input: ATProtocolCodable {
            public let identifier: String

            // Standard public initializer
            public init(identifier: String) {
                self.identifier = identifier
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.identifier = try container.decode(String.self, forKey: .identifier)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(identifier, forKey: .identifier)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case identifier
            }
        }
    public typealias Output = ComAtprotoIdentityDefs.IdentityInfo
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case handleNotFound = "HandleNotFound.The resolution process confirmed that the handle does not resolve to any DID."
                case didNotFound = "DidNotFound.The DID resolution process confirmed that there is no current DID."
                case didDeactivated = "DidDeactivated.The DID previously existed, but has been deactivated."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Identity {
    /// Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
    public func refreshIdentity(
        
        input: ComAtprotoIdentityRefreshIdentity.Input
        
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentityRefreshIdentity.Output?) {
        let endpoint = "com.atproto.identity.refreshIdentity"
        
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
        let decodedData = try? decoder.decode(ComAtprotoIdentityRefreshIdentity.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
