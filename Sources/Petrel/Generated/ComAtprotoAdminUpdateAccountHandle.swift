import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.admin.updateAccountHandle


public struct ComAtprotoAdminUpdateAccountHandle { 

    public static let typeIdentifier = "com.atproto.admin.updateAccountHandle"        
public struct Input: ATProtocolCodable {
            public let did: String
            public let handle: String

            // Standard public initializer
            public init(did: String, handle: String) {
                self.did = did
                self.handle = handle
                
            }
        }



}

extension ATProtoClient.Com.Atproto.Admin {
    /// Administrative action to update an account's handle.
    public func updateAccountHandle(
        
        input: ComAtprotoAdminUpdateAccountHandle.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountHandle"
        
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
                           
