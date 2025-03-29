import Foundation



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
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.thread = try container.decode(OutputThreadUnion.self, forKey: .thread)
            
            
            self.threadgate = try container.decodeIfPresent(AppBskyFeedDefs.ThreadgateView.self, forKey: .threadgate)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(thread, forKey: .thread)
            
            
            if let value = threadgate {
                
                try container.encode(value, forKey: .threadgate)
                
            }
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let threadValue = try (thread as? DAGCBOREncodable)?.toCBORValue() ?? thread
            map = map.adding(key: "thread", value: threadValue)
            
            
            
            if let value = threadgate {
                
                
                let threadgateValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "threadgate", value: threadgateValue)
                
            }
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case thread
            case threadgate
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case notFound = "NotFound."
            public var description: String {
                return self.rawValue
            }
        }




public indirect enum OutputThreadUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)
    
    case pending(PendingDecodeData)
    
    
    public init(_ value: AppBskyFeedDefs.ThreadViewPost) {
        self = .appBskyFeedDefsThreadViewPost(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        
        let depth = decoder.codingPath.count
        
        // Check if we're at a recursion depth that might cause stack overflow
        if depth > DecodingConfiguration.standard.threshold {
            if DecodingConfiguration.standard.debugMode {
                print("🔄 Deferring deep decode for OutputThreadUnion at depth \(depth), type: \(typeValue)")
            }
            
            // Get the original JSON data if available
            if let originalData = decoder.userInfo[.originalData] as? Data {
                do {
                    // Extract just the portion we need based on the coding path
                    if let nestedData = try SafeDecoder.extractNestedJSON(from: originalData, at: decoder.codingPath) {
                        self = .pending(PendingDecodeData(rawData: nestedData, type: typeValue))
                        return
                    }
                } catch {
                    // Fall through to minimal data approach if extraction fails
                }
            }
            
            // Fallback if we can't get the nested data - store minimal information
            let minimalData = try JSONEncoder().encode(["$type": typeValue])
            self = .pending(PendingDecodeData(rawData: minimalData, type: typeValue))
            return
        }
        

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        case .pending(let pendingData):
            try container.encode(pendingData.type, forKey: .type)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        case .pending(let pendingData):
            hasher.combine("pending")
            hasher.combine(pendingData.type)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputThreadUnion, rhs: OutputThreadUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsThreadViewPost(let lhsValue),
              .appBskyFeedDefsThreadViewPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        case (.pending(let lhsData), .pending(let rhsData)):
            return lhsData.type == rhsData.type
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputThreadUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#threadViewPost")
            
            // Add the value's fields while preserving their order
            if let encodableValue = value as? DAGCBOREncodable {
                let valueDict = try encodableValue.toCBORValue()
                
                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
            }
            return map
        case .appBskyFeedDefsNotFoundPost(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
            // Add the value's fields while preserving their order
            if let encodableValue = value as? DAGCBOREncodable {
                let valueDict = try encodableValue.toCBORValue()
                
                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
            }
            return map
        case .appBskyFeedDefsBlockedPost(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
            // Add the value's fields while preserving their order
            if let encodableValue = value as? DAGCBOREncodable {
                let valueDict = try encodableValue.toCBORValue()
                
                // If the value is already an OrderedCBORMap, merge its entries
                if let orderedMap = valueDict as? OrderedCBORMap {
                    for (key, value) in orderedMap.entries where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                } else if let dict = valueDict as? [String: Any] {
                    // Otherwise add each key-value pair from the dictionary
                    for (key, value) in dict where key != "$type" {
                        map = map.adding(key: key, value: value)
                    }
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        
        case .pending(let pendingData):
            map = map.adding(key: "$type", value: pendingData.type)
            return map
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .pending:
            return true
        
        case .appBskyFeedDefsThreadViewPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsNotFoundPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsBlockedPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .pending(let pendingData):
            do {
                // Attempt to decode the full object using the raw data
                switch pendingData.type {
                case "app.bsky.feed.defs#threadViewPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.ThreadViewPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsThreadViewPost(value)
                case "app.bsky.feed.defs#notFoundPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.NotFoundPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsNotFoundPost(value)
                case "app.bsky.feed.defs#blockedPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.BlockedPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsBlockedPost(value)
                default:
                    let unknownValue = ATProtocolValueContainer.string("Unknown type: \(pendingData.type)")
                    self = .unexpected(unknownValue)
                }
            } catch {
                if DecodingConfiguration.standard.debugMode {
                    print("❌ Failed to decode pending data for OutputThreadUnion: \(error)")
                }
                self = .unexpected(ATProtocolValueContainer.string("Failed to decode: \(error)"))
            }
        
        case .appBskyFeedDefsThreadViewPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsThreadViewPost(value)
        case .appBskyFeedDefsNotFoundPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsNotFoundPost(value)
        case .appBskyFeedDefsBlockedPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsBlockedPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyFeedGetPostThread.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
