import Foundation

// lexicon: 1, id: app.bsky.graph.list

public struct AppBskyGraphList: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.graph.list"
    public let purpose: AppBskyGraphDefs.ListPurpose
    public let name: String
    public let description: String?
    public let descriptionFacets: [AppBskyRichtextFacet]?
    public let avatar: Blob?
    public let labels: AppBskyGraphListLabelsUnion?
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(purpose: AppBskyGraphDefs.ListPurpose, name: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: Blob?, labels: AppBskyGraphListLabelsUnion?, createdAt: ATProtocolDate) {
        self.purpose = purpose

        self.name = name

        self.description = description

        self.descriptionFacets = descriptionFacets

        self.avatar = avatar

        self.labels = labels

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        purpose = try container.decode(AppBskyGraphDefs.ListPurpose.self, forKey: .purpose)

        name = try container.decode(String.self, forKey: .name)

        description = try container.decodeIfPresent(String.self, forKey: .description)

        descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)

        avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)

        labels = try container.decodeIfPresent(AppBskyGraphListLabelsUnion.self, forKey: .labels)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(purpose, forKey: .purpose)

        try container.encode(name, forKey: .name)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(description, forKey: .description)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(descriptionFacets, forKey: .descriptionFacets)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(avatar, forKey: .avatar)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(labels, forKey: .labels)

        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if purpose != other.purpose {
            return false
        }

        if name != other.name {
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

        if labels != other.labels {
            return false
        }

        if createdAt != other.createdAt {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(purpose)
        hasher.combine(name)
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
        if let value = labels {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        hasher.combine(createdAt)
    }

    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        map = map.adding(key: "$type", value: Self.typeIdentifier)

        let purposeValue = try purpose.toCBORValue()
        map = map.adding(key: "purpose", value: purposeValue)

        let nameValue = try name.toCBORValue()
        map = map.adding(key: "name", value: nameValue)

        if let value = description {
            // Encode optional property even if it's an empty array for CBOR
            let descriptionValue = try value.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)
        }

        if let value = descriptionFacets {
            // Encode optional property even if it's an empty array for CBOR
            let descriptionFacetsValue = try value.toCBORValue()
            map = map.adding(key: "descriptionFacets", value: descriptionFacetsValue)
        }

        if let value = avatar {
            // Encode optional property even if it's an empty array for CBOR
            let avatarValue = try value.toCBORValue()
            map = map.adding(key: "avatar", value: avatarValue)
        }

        if let value = labels {
            // Encode optional property even if it's an empty array for CBOR
            let labelsValue = try value.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
        }

        let createdAtValue = try createdAt.toCBORValue()
        map = map.adding(key: "createdAt", value: createdAtValue)

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case purpose
        case name
        case description
        case descriptionFacets
        case avatar
        case labels
        case createdAt
    }

    public enum AppBskyGraphListLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .comAtprotoLabelDefsSelfLabels(value):
                try container.encode("com.atproto.label.defs#selfLabels", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                hasher.combine("com.atproto.label.defs#selfLabels")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyGraphListLabelsUnion, rhs: AppBskyGraphListLabelsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .comAtprotoLabelDefsSelfLabels(lhsValue),
                .comAtprotoLabelDefsSelfLabels(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyGraphListLabelsUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                map = map.adding(key: "$type", value: "com.atproto.label.defs#selfLabels")

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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}
