import Foundation



// lexicon: 1, id: app.bsky.feed.postgate


public struct AppBskyFeedPostgate: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.feed.postgate"
        public let createdAt: ATProtocolDate
        public let post: ATProtocolURI
        public let detachedEmbeddingUris: [ATProtocolURI]?
        public let embeddingRules: [AppBskyFeedPostgateEmbeddingRulesUnion]?

        // Standard initializer
        public init(createdAt: ATProtocolDate, post: ATProtocolURI, detachedEmbeddingUris: [ATProtocolURI]?, embeddingRules: [AppBskyFeedPostgateEmbeddingRulesUnion]?) {
            
            self.createdAt = createdAt
            
            self.post = post
            
            self.detachedEmbeddingUris = detachedEmbeddingUris
            
            self.embeddingRules = embeddingRules
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
            
            self.post = try container.decode(ATProtocolURI.self, forKey: .post)
            
            
            self.detachedEmbeddingUris = try container.decodeIfPresent([ATProtocolURI].self, forKey: .detachedEmbeddingUris)
            
            
            self.embeddingRules = try container.decodeIfPresent([AppBskyFeedPostgateEmbeddingRulesUnion].self, forKey: .embeddingRules)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            try container.encode(post, forKey: .post)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(detachedEmbeddingUris, forKey: .detachedEmbeddingUris)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embeddingRules, forKey: .embeddingRules)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            if self.post != other.post {
                return false
            }
            
            
            if detachedEmbeddingUris != other.detachedEmbeddingUris {
                return false
            }
            
            
            if embeddingRules != other.embeddingRules {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(createdAt)
            hasher.combine(post)
            if let value = detachedEmbeddingUris {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = embeddingRules {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            if let value = detachedEmbeddingUris {
                // Encode optional property even if it's an empty array for CBOR
                let detachedEmbeddingUrisValue = try value.toCBORValue()
                map = map.adding(key: "detachedEmbeddingUris", value: detachedEmbeddingUrisValue)
            }
            
            
            
            if let value = embeddingRules {
                // Encode optional property even if it's an empty array for CBOR
                let embeddingRulesValue = try value.toCBORValue()
                map = map.adding(key: "embeddingRules", value: embeddingRulesValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case createdAt
            case post
            case detachedEmbeddingUris
            case embeddingRules
        }
        
public struct DisableRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.postgate#disableRule"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }





public enum AppBskyFeedPostgateEmbeddingRulesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedPostgateDisableRule(AppBskyFeedPostgate.DisableRule)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyFeedPostgate.DisableRule) {
        self = .appBskyFeedPostgateDisableRule(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.postgate#disableRule":
            let value = try AppBskyFeedPostgate.DisableRule(from: decoder)
            self = .appBskyFeedPostgateDisableRule(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            try container.encode("app.bsky.feed.postgate#disableRule", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            hasher.combine("app.bsky.feed.postgate#disableRule")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyFeedPostgateEmbeddingRulesUnion, rhs: AppBskyFeedPostgateEmbeddingRulesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedPostgateDisableRule(let lhsValue),
              .appBskyFeedPostgateDisableRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyFeedPostgateEmbeddingRulesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.postgate#disableRule")
            
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
}


}


                           

