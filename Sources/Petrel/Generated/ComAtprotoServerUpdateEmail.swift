import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.server.updateEmail


public struct ComAtprotoServerUpdateEmail { 

    public static let typeIdentifier = "com.atproto.server.updateEmail"        
public struct Input: ATProtocolCodable {
            public let email: String
            public let emailAuthFactor: Bool?
            public let token: String?

            // Standard public initializer
            public init(email: String, emailAuthFactor: Bool? = nil, token: String? = nil) {
                self.email = email
                self.emailAuthFactor = emailAuthFactor
                self.token = token
                
            }
        }        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case expiredToken = "ExpiredToken."
                case invalidToken = "InvalidToken."
                case tokenRequired = "TokenRequired."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Com.Atproto.Server {
    /// Update an account's email.
    public func updateEmail(
        
        input: ComAtprotoServerUpdateEmail.Input
        
    ) async throws -> Int {
        let endpoint = "com.atproto.server.updateEmail"
        
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
                           
