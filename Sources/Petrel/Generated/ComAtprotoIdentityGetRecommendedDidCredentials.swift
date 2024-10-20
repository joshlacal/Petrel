import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.identity.getRecommendedDidCredentials


public struct ComAtprotoIdentityGetRecommendedDidCredentials { 

    public static let typeIdentifier = "com.atproto.identity.getRecommendedDidCredentials"    
    
public struct Output: ATProtocolCodable {
        
        
        public let rotationKeys: [String]?
        
        public let alsoKnownAs: [String]?
        
        public let verificationMethods: ATProtocolValueContainer?
        
        public let services: ATProtocolValueContainer?
        
        
        
        // Standard public initializer
        public init(
            
            rotationKeys: [String]? = nil,
            
            alsoKnownAs: [String]? = nil,
            
            verificationMethods: ATProtocolValueContainer? = nil,
            
            services: ATProtocolValueContainer? = nil
            
            
        ) {
            
            self.rotationKeys = rotationKeys
            
            self.alsoKnownAs = alsoKnownAs
            
            self.verificationMethods = verificationMethods
            
            self.services = services
            
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Identity {
    /// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
    public func getRecommendedDidCredentials() async throws -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        let endpoint = "com.atproto.identity.getRecommendedDidCredentials"
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }
        
        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityGetRecommendedDidCredentials.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
