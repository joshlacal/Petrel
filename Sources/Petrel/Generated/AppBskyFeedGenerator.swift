import Foundation
import ZippyJSON

// lexicon: 1, id: app.bsky.feed.generator

public struct AppBskyFeedGenerator: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.feed.generator"
    public let did: String
    public let displayName: String
    public let description: String?
    public let descriptionFacets: [AppBskyRichtextFacet]?
    public let avatar: Blob?
    public let acceptsInteractions: Bool?
    public let labels: AppBskyFeedGeneratorLabelsUnion?
    public let contentMode: String?
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(did: String, displayName: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: Blob?, acceptsInteractions: Bool?, labels: AppBskyFeedGeneratorLabelsUnion?, contentMode: String?, createdAt: ATProtocolDate) {
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

        did = try container.decode(String.self, forKey: .did)

        displayName = try container.decode(String.self, forKey: .displayName)

        description = try container.decodeIfPresent(String.self, forKey: .description)

        descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)

        avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)

        acceptsInteractions = try container.decodeIfPresent(Bool.self, forKey: .acceptsInteractions)

        labels = try container.decodeIfPresent(AppBskyFeedGeneratorLabelsUnion.self, forKey: .labels)

        contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
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
            try container.encode(value, forKey: .descriptionFacets)
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

        if did != other.did {
            return false
        }

        if displayName != other.displayName {
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

        if createdAt != other.createdAt {
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

    public enum AppBskyFeedGeneratorLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue {
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
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                hasher.combine("com.atproto.label.defs#selfLabels")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? AppBskyFeedGeneratorLabelsUnion else { return false }

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
