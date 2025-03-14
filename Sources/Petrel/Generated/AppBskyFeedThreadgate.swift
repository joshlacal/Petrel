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

        post = try container.decode(ATProtocolURI.self, forKey: .post)

        allow = try container.decodeIfPresent([AppBskyFeedThreadgateAllowUnion].self, forKey: .allow)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

        hiddenReplies = try container.decodeIfPresent([ATProtocolURI].self, forKey: .hiddenReplies)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(post, forKey: .post)

        if let value = allow {
            try container.encode(value, forKey: .allow)
        }

        try container.encode(createdAt, forKey: .createdAt)

        if let value = hiddenReplies {
            try container.encode(value, forKey: .hiddenReplies)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if post != other.post {
            return false
        }

        if allow != other.allow {
            return false
        }

        if createdAt != other.createdAt {
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
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct FollowerRule: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.threadgate#followerRule"

        // Standard initializer
        public init(
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public struct FollowingRule: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.threadgate#followingRule"

        // Standard initializer
        public init(
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
                list = try container.decode(ATProtocolURI.self, forKey: .list)

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

            if list != other.list {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case list
        }
    }

    public enum AppBskyFeedThreadgateAllowUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, PendingDataLoadable, Equatable {
        case appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule)
        case appBskyFeedThreadgateFollowerRule(AppBskyFeedThreadgate.FollowerRule)
        case appBskyFeedThreadgateFollowingRule(AppBskyFeedThreadgate.FollowingRule)
        case appBskyFeedThreadgateListRule(AppBskyFeedThreadgate.ListRule)
        case unexpected(ATProtocolValueContainer)

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
            case let .appBskyFeedThreadgateMentionRule(value):
                try container.encode("app.bsky.feed.threadgate#mentionRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowerRule(value):
                try container.encode("app.bsky.feed.threadgate#followerRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowingRule(value):
                try container.encode("app.bsky.feed.threadgate#followingRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateListRule(value):
                try container.encode("app.bsky.feed.threadgate#listRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                hasher.combine("app.bsky.feed.threadgate#mentionRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowerRule(value):
                hasher.combine("app.bsky.feed.threadgate#followerRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowingRule(value):
                hasher.combine("app.bsky.feed.threadgate#followingRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateListRule(value):
                hasher.combine("app.bsky.feed.threadgate#listRule")
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

        public static func == (lhs: AppBskyFeedThreadgateAllowUnion, rhs: AppBskyFeedThreadgateAllowUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedThreadgateMentionRule(lhsValue),
                .appBskyFeedThreadgateMentionRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowerRule(lhsValue),
                .appBskyFeedThreadgateFollowerRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowingRule(lhsValue),
                .appBskyFeedThreadgateFollowingRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateListRule(lhsValue),
                .appBskyFeedThreadgateListRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard other is AppBskyFeedThreadgateAllowUnion else { return false }
            return self == (other as! AppBskyFeedThreadgateAllowUnion)
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedThreadgateFollowerRule(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedThreadgateFollowingRule(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case let .appBskyFeedThreadgateListRule(value):
                if let loadable = value as? PendingDataLoadable {
                    return loadable.hasPendingData
                }
                return false
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedThreadgate.MentionRule.self, from: jsonData)
                    {
                        self = .appBskyFeedThreadgateMentionRule(decodedValue)
                    }
                }
            case let .appBskyFeedThreadgateFollowerRule(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedThreadgate.FollowerRule.self, from: jsonData)
                    {
                        self = .appBskyFeedThreadgateFollowerRule(decodedValue)
                    }
                }
            case let .appBskyFeedThreadgateFollowingRule(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedThreadgate.FollowingRule.self, from: jsonData)
                    {
                        self = .appBskyFeedThreadgateFollowingRule(decodedValue)
                    }
                }
            case let .appBskyFeedThreadgateListRule(value):
                // Check if this value conforms to PendingDataLoadable and has pending data
                if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                    // Create a new decoded value from scratch if possible
                    if let jsonData = try? JSONEncoder().encode(value),
                       let decodedValue = try? await SafeDecoder.decode(AppBskyFeedThreadgate.ListRule.self, from: jsonData)
                    {
                        self = .appBskyFeedThreadgateListRule(decodedValue)
                    }
                }
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
