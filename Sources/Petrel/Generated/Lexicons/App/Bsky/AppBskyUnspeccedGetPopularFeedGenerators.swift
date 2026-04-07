import Foundation



// lexicon: 1, id: app.bsky.unspecced.getPopularFeedGenerators


public struct AppBskyUnspeccedGetPopularFeedGenerators { 

    public static let typeIdentifier = "app.bsky.unspecced.getPopularFeedGenerators"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        public let query: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil, 
            query: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            self.query = query
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let feeds: [AppBskyFeedDefs.GeneratorView]
        
        
        
        // Standard public initializer
        public init(
            
            
            cursor: String? = nil,
            
            feeds: [AppBskyFeedDefs.GeneratorView]
            
            
        ) {
            
            
            self.cursor = cursor
            
            self.feeds = feeds
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.feeds = try container.decode([AppBskyFeedDefs.GeneratorView].self, forKey: .feeds)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(feeds, forKey: .feeds)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let feedsValue = try feeds.toCBORValue()
            map = map.adding(key: "feeds", value: feedsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cursor
            case feeds
        }
        
    }




}



extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getPopularFeedGenerators

    /// An unspecced view of globally popular feed generators.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPopularFeedGenerators(input: AppBskyUnspeccedGetPopularFeedGenerators.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPopularFeedGenerators.Output?) {
        let endpoint = "app.bsky.unspecced.getPopularFeedGenerators"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.unspecced.getPopularFeedGenerators")
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
                let decodedData = try decoder.decode(AppBskyUnspeccedGetPopularFeedGenerators.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.unspecced.getPopularFeedGenerators: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

