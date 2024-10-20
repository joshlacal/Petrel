import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.admin.disableAccountInvites


public struct ComAtprotoAdminDisableAccountInvites { 

    public static let typeIdentifier = "com.atproto.admin.disableAccountInvites"        
public struct Input: ATProtocolCodable {
            public let account: String
            public let note: String?

            // Standard public initializer
            public init(account: String, note: String? = nil) {
                self.account = account
                self.note = note
                
            }
        }



}

extension ATProtoClient.Com.Atproto.Admin {
    /// Disable an account from receiving new invite codes, but does not invalidate existing codes.
    public func disableAccountInvites(
        
        input: ComAtprotoAdminDisableAccountInvites.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.admin.disableAccountInvites"
        
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
                           
