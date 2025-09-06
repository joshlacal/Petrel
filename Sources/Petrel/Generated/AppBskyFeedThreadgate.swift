import Foundation



// lexicon: 1, id: app.bsky.feed.threadgate


public struct AppBskyFeedThreadgate: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.feed.threadgate"
        public let post: ATProtocolURI
        public let allow: [AppBskyFeedThreadgateAllowUnion]?
        public let createdAt: ATProtocolDate
        public let hiddenReplies: [ATProtocolURI]?

        // Standard initializer
        public init(post: ATProtocolURI, allow: [AppBskyFeedThreadgateAllowUnion]?, createdAt: ATProtocolDate, hiddenReplies: [ATProtocolURI]?) {
            
            self.post = post
            
            self.allow = allow
            
            self.createdAt = createdAt
            
            self.hiddenReplies = hiddenReplies
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.post = try container.decode(ATProtocolURI.self, forKey: .post)
            
            
            self.allow = try container.decodeIfPresent([AppBskyFeedThreadgateAllowUnion].self, forKey: .allow)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
            
            self.hiddenReplies = try container.decodeIfPresent([ATProtocolURI].self, forKey: .hiddenReplies)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allow, forKey: .allow)
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hiddenReplies, forKey: .hiddenReplies)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.post != other.post {
                return false
            }
            
            
            if allow != other.allow {
                return false
            }
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            if hiddenReplies != other.hiddenReplies {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            if let value = allow {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            hasher.combine(createdAt)
            if let value = hiddenReplies {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            if let value = allow {
                // Encode optional property even if it's an empty array for CBOR
                let allowValue = try value.toCBORValue()
                map = map.adding(key: "allow", value: allowValue)
            }
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            if let value = hiddenReplies {
                // Encode optional property even if it's an empty array for CBOR
                let hiddenRepliesValue = try value.toCBORValue()
                map = map.adding(key: "hiddenReplies", value: hiddenRepliesValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case allow
            case createdAt
            case hiddenReplies
        }
        
public struct MentionRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.threadgate#mentionRule"

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
        
public struct FollowerRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.threadgate#followerRule"

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
        
public struct FollowingRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.threadgate#followingRule"

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
        
public struct ListRule: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.threadgate#listRule"
            public let list: ATProtocolURI

        // Standard initializer
        public init(
            list: ATProtocolURI
        ) {
            
            self.list = list
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.list = try container.decode(ATProtocolURI.self, forKey: .list)
                
            } catch {
                LogManager.logError("Decoding error for property 'list': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(list, forKey: .list)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(list)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.list != other.list {
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

            
            
            
            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case list
        }
    }





public enum AppBskyFeedThreadgateAllowUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule)
    case appBskyFeedThreadgateFollowerRule(AppBskyFeedThreadgate.FollowerRule)
    case appBskyFeedThreadgateFollowingRule(AppBskyFeedThreadgate.FollowingRule)
    case appBskyFeedThreadgateListRule(AppBskyFeedThreadgate.ListRule)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyFeedThreadgate.MentionRule) {
        self = .appBskyFeedThreadgateMentionRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.FollowerRule) {
        self = .appBskyFeedThreadgateFollowerRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.FollowingRule) {
        self = .appBskyFeedThreadgateFollowingRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.ListRule) {
        self = .appBskyFeedThreadgateListRule(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.feed.threadgate#mentionRule":
            let value = try AppBskyFeedThreadgate.MentionRule(from: decoder)
            self = .appBskyFeedThreadgateMentionRule(value)
        case "app.bsky.feed.threadgate#followerRule":
            let value = try AppBskyFeedThreadgate.FollowerRule(from: decoder)
            self = .appBskyFeedThreadgateFollowerRule(value)
        case "app.bsky.feed.threadgate#followingRule":
            let value = try AppBskyFeedThreadgate.FollowingRule(from: decoder)
            self = .appBskyFeedThreadgateFollowingRule(value)
        case "app.bsky.feed.threadgate#listRule":
            let value = try AppBskyFeedThreadgate.ListRule(from: decoder)
            self = .appBskyFeedThreadgateListRule(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            try container.encode("app.bsky.feed.threadgate#mentionRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateFollowerRule(let value):
            try container.encode("app.bsky.feed.threadgate#followerRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateFollowingRule(let value):
            try container.encode("app.bsky.feed.threadgate#followingRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateListRule(let value):
            try container.encode("app.bsky.feed.threadgate#listRule", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            hasher.combine("app.bsky.feed.threadgate#mentionRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateFollowerRule(let value):
            hasher.combine("app.bsky.feed.threadgate#followerRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateFollowingRule(let value):
            hasher.combine("app.bsky.feed.threadgate#followingRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateListRule(let value):
            hasher.combine("app.bsky.feed.threadgate#listRule")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyFeedThreadgateAllowUnion, rhs: AppBskyFeedThreadgateAllowUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedThreadgateMentionRule(let lhsValue),
              .appBskyFeedThreadgateMentionRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateFollowerRule(let lhsValue),
              .appBskyFeedThreadgateFollowerRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateFollowingRule(let lhsValue),
              .appBskyFeedThreadgateFollowingRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateListRule(let lhsValue),
              .appBskyFeedThreadgateListRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyFeedThreadgateAllowUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#mentionRule")
            
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
        case .appBskyFeedThreadgateFollowerRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followerRule")
            
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
        case .appBskyFeedThreadgateFollowingRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followingRule")
            
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
        case .appBskyFeedThreadgateListRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#listRule")
            
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
        
        case .appBskyFeedThreadgateMentionRule(let value):
            return value.hasPendingData
        case .appBskyFeedThreadgateFollowerRule(let value):
            return value.hasPendingData
        case .appBskyFeedThreadgateFollowingRule(let value):
            return value.hasPendingData
        case .appBskyFeedThreadgateListRule(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyFeedThreadgateMentionRule(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedThreadgateMentionRule(value)
        case .appBskyFeedThreadgateFollowerRule(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedThreadgateFollowerRule(value)
        case .appBskyFeedThreadgateFollowingRule(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedThreadgateFollowingRule(value)
        case .appBskyFeedThreadgateListRule(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedThreadgateListRule(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


                           
