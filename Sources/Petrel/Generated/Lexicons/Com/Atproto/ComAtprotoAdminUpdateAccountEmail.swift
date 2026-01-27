import Foundation



// lexicon: 1, id: com.atproto.admin.updateAccountEmail


public struct ComAtprotoAdminUpdateAccountEmail { 

    public static let typeIdentifier = "com.atproto.admin.updateAccountEmail"
public struct Input: ATProtocolCodable {
            public let account: ATIdentifier
            public let email: String

            // Standard public initializer
            public init(account: ATIdentifier, email: String) {
                self.account = account
                self.email = email
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.account = try container.decode(ATIdentifier.self, forKey: .account)
                
                
                self.email = try container.decode(String.self, forKey: .email)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(account, forKey: .account)
                
                
                try container.encode(email, forKey: .email)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case account
                case email
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let accountValue = try account.toCBORValue()
                map = map.adding(key: "account", value: accountValue)
                
                
                
                let emailValue = try email.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Admin {
    // MARK: - updateAccountEmail

    /// Administrative action to update an account's email.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateAccountEmail(
        
        input: ComAtprotoAdminUpdateAccountEmail.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.admin.updateAccountEmail"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.admin.updateAccountEmail")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

