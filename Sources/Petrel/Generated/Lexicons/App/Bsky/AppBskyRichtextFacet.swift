import Foundation



// lexicon: 1, id: app.bsky.richtext.facet


public struct AppBskyRichtextFacet: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.richtext.facet"
        public let index: ByteSlice
        public let features: [AppBskyRichtextFacetFeaturesUnion]

        public init(index: ByteSlice, features: [AppBskyRichtextFacetFeaturesUnion]) {
            self.index = index
            self.features = features
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.index = try container.decode(ByteSlice.self, forKey: .index)
            self.features = try container.decode([AppBskyRichtextFacetFeaturesUnion].self, forKey: .features)
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
        
public struct Mention: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.richtext.facet#mention"
            public let did: DID

        public init(
            did: DID
        ) {
            self.did = did
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }
        
public struct Link: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.richtext.facet#link"
            public let uri: URI

        public init(
            uri: URI
        ) {
            self.uri = uri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(URI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }
        
public struct Tag: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.richtext.facet#tag"
            public let tag: String

        public init(
            tag: String
        ) {
            self.tag = tag
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.tag = try container.decode(String.self, forKey: .tag)
            } catch {
                LogManager.logError("Decoding error for required property 'tag': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(tag, forKey: .tag)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(tag)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if tag != other.tag {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let tagValue = try tag.toCBORValue()
            map = map.adding(key: "tag", value: tagValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case tag
        }
    }
        
public struct ByteSlice: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.richtext.facet#byteSlice"
            public let byteStart: Int
            public let byteEnd: Int

        public init(
            byteStart: Int, byteEnd: Int
        ) {
            self.byteStart = byteStart
            self.byteEnd = byteEnd
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.byteStart = try container.decode(Int.self, forKey: .byteStart)
            } catch {
                LogManager.logError("Decoding error for required property 'byteStart': \(error)")
                throw error
            }
            do {
                self.byteEnd = try container.decode(Int.self, forKey: .byteEnd)
            } catch {
                LogManager.logError("Decoding error for required property 'byteEnd': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(byteStart, forKey: .byteStart)
            try container.encode(byteEnd, forKey: .byteEnd)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(byteStart)
            hasher.combine(byteEnd)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if byteStart != other.byteStart {
                return false
            }
            if byteEnd != other.byteEnd {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let byteStartValue = try byteStart.toCBORValue()
            map = map.adding(key: "byteStart", value: byteStartValue)
            let byteEndValue = try byteEnd.toCBORValue()
            map = map.adding(key: "byteEnd", value: byteEndValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case byteStart
            case byteEnd
        }
    }





public enum AppBskyRichtextFacetFeaturesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyRichtextFacetMention(AppBskyRichtextFacet.Mention)
    case appBskyRichtextFacetLink(AppBskyRichtextFacet.Link)
    case appBskyRichtextFacetTag(AppBskyRichtextFacet.Tag)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyRichtextFacet.Mention) {
        self = .appBskyRichtextFacetMention(value)
    }
    public init(_ value: AppBskyRichtextFacet.Link) {
        self = .appBskyRichtextFacetLink(value)
    }
    public init(_ value: AppBskyRichtextFacet.Tag) {
        self = .appBskyRichtextFacetTag(value)
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
        case "app.bsky.richtext.facet#tag":
            let value = try AppBskyRichtextFacet.Tag(from: decoder)
            self = .appBskyRichtextFacetTag(value)
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
        case .appBskyRichtextFacetTag(let value):
            try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
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
        case .appBskyRichtextFacetTag(let value):
            hasher.combine("app.bsky.richtext.facet#tag")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyRichtextFacetFeaturesUnion, rhs: AppBskyRichtextFacetFeaturesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyRichtextFacetMention(let lhsValue),
              .appBskyRichtextFacetMention(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyRichtextFacetLink(let lhsValue),
              .appBskyRichtextFacetLink(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyRichtextFacetTag(let lhsValue),
              .appBskyRichtextFacetTag(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyRichtextFacetFeaturesUnion else { return false }
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
        case .appBskyRichtextFacetTag(let value):
            map = map.adding(key: "$type", value: "app.bsky.richtext.facet#tag")
            
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
    case mention(Mention)
    case link(Link)
    case tag(Tag)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: Mention) {
        self = .mention(value)
    }
    public init(_ value: Link) {
        self = .link(value)
    }
    public init(_ value: Tag) {
        self = .tag(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "Mention":
            let value = try Mention(from: decoder)
            self = .mention(value)
        case "Link":
            let value = try Link(from: decoder)
            self = .link(value)
        case "Tag":
            let value = try Tag(from: decoder)
            self = .tag(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .mention(let value):
            try container.encode("Mention", forKey: .type)
            try value.encode(to: encoder)
        case .link(let value):
            try container.encode("Link", forKey: .type)
            try value.encode(to: encoder)
        case .tag(let value):
            try container.encode("Tag", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .mention(let value):
            hasher.combine("Mention")
            hasher.combine(value)
        case .link(let value):
            hasher.combine("Link")
            hasher.combine(value)
        case .tag(let value):
            hasher.combine("Tag")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? FeaturesForUnionArray else { return false }

        switch (self, otherValue) {
        case (.mention(let selfValue), 
              .mention(let otherValue)):
            return selfValue == otherValue
        case (.link(let selfValue), 
              .link(let otherValue)):
            return selfValue == otherValue
        case (.tag(let selfValue), 
              .tag(let otherValue)):
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
        case .mention(let value):
            map = map.adding(key: "$type", value: "Mention")
            
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
        case .link(let value):
            map = map.adding(key: "$type", value: "Link")
            
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
        case .tag(let value):
            map = map.adding(key: "$type", value: "Tag")
            
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


                           

