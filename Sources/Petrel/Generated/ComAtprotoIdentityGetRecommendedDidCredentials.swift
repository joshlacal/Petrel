import Foundation



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
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.rotationKeys = try container.decodeIfPresent([String].self, forKey: .rotationKeys)
            
            
            self.alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs)
            
            
            self.verificationMethods = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .verificationMethods)
            
            
            self.services = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .services)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rotationKeys, forKey: .rotationKeys)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(alsoKnownAs, forKey: .alsoKnownAs)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verificationMethods, forKey: .verificationMethods)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(services, forKey: .services)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = rotationKeys {
                // Encode optional property even if it's an empty array for CBOR
                let rotationKeysValue = try value.toCBORValue()
                map = map.adding(key: "rotationKeys", value: rotationKeysValue)
            }
            
            
            
            if let value = alsoKnownAs {
                // Encode optional property even if it's an empty array for CBOR
                let alsoKnownAsValue = try value.toCBORValue()
                map = map.adding(key: "alsoKnownAs", value: alsoKnownAsValue)
            }
            
            
            
            if let value = verificationMethods {
                // Encode optional property even if it's an empty array for CBOR
                let verificationMethodsValue = try value.toCBORValue()
                map = map.adding(key: "verificationMethods", value: verificationMethodsValue)
            }
            
            
            
            if let value = services {
                // Encode optional property even if it's an empty array for CBOR
                let servicesValue = try value.toCBORValue()
                map = map.adding(key: "services", value: servicesValue)
            }
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case rotationKeys
            case alsoKnownAs
            case verificationMethods
            case services
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - getRecommendedDidCredentials

    /// Describe the credentials that should be included in the DID doc of an account that is migrating to this service.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRecommendedDidCredentials() async throws -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?) {
        let endpoint = "com.atproto.identity.getRecommendedDidCredentials"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoIdentityGetRecommendedDidCredentials.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
