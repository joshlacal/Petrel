import Foundation



// lexicon: 1, id: app.bsky.bookmark.defs


public struct AppBskyBookmarkDefs { 

    public static let typeIdentifier = "app.bsky.bookmark.defs"
        
public struct Bookmark: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.bookmark.defs#bookmark"
            public let subject: ComAtprotoRepoStrongRef

        // Standard initializer
        public init(
            subject: ComAtprotoRepoStrongRef
        ) {
            
            self.subject = subject
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.subject = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .subject)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'subject': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(subject, forKey: .subject)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.subject != other.subject {
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

            
            
            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
        }
    }
        
public struct BookmarkView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.bookmark.defs#bookmarkView"
            public let subject: ComAtprotoRepoStrongRef
            public let createdAt: ATProtocolDate?
            public let item: BookmarkViewItemUnion

        // Standard initializer
        public init(
            subject: ComAtprotoRepoStrongRef, createdAt: ATProtocolDate?, item: BookmarkViewItemUnion
        ) {
            
            self.subject = subject
            self.createdAt = createdAt
            self.item = item
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.subject = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .subject)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'subject': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.item = try container.decode(BookmarkViewItemUnion.self, forKey: .item)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'item': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(subject, forKey: .subject)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            
            
            
            
            try container.encode(item, forKey: .item)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(item)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.subject != other.subject {
                return false
            }
            
            
            
            
            if createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if self.item != other.item {
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

            
            
            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            
            
            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            
            
            
            
            
            
            let itemValue = try item.toCBORValue()
            map = map.adding(key: "item", value: itemValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case createdAt
            case item
        }
    }




public indirect enum BookmarkViewItemUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsPostView(AppBskyFeedDefs.PostView)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.PostView) {
        self = .appBskyFeedDefsPostView(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#postView":
            let value = try AppBskyFeedDefs.PostView(from: decoder)
            self = .appBskyFeedDefsPostView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsPostView(let value):
            try container.encode("app.bsky.feed.defs#postView", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsPostView(let value):
            hasher.combine("app.bsky.feed.defs#postView")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: BookmarkViewItemUnion, rhs: BookmarkViewItemUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsPostView(let lhsValue),
              .appBskyFeedDefsPostView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? BookmarkViewItemUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsBlockedPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
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
        case .appBskyFeedDefsNotFoundPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
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
        case .appBskyFeedDefsPostView(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#postView")
            
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


                           
