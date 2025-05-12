import Foundation



// lexicon: 1, id: com.atproto.server.requestPasswordReset


public struct ComAtprotoServerRequestPasswordReset { 

    public static let typeIdentifier = "com.atproto.server.requestPasswordReset"
public struct Input: ATProtocolCodable {
            public let email: String

            // Standard public initializer
            public init(email: String) {
                self.email = email
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.email = try container.decode(String.self, forKey: .email)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(email, forKey: .email)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case email
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let emailValue = try email.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
                
                

                return map
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - requestPasswordReset

    /// Initiate a user account password reset via email.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func requestPasswordReset(
        
        input: ComAtprotoServerRequestPasswordReset.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.requestPasswordReset"
        
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
                           
