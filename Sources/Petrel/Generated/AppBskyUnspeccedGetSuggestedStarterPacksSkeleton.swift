import Foundation



// lexicon: 1, id: app.bsky.unspecced.getSuggestedStarterPacksSkeleton


public struct AppBskyUnspeccedGetSuggestedStarterPacksSkeleton { 

    public static let typeIdentifier = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"    
public struct Parameters: Parametrizable {
        public let viewer: DID?
        public let limit: Int?
        
        public init(
            viewer: DID? = nil, 
            limit: Int? = nil
            ) {
            self.viewer = viewer
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let starterPacks: [ATProtocolURI]
        
        
        
        // Standard public initializer
        public init(
            
            starterPacks: [ATProtocolURI]
            
            
        ) {
            
            self.starterPacks = starterPacks
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.starterPacks = try container.decode([ATProtocolURI].self, forKey: .starterPacks)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(starterPacks, forKey: .starterPacks)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let starterPacksValue = try starterPacks.toCBORValue()
            map = map.adding(key: "starterPacks", value: starterPacksValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case starterPacks
            
        }
    }




}


extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getSuggestedStarterPacksSkeleton

    /// Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSuggestedStarterPacksSkeleton(input: AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"

        
        let queryItems = input.asQueryItems()
        
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

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(AppBskyUnspeccedGetSuggestedStarterPacksSkeleton.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getSuggestedStarterPacksSkeleton: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
