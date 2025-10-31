import Foundation



// lexicon: 1, id: app.bsky.feed.sendInteractions


public struct AppBskyFeedSendInteractions { 

    public static let typeIdentifier = "app.bsky.feed.sendInteractions"
public struct Input: ATProtocolCodable {
            public let interactions: [AppBskyFeedDefs.Interaction]

            // Standard public initializer
            public init(interactions: [AppBskyFeedDefs.Interaction]) {
                self.interactions = interactions
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.interactions = try container.decode([AppBskyFeedDefs.Interaction].self, forKey: .interactions)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(interactions, forKey: .interactions)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case interactions
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let interactionsValue = try interactions.toCBORValue()
                map = map.adding(key: "interactions", value: interactionsValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        // Empty output - no properties (response is {})
        
        
        // Standard public initializer
        public init(
            
        ) {
            
        }
        
        public init(from decoder: Decoder) throws {
            
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
            
        }

        public func toCBORValue() throws -> Any {
            
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
            
        }
        
        
    }




}

extension ATProtoClient.App.Bsky.Feed {
    // MARK: - sendInteractions

    /// Send information about interactions with feed items back to the feed generator that served them.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func sendInteractions(
        
        input: AppBskyFeedSendInteractions.Input
        
    ) async throws -> (responseCode: Int, data: AppBskyFeedSendInteractions.Output?) {
        let endpoint = "app.bsky.feed.sendInteractions"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.feed.sendInteractions")
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
                let decodedData = try decoder.decode(AppBskyFeedSendInteractions.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.feed.sendInteractions: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

