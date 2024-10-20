import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.server.revokeAppPassword


public struct ComAtprotoServerRevokeAppPassword { 

    public static let typeIdentifier = "com.atproto.server.revokeAppPassword"        
public struct Input: ATProtocolCodable {
            public let name: String

            // Standard public initializer
            public init(name: String) {
                self.name = name
                
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    /// Revoke an App Password by name.
    public func revokeAppPassword(
        
        input: ComAtprotoServerRevokeAppPassword.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.revokeAppPassword"
        
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
                           
