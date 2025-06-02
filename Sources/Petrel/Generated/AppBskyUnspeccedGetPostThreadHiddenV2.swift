import Foundation



// lexicon: 1, id: app.bsky.unspecced.getPostThreadHiddenV2


public struct AppBskyUnspeccedGetPostThreadHiddenV2 { 

    public static let typeIdentifier = "app.bsky.unspecced.getPostThreadHiddenV2"
        
public struct ThreadHiddenItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.getPostThreadHiddenV2#threadHiddenItem"
            public let uri: ATProtocolURI
            public let depth: Int
            public let value: ThreadHiddenItemValueUnion

        // Standard initializer
        public init(
            uri: ATProtocolURI, depth: Int, value: ThreadHiddenItemValueUnion
        ) {
            
            self.uri = uri
            self.depth = depth
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.depth = try container.decode(Int.self, forKey: .depth)
                
            } catch {
                LogManager.logError("Decoding error for property 'depth': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(ThreadHiddenItemValueUnion.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(depth, forKey: .depth)
            
            
            try container.encode(value, forKey: .value)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(depth)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.depth != other.depth {
                return false
            }
            
            
            if self.value != other.value {
                return false
            }
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            let depthValue = try depth.toCBORValue()
            map = map.adding(key: "depth", value: depthValue)
            
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case depth
            case value
        }
    }    
public struct Parameters: Parametrizable {
        public let anchor: ATProtocolURI
        public let prioritizeFollowedUsers: Bool?
        
        public init(
            anchor: ATProtocolURI, 
            prioritizeFollowedUsers: Bool? = nil
            ) {
            self.anchor = anchor
            self.prioritizeFollowedUsers = prioritizeFollowedUsers
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let thread: [ThreadHiddenItem]
        
        
        
        // Standard public initializer
        public init(
            
            thread: [ThreadHiddenItem]
            
            
        ) {
            
            self.thread = thread
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.thread = try container.decode([ThreadHiddenItem].self, forKey: .thread)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(thread, forKey: .thread)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let threadValue = try thread.toCBORValue()
            map = map.adding(key: "thread", value: threadValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case thread
            
        }
    }






public enum ThreadHiddenItemValueUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyUnspeccedDefsThreadItemPost(AppBskyUnspeccedDefs.ThreadItemPost)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyUnspeccedDefs.ThreadItemPost) {
        self = .appBskyUnspeccedDefsThreadItemPost(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.unspecced.defs#threadItemPost":
            let value = try AppBskyUnspeccedDefs.ThreadItemPost(from: decoder)
            self = .appBskyUnspeccedDefsThreadItemPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyUnspeccedDefsThreadItemPost(let value):
            try container.encode("app.bsky.unspecced.defs#threadItemPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyUnspeccedDefsThreadItemPost(let value):
            hasher.combine("app.bsky.unspecced.defs#threadItemPost")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ThreadHiddenItemValueUnion, rhs: ThreadHiddenItemValueUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyUnspeccedDefsThreadItemPost(let lhsValue),
              .appBskyUnspeccedDefsThreadItemPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ThreadHiddenItemValueUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyUnspeccedDefsThreadItemPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.unspecced.defs#threadItemPost")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyUnspeccedDefsThreadItemPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyUnspeccedDefsThreadItemPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyUnspeccedDefsThreadItemPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.App.Bsky.Unspecced {
    // MARK: - getPostThreadHiddenV2

    /// (NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get the hidden posts in a thread. It is based in an anchor post at any depth of the tree, and returns hidden replies (recursive replies, with branching to their replies) below the anchor. It does not include ancestors nor the anchor. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPostThreadHiddenV2(input: AppBskyUnspeccedGetPostThreadHiddenV2.Parameters) async throws -> (responseCode: Int, data: AppBskyUnspeccedGetPostThreadHiddenV2.Output?) {
        let endpoint = "app.bsky.unspecced.getPostThreadHiddenV2"

        
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

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyUnspeccedGetPostThreadHiddenV2.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
