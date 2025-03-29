import Foundation



// lexicon: 1, id: app.bsky.feed.searchPosts


public struct AppBskyFeedSearchPosts { 

    public static let typeIdentifier = "app.bsky.feed.searchPosts"    
public struct Parameters: Parametrizable {
        public let q: String
        public let sort: String?
        public let since: String?
        public let until: String?
        public let mentions: ATIdentifier?
        public let author: ATIdentifier?
        public let lang: LanguageCodeContainer?
        public let domain: String?
        public let url: URI?
        public let tag: [String]?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            q: String, 
            sort: String? = nil, 
            since: String? = nil, 
            until: String? = nil, 
            mentions: ATIdentifier? = nil, 
            author: ATIdentifier? = nil, 
            lang: LanguageCodeContainer? = nil, 
            domain: String? = nil, 
            url: URI? = nil, 
            tag: [String]? = nil, 
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
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let hitsTotal: Int?
        
        public let posts: [AppBskyFeedDefs.PostView]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            hitsTotal: Int? = nil,
            
            posts: [AppBskyFeedDefs.PostView]
            
            
        ) {
            
            self.cursor = cursor
            
            self.hitsTotal = hitsTotal
            
            self.posts = posts
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.hitsTotal = try container.decodeIfPresent(Int.self, forKey: .hitsTotal)
            
            
            self.posts = try container.decode([AppBskyFeedDefs.PostView].self, forKey: .posts)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            if let value = cursor {
                
                try container.encode(value, forKey: .cursor)
                
            }
            
            
            if let value = hitsTotal {
                
                try container.encode(value, forKey: .hitsTotal)
                
            }
            
            
            try container.encode(posts, forKey: .posts)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            if let value = cursor {
                
                
                let cursorValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "cursor", value: cursorValue)
                
            }
            
            
            
            if let value = hitsTotal {
                
                
                let hitsTotalValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "hitsTotal", value: hitsTotalValue)
                
            }
            
            
            
            
            let postsValue = try (posts as? DAGCBOREncodable)?.toCBORValue() ?? posts
            map = map.adding(key: "posts", value: postsValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cursor
            case hitsTotal
            case posts
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case badQueryString = "BadQueryString."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.App.Bsky.Feed {
    /// Find posts matching search criteria, returning views of those posts.
    public func searchPosts(input: AppBskyFeedSearchPosts.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedSearchPosts.Output?) {
        let endpoint = "app.bsky.feed.searchPosts"
        
        
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedSearchPosts.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
