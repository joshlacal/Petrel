import Foundation



// lexicon: 1, id: app.bsky.graph.getStarterPacks


public struct AppBskyGraphGetStarterPacks { 

    public static let typeIdentifier = "app.bsky.graph.getStarterPacks"    
public struct Parameters: Parametrizable {
        public let uris: [ATProtocolURI]
        
        public init(
            uris: [ATProtocolURI]
            ) {
            self.uris = uris
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]
        
        
        
        // Standard public initializer
        public init(
            
            
            starterPacks: [AppBskyGraphDefs.StarterPackViewBasic]
            
            
        ) {
            
            
            self.starterPacks = starterPacks
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.starterPacks = try container.decode([AppBskyGraphDefs.StarterPackViewBasic].self, forKey: .starterPacks)
            
            
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


extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getStarterPacks

    /// Get views for a list of starter packs.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getStarterPacks(input: AppBskyGraphGetStarterPacks.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetStarterPacks.Output?) {
        let endpoint = "app.bsky.graph.getStarterPacks"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.getStarterPacks")
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
                let decodedData = try decoder.decode(AppBskyGraphGetStarterPacks.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.graph.getStarterPacks: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
