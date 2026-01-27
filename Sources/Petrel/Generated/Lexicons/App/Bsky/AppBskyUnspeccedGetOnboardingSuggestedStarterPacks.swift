import Foundation



// lexicon: 1, id: app.bsky.unspecced.getOnboardingSuggestedStarterPacks


public struct AppBskyUnspeccedGetOnboardingSuggestedStarterPacks { 

    public static let typeIdentifier = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        
        public init(
            limit: Int? = nil
            ) {
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let starterPacks: [AppBskyGraphDefs.StarterPackView]
        
        
        
        // Standard public initializer
        public init(
            
            
            starterPacks: [AppBskyGraphDefs.StarterPackView]
            
            
        ) {
            
            
            self.starterPacks = starterPacks
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.starterPacks = try container.decode([AppBskyGraphDefs.StarterPackView].self, forKey: .starterPacks)
            
            
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
    // MARK: - getOnboardingSuggestedStarterPacks

    /// Get a list of suggested starterpacks for onboarding
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getOnboardingSuggestedStarterPacks(input: AppBskyUnspeccedGetOnboardingSuggestedStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetOnboardingSuggestedStarterPacks.Output?) {
        let endpoint = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getOnboardingSuggestedStarterPacks")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetOnboardingSuggestedStarterPacks.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getOnboardingSuggestedStarterPacks: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

