import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.admin.deleteAccount


public struct ComAtprotoAdminDeleteAccount { 

    public static let typeIdentifier = "com.atproto.admin.deleteAccount"        
public struct Input: ATProtocolCodable {
            public let did: String

            // Standard public initializer
            public init(did: String) {
                self.did = did
                
            }
        }



}

extension ATProtoClient.Com.Atproto.Admin {
    /// Delete a user account as an administrator.
    public func deleteAccount(
        
        input: ComAtprotoAdminDeleteAccount.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.admin.deleteAccount"
        
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
                           
