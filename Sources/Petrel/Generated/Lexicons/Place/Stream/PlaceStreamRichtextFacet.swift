import Foundation



// lexicon: 1, id: place.stream.richtext.facet


public struct PlaceStreamRichtextFacet: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.richtext.facet"
        public let index: AppBskyRichtextFacet.ByteSlice
        public let features: [PlaceStreamRichtextFacetFeaturesUnion]

        public init(index: AppBskyRichtextFacet.ByteSlice, features: [PlaceStreamRichtextFacetFeaturesUnion]) {
            self.index = index
            self.features = features
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.index = try container.decode(AppBskyRichtextFacet.ByteSlice.self, forKey: .index)
            self.features = try container.decode([PlaceStreamRichtextFacetFeaturesUnion].self, forKey: .features)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(index, forKey: .index)
            try container.encode(features, forKey: .features)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(index)
            hasher.combine(features)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if index != other.index {
                return false
            }
            if features != other.features {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let indexValue = try index.toCBORValue()
            map = map.adding(key: "index", value: indexValue)
            let featuresValue = try features.toCBORValue()
            map = map.adding(key: "features", value: featuresValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case index
            case features
        }





public enum PlaceStreamRichtextFacetFeaturesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention)
    case appBskyRichtextFacetLink(AppBskyRichtextFacet.Link)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyRichtextFacet.Mention) {
        self = .appBskyRichtextFacetMention(value)
    }
    public init(_ value: AppBskyRichtextFacet.Link) {
        self = .appBskyRichtextFacetLink(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.richtext.facet#mention":
            let value = try AppBskyRichtextFacet.Mention(from: decoder)
            self = .appBskyRichtextFacetMention(value)
        case "app.bsky.richtext.facet#link":
            let value = try AppBskyRichtextFacet.Link(from: decoder)
            self = .appBskyRichtextFacetLink(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyRichtextFacetMention(let value):
            try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyRichtextFacetLink(let value):
            try container.encode("app.bsky.richtext.facet#link", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyRichtextFacetMention(let value):
            hasher.combine("app.bsky.richtext.facet#mention")
            hasher.combine(value)
        case .appBskyRichtextFacetLink(let value):
            hasher.combine("app.bsky.richtext.facet#link")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: PlaceStreamRichtextFacetFeaturesUnion, rhs: PlaceStreamRichtextFacetFeaturesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyRichtextFacetMention(let lhsValue),
              .appBskyRichtextFacetMention(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyRichtextFacetLink(let lhsValue),
              .appBskyRichtextFacetLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? PlaceStreamRichtextFacetFeaturesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyRichtextFacetMention(let value):
            map = map.adding(key: "$type", value: "app.bsky.richtext.facet#mention")
            
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
        case .appBskyRichtextFacetLink(let value):
            map = map.adding(key: "$type", value: "app.bsky.richtext.facet#link")
            
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

// Union Array Type


public struct Features: Codable, ATProtocolCodable, ATProtocolValue {
    public let items: [FeaturesForUnionArray]
    
    public init(items: [FeaturesForUnionArray]) {
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items = [FeaturesForUnionArray]()
        while !container.isAtEnd {
            let item = try container.decode(FeaturesForUnionArray.self)
            items.append(item)
        }
        self.items = items
    }

    public func encode(to encoder: Encoder) throws {
        // Encode the array regardless of whether it's empty
        var container = encoder.unkeyedContainer()
        for item in items {
            try container.encode(item)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Features else { return false }
        
        if self.items != other.items {
            return false
        }

        return true
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // For union arrays, we need to encode each item while preserving its order
        var itemsArray = [Any]()
        
        for item in items {
            let itemValue = try item.toCBORValue()
            itemsArray.append(itemValue)
        }
        
        return itemsArray
    }

}


public enum FeaturesForUnionArray: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyRichtextFacetMention(AppBskyRichtextFacetMention)
    case appBskyRichtextFacetLink(AppBskyRichtextFacetLink)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyRichtextFacetMention) {
        self = .appBskyRichtextFacetMention(value)
    }
    public init(_ value: AppBskyRichtextFacetLink) {
        self = .appBskyRichtextFacetLink(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "AppBskyRichtextFacet.Mention":
            let value = try AppBskyRichtextFacetMention(from: decoder)
            self = .appBskyRichtextFacetMention(value)
        case "AppBskyRichtextFacet.Link":
            let value = try AppBskyRichtextFacetLink(from: decoder)
            self = .appBskyRichtextFacetLink(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyRichtextFacetMention(let value):
            try container.encode("AppBskyRichtextFacet.Mention", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyRichtextFacetLink(let value):
            try container.encode("AppBskyRichtextFacet.Link", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyRichtextFacetMention(let value):
            hasher.combine("AppBskyRichtextFacet.Mention")
            hasher.combine(value)
        case .appBskyRichtextFacetLink(let value):
            hasher.combine("AppBskyRichtextFacet.Link")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? FeaturesForUnionArray else { return false }

        switch (self, otherValue) {
        case (.appBskyRichtextFacetMention(let selfValue), 
              .appBskyRichtextFacetMention(let otherValue)):
            return selfValue == otherValue
        case (.appBskyRichtextFacetLink(let selfValue), 
              .appBskyRichtextFacetLink(let otherValue)):
            return selfValue == otherValue
        case (.unexpected(let selfValue), .unexpected(let otherValue)):
            return selfValue.isEqual(to: otherValue)
        default:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyRichtextFacetMention(let value):
            map = map.adding(key: "$type", value: "AppBskyRichtextFacet.Mention")
            
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
        case .appBskyRichtextFacetLink(let value):
            map = map.adding(key: "$type", value: "AppBskyRichtextFacet.Link")
            
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


                           

