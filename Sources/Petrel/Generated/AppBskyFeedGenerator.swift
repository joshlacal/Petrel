import Foundation



// lexicon: 1, id: app.bsky.feed.generator


public struct AppBskyFeedGenerator: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.feed.generator"
        public let did: DID
        public let displayName: String
        public let description: String?
        public let descriptionFacets: [AppBskyRichtextFacet]?
        public let avatar: Blob?
        public let acceptsInteractions: Bool?
        public let labels: AppBskyFeedGeneratorLabelsUnion?
        public let contentMode: String?
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(did: DID, displayName: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: Blob?, acceptsInteractions: Bool?, labels: AppBskyFeedGeneratorLabelsUnion?, contentMode: String?, createdAt: ATProtocolDate) {
            
            self.did = did
            
            self.displayName = displayName
            
            self.description = description
            
            self.descriptionFacets = descriptionFacets
            
            self.avatar = avatar
            
            self.acceptsInteractions = acceptsInteractions
            
            self.labels = labels
            
            self.contentMode = contentMode
            
            self.createdAt = createdAt
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.did = try container.decode(DID.self, forKey: .did)
            
            
            self.displayName = try container.decode(String.self, forKey: .displayName)
            
            
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            
            
            self.descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)
            
            
            self.avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)
            
            
            self.acceptsInteractions = try container.decodeIfPresent(Bool.self, forKey: .acceptsInteractions)
            
            
            self.labels = try container.decodeIfPresent(AppBskyFeedGeneratorLabelsUnion.self, forKey: .labels)
            
            
            self.contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(displayName, forKey: .displayName)
            
            
            if let value = description {
                
                try container.encode(value, forKey: .description)
                
            }
            
            
            if let value = descriptionFacets {
                
                if !value.isEmpty {
                    try container.encode(value, forKey: .descriptionFacets)
                }
                
            }
            
            
            if let value = avatar {
                
                try container.encode(value, forKey: .avatar)
                
            }
            
            
            if let value = acceptsInteractions {
                
                try container.encode(value, forKey: .acceptsInteractions)
                
            }
            
            
            if let value = labels {
                
                try container.encode(value, forKey: .labels)
                
            }
            
            
            if let value = contentMode {
                
                try container.encode(value, forKey: .contentMode)
                
            }
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            
            if self.displayName != other.displayName {
                return false
            }
            
            
            if description != other.description {
                return false
            }
            
            
            if descriptionFacets != other.descriptionFacets {
                return false
            }
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            if acceptsInteractions != other.acceptsInteractions {
                return false
            }
            
            
            if labels != other.labels {
                return false
            }
            
            
            if contentMode != other.contentMode {
                return false
            }
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(displayName)
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = descriptionFacets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = acceptsInteractions {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            if let value = contentMode {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
            hasher.combine(createdAt)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            
            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            
            // Add remaining fields in lexicon-defined order
            
            
            
            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            let displayNameValue = try (displayName as? DAGCBOREncodable)?.toCBORValue() ?? displayName
            map = map.adding(key: "displayName", value: displayNameValue)
            
            
            
            if let value = description {
                
                
                let descriptionValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "description", value: descriptionValue)
                
            }
            
            
            
            if let value = descriptionFacets {
                
                if !value.isEmpty {
                    
                    let descriptionFacetsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "descriptionFacets", value: descriptionFacetsValue)
                }
                
            }
            
            
            
            if let value = avatar {
                
                
                let avatarValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "avatar", value: avatarValue)
                
            }
            
            
            
            if let value = acceptsInteractions {
                
                
                let acceptsInteractionsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "acceptsInteractions", value: acceptsInteractionsValue)
                
            }
            
            
            
            if let value = labels {
                
                
                let labelsValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "labels", value: labelsValue)
                
            }
            
            
            
            if let value = contentMode {
                
                
                let contentModeValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "contentMode", value: contentModeValue)
                
            }
            
            
            
            
            let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case displayName
            case description
            case descriptionFacets
            case avatar
            case acceptsInteractions
            case labels
            case contentMode
            case createdAt
        }





public enum AppBskyFeedGeneratorLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoLabelDefs.SelfLabels) {
        self = .comAtprotoLabelDefsSelfLabels(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.label.defs#selfLabels":
            let value = try ComAtprotoLabelDefs.SelfLabels(from: decoder)
            self = .comAtprotoLabelDefsSelfLabels(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            try container.encode("com.atproto.label.defs#selfLabels", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            hasher.combine("com.atproto.label.defs#selfLabels")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: AppBskyFeedGeneratorLabelsUnion, rhs: AppBskyFeedGeneratorLabelsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoLabelDefsSelfLabels(let lhsValue),
              .comAtprotoLabelDefsSelfLabels(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? AppBskyFeedGeneratorLabelsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoLabelDefsSelfLabels(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "com.atproto.label.defs#selfLabels")
            
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
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoLabelDefsSelfLabels(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoLabelDefsSelfLabels(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoLabelDefsSelfLabels(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


                           
