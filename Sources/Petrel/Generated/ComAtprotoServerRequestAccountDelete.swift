import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.server.requestAccountDelete


public struct ComAtprotoServerRequestAccountDelete { 

    public static let typeIdentifier = "com.atproto.server.requestAccountDelete"



}

extension ATProtoClient.Com.Atproto.Server {
    /// Initiate a user account deletion via email.
    public func requestAccountDelete(
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestAccountDelete"
        
        var headers: [String: String] = [:]
        
        
        
        
        let requestData: Data? = nil
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
                           
