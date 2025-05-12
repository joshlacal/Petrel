import Foundation



// lexicon: 1, id: com.atproto.server.requestEmailUpdate


public struct ComAtprotoServerRequestEmailUpdate { 

    public static let typeIdentifier = "com.atproto.server.requestEmailUpdate"
    
public struct Output: ATProtocolCodable {
        
        
        public let tokenRequired: Bool
        
        
        
        // Standard public initializer
        public init(
            
            tokenRequired: Bool
            
            
        ) {
            
            self.tokenRequired = tokenRequired
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.tokenRequired = try container.decode(Bool.self, forKey: .tokenRequired)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(tokenRequired, forKey: .tokenRequired)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let tokenRequiredValue = try tokenRequired.toCBORValue()
            map = map.adding(key: "tokenRequired", value: tokenRequiredValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case tokenRequired
            
        }
    }




}

extension ATProtoClient.Com.Atproto.Server {
    // MARK: - requestEmailUpdate

    /// Request a token in order to update email.
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func requestEmailUpdate(
        
    ) async throws -> (responseCode: Int, data: ComAtprotoServerRequestEmailUpdate.Output?) {
        let endpoint = "com.atproto.server.requestEmailUpdate"
        
        var headers: [String: String] = [:]
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = nil
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
        let decodedData = try? decoder.decode(ComAtprotoServerRequestEmailUpdate.Output.self, from: responseData)
        

        return (responseCode, decodedData)
        
    }
    
}
                           
