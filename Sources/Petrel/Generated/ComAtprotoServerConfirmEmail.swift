import Foundation



// lexicon: 1, id: com.atproto.server.confirmEmail


public struct ComAtprotoServerConfirmEmail { 

    public static let typeIdentifier = "com.atproto.server.confirmEmail"
public struct Input: ATProtocolCodable {
            public let email: String
            public let token: String

            // Standard public initializer
            public init(email: String, token: String) {
                self.email = email
                self.token = token
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.email = try container.decode(String.self, forKey: .email)
                
                
                self.token = try container.decode(String.self, forKey: .token)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(email, forKey: .email)
                
                
                try container.encode(token, forKey: .token)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case email
                case token
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let emailValue = try email.toCBORValue()
                map = map.adding(key: "email", value: emailValue)
                
                
                
                let tokenValue = try token.toCBORValue()
                map = map.adding(key: "token", value: tokenValue)
                
                

                return map
            }
        }        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case accountNotFound = "AccountNotFound."
                case expiredToken = "ExpiredToken."
                case invalidToken = "InvalidToken."
                case invalidEmail = "InvalidEmail."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - confirmEmail

    /// Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func confirmEmail(
        
        input: ComAtprotoServerConfirmEmail.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.confirmEmail"
        
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
                           
