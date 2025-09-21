import Foundation



// lexicon: 1, id: com.atproto.temp.revokeAccountCredentials


public struct ComAtprotoTempRevokeAccountCredentials { 

    public static let typeIdentifier = "com.atproto.temp.revokeAccountCredentials"
public struct Input: ATProtocolCodable {
            public let account: ATIdentifier

            // Standard public initializer
            public init(account: ATIdentifier) {
                self.account = account
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.account = try container.decode(ATIdentifier.self, forKey: .account)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(account, forKey: .account)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case account
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let accountValue = try account.toCBORValue()
                map = map.adding(key: "account", value: accountValue)
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - revokeAccountCredentials

    /// Revoke sessions, password, and app passwords associated with account. May be resolved by a password reset.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func revokeAccountCredentials(
        
        input: ComAtprotoTempRevokeAccountCredentials.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.temp.revokeAccountCredentials"
        
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

        
        
        let (_, response) = try await networkService.performRequest(urlRequest)
        
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
