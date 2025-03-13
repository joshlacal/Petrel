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

        if let value = description {
            try container.encode(value, forKey: .description)
        }

        if let value = descriptionFacets {
            try container.encode(value, forKey: .descriptionFacets)
        }

        if let value = avatar {
            try container.encode(value, forKey: .avatar)
        }

        if let value = labels {
            try container.encode(value, forKey: .labels)
        }

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

    public enum AppBskyGraphListLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable {
        case comAtprotoLabelDefsSelfLabels(ComAtprotoLabelDefs.SelfLabels)
        case unexpected(ATProtocolValueContainer)

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
            case rawContent = "_rawContent"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? AppBskyGraphListLabelsUnion else { return false }

            switch (self, otherValue) {
            case let (
                .comAtprotoLabelDefsSelfLabels(selfValue),
                .comAtprotoLabelDefsSelfLabels(otherValue)
            ):
                return selfValue == otherValue

            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)

            default:
                return false
            }
        }
    }
}
