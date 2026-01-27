import Foundation

// lexicon: 1, id: app.bsky.actor.profile

public struct AppBskyActorProfile: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.actor.profile"
    public let displayName: String?
    public let description: String?
    public let pronouns: String?
    public let website: URI?
    public let avatar: Blob?
    public let banner: Blob?
    public let labels: AppBskyActorProfileLabelsUnion?
    public let joinedViaStarterPack: ComAtprotoRepoStrongRef?
    public let pinnedPost: ComAtprotoRepoStrongRef?
    public let createdAt: ATProtocolDate?

    public init(displayName: String?, description: String?, pronouns: String?, website: URI?, avatar: Blob?, banner: Blob?, labels: AppBskyActorProfileLabelsUnion?, joinedViaStarterPack: ComAtprotoRepoStrongRef?, pinnedPost: ComAtprotoRepoStrongRef?, createdAt: ATProtocolDate?) {
        self.displayName = displayName
        self.description = description
        self.pronouns = pronouns
        self.website = website
        self.avatar = avatar
        self.banner = banner
        self.labels = labels
        self.joinedViaStarterPack = joinedViaStarterPack
        self.pinnedPost = pinnedPost
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
        website = try container.decodeIfPresent(URI.self, forKey: .website)
        avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)
        banner = try container.decodeIfPresent(Blob.self, forKey: .banner)
        labels = try container.decodeIfPresent(AppBskyActorProfileLabelsUnion.self, forKey: .labels)
        joinedViaStarterPack = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .joinedViaStarterPack)
        pinnedPost = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .pinnedPost)
        createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(pronouns, forKey: .pronouns)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(labels, forKey: .labels)
        try container.encodeIfPresent(joinedViaStarterPack, forKey: .joinedViaStarterPack)
        try container.encodeIfPresent(pinnedPost, forKey: .pinnedPost)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if displayName != other.displayName {
            return false
        }
        if description != other.description {
            return false
        }
        if pronouns != other.pronouns {
            return false
        }
        if website != other.website {
            return false
        }
        if avatar != other.avatar {
            return false
        }
        if banner != other.banner {
            return false
        }
        if labels != other.labels {
            return false
        }
        if joinedViaStarterPack != other.joinedViaStarterPack {
            return false
        }
        if pinnedPost != other.pinnedPost {
            return false
        }
        if createdAt != other.createdAt {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        if let value = displayName {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = description {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = pronouns {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = website {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = avatar {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = banner {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = labels {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = joinedViaStarterPack {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = pinnedPost {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = createdAt {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        if let value = displayName {
            let displayNameValue = try value.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
        }
        if let value = description {
            let descriptionValue = try value.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)
        }
        if let value = pronouns {
            let pronounsValue = try value.toCBORValue()
            map = map.adding(key: "pronouns", value: pronounsValue)
        }
        if let value = website {
            let websiteValue = try value.toCBORValue()
            map = map.adding(key: "website", value: websiteValue)
        }
        if let value = avatar {
            let avatarValue = try value.toCBORValue()
            map = map.adding(key: "avatar", value: avatarValue)
        }
        if let value = banner {
            let bannerValue = try value.toCBORValue()
            map = map.adding(key: "banner", value: bannerValue)
        }
        if let value = labels {
            let labelsValue = try value.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
        }
        if let value = joinedViaStarterPack {
            let joinedViaStarterPackValue = try value.toCBORValue()
            map = map.adding(key: "joinedViaStarterPack", value: joinedViaStarterPackValue)
        }
        if let value = pinnedPost {
            let pinnedPostValue = try value.toCBORValue()
            map = map.adding(key: "pinnedPost", value: pinnedPostValue)
        }
        if let value = createdAt {
            let createdAtValue = try value.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
        }
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case displayName
        case description
        case pronouns
        case website
        case avatar
        case banner
        case labels
        case joinedViaStarterPack
        case pinnedPost
        case createdAt
    }

    public enum AppBskyActorProfileLabelsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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

        public static func == (lhs: AppBskyActorProfileLabelsUnion, rhs: AppBskyActorProfileLabelsUnion) -> Bool {
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
            guard let other = other as? AppBskyActorProfileLabelsUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
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
