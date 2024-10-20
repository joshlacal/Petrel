import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.unspecced.searchPostsSkeleton


public struct AppBskyUnspeccedSearchPostsSkeleton { 

    public static let typeIdentifier = "app.bsky.unspecced.searchPostsSkeleton"    
public struct Parameters: Parametrizable {
        public let q: String
        public let sort: String?
        public let since: String?
        public let until: String?
        public let mentions: String?
        public let author: String?
        public let lang: LanguageCodeContainer?
        public let domain: String?
        public let url: URI?
        public let tag: [String]?
        public let viewer: String?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            q: String, 
            sort: String? = nil, 
            since: String? = nil, 
            until: String? = nil, 
            mentions: String? = nil, 
            author: String? = nil, 
            lang: LanguageCodeContainer? = nil, 
            domain: String? = nil, 
            url: URI? = nil, 
            tag: [String]? = nil, 
            viewer: String? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.q = q
            self.sort = sort
            self.since = since
            self.until = until
            self.mentions = mentions
            self.author = author
            self.lang = lang
            self.domain = domain
            self.url = url
            self.tag = tag
            self.viewer = viewer
            self.limit = limit
            self.cursor = cursor
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let hitsTotal: Int?
        
        public let posts: [AppBskyUnspeccedDefs.SkeletonSearchPost]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            hitsTotal: Int? = nil,
            
            posts: [AppBskyUnspeccedDefs.SkeletonSearchPost]
            
            
        ) {
            
            self.cursor = cursor
            
            self.hitsTotal = hitsTotal
            
            self.posts = posts
            
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case badQueryString = "BadQueryString."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.App.Bsky.Unspecced {
    /// Backend Posts search, returns only skeleton
    public func searchPostsSkeleton(input: AppBskyUnspeccedSearchPostsSkeleton.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedSearchPostsSkeleton.Output?) {
        let endpoint = "app.bsky.unspecced.searchPostsSkeleton"
        
        
        let queryItems = input.asQueryItems()
        
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
        let decodedData = try? decoder.decode(AppBskyUnspeccedSearchPostsSkeleton.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
