import Foundation



// lexicon: 1, id: app.bsky.unspecced.getSuggestedUsers


public struct AppBskyUnspeccedGetSuggestedUsers { 

    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedUsers"    
public struct Parameters: Parametrizable {
        public let category: String?
        public let limit: Int?
        
        public init(
            category: String? = nil, 
            limit: Int? = nil
            ) {
            self.category = category
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let actors: [AppBskyActorDefs.ProfileView]
        
        
        
        // Standard public initializer
        public init(
            
            
            actors: [AppBskyActorDefs.ProfileView]
            
            
        ) {
            
            
            self.actors = actors
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.actors = try container.decode([AppBskyActorDefs.ProfileView].self, forKey: .actors)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(actors, forKey: .actors)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let actorsValue = try actors.toCBORValue()
            map = map.adding(key: "actors", value: actorsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case actors
        }
        
    }




}



extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedUsers

    /// Get a list of suggested users
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSuggestedUsers(input: AppBskyUnspeccedGetSuggestedUsers.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedUsers.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedUsers"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getSuggestedUsers")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyUnspeccedGetSuggestedUsers.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getSuggestedUsers: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

