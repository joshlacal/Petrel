import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.feed.getPostThread


public struct AppBskyFeedGetPostThread { 

    public static let typeIdentifier = "app.bsky.feed.getPostThread"    
public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let depth: Int?
        public let parentHeight: Int?
        
        public init(
            uri: ATProtocolURI, 
            depth: Int? = nil, 
            parentHeight: Int? = nil
            ) {
            self.uri = uri
            self.depth = depth
            self.parentHeight = parentHeight
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let thread: OutputThreadUnion
        
        public let threadgate: AppBskyFeedDefs.ThreadgateView?
        
        
        
        // Standard public initializer
        public init(
            
            thread: OutputThreadUnion,
            
            threadgate: AppBskyFeedDefs.ThreadgateView? = nil
            
            
        ) {
            
            self.thread = thread
            
            self.threadgate = threadgate
            
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case notFound = "NotFound."
            public var description: String {
                return self.rawValue
            }
        }




public indirect enum OutputThreadUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#threadViewPost":
            let value = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
            self = .appBskyFeedDefsThreadViewPost(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            hasher.combine("app.bsky.feed.defs#threadViewPost")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? OutputThreadUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsThreadViewPost(let selfValue), 
                .appBskyFeedDefsThreadViewPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsNotFoundPost(let selfValue), 
                .appBskyFeedDefsNotFoundPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsBlockedPost(let selfValue), 
                .appBskyFeedDefsBlockedPost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}


extension ATProtoClient.App.Bsky.Feed {
    /// Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.
    public func getPostThread(input: AppBskyFeedGetPostThread.Parameters) async throws -> (responseCode: Int, data: AppBskyFeedGetPostThread.Output?) {
        let endpoint = "app.bsky.feed.getPostThread"
        
        
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
        let decodedData = try? decoder.decode(AppBskyFeedGetPostThread.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
