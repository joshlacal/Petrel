import Foundation

// lexicon: 1, id: app.bsky.actor.profile

public struct AppBskyActorProfile: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.actor.profile"
    public let displayName: String?
    public let description: String?
    public let avatar: Blob?
    public let banner: Blob?
    public let labels: AppBskyActorProfileLabelsUnion?
    public let joinedViaStarterPack: ComAtprotoRepoStrongRef?
    public let pinnedPost: ComAtprotoRepoStrongRef?
    public let createdAt: ATProtocolDate?

    // Standard initializer
    public init(displayName: String?, description: String?, avatar: Blob?, banner: Blob?, labels: AppBskyActorProfileLabelsUnion?, joinedViaStarterPack: ComAtprotoRepoStrongRef?, pinnedPost: ComAtprotoRepoStrongRef?, createdAt: ATProtocolDate?) {
        self.displayName = displayName

        self.description = description

        self.avatar = avatar

        self.banner = banner

        self.labels = labels

        self.joinedViaStarterPack = joinedViaStarterPack

        self.pinnedPost = pinnedPost

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)

        description = try container.decodeIfPresent(String.self, forKey: .description)

        avatar = try container.decodeIfPresent(Blob.self, forKey: .avatar)

        banner = try container.decodeIfPresent(Blob.self, forKey: .banner)

        labels = try container.decodeIfPresent(AppBskyActorProfileLabelsUnion.self, forKey: .labels)

        joinedViaStarterPack = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .joinedViaStarterPack)

        pinnedPost = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .pinnedPost)

        createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(displayName, forKey: .displayName)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(description, forKey: .description)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(avatar, forKey: .avatar)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(banner, forKey: .banner)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(labels, forKey: .labels)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(joinedViaStarterPack, forKey: .joinedViaStarterPack)

        // Encode optional property even if it's an empty array
        try container.encodeIfPresent(pinnedPost, forKey: .pinnedPost)

        // Encode optional property even if it's an empty array
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
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = description {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = avatar {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = banner {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = labels {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = joinedViaStarterPack {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = pinnedPost {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = createdAt {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
    }

    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        map = map.adding(key: "$type", value: Self.typeIdentifier)

        if let value = displayName {
            // Encode optional property even if it's an empty array for CBOR
            let displayNameValue = try value.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
        }

        if let value = description {
            // Encode optional property even if it's an empty array for CBOR
            let descriptionValue = try value.toCBORValue()
            map = map.adding(key: "description", value: descriptionValue)
        }

        if let value = avatar {
            // Encode optional property even if it's an empty array for CBOR
            let avatarValue = try value.toCBORValue()
            map = map.adding(key: "avatar", value: avatarValue)
        }

        if let value = banner {
            // Encode optional property even if it's an empty array for CBOR
            let bannerValue = try value.toCBORValue()
            map = map.adding(key: "banner", value: bannerValue)
        }

        if let value = labels {
            // Encode optional property even if it's an empty array for CBOR
            let labelsValue = try value.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
        }

        if let value = joinedViaStarterPack {
            // Encode optional property even if it's an empty array for CBOR
            let joinedViaStarterPackValue = try value.toCBORValue()
            map = map.adding(key: "joinedViaStarterPack", value: joinedViaStarterPackValue)
        }

        if let value = pinnedPost {
            // Encode optional property even if it's an empty array for CBOR
            let pinnedPostValue = try value.toCBORValue()
            map = map.adding(key: "pinnedPost", value: pinnedPostValue)
        }

        if let value = createdAt {
            // Encode optional property even if it's an empty array for CBOR
            let createdAtValue = try value.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
        }

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case displayName
        case description
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

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .comAtprotoLabelDefsSelfLabels(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .comAtprotoLabelDefsSelfLabels(value):
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
