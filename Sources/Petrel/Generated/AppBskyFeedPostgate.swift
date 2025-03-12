import Foundation

// lexicon: 1, id: app.bsky.feed.postgate

public struct AppBskyFeedPostgate: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.feed.postgate"
    public let createdAt: ATProtocolDate
    public let post: ATProtocolURI
    public let detachedEmbeddingUris: [ATProtocolURI]?
    public let embeddingRules: [AppBskyFeedPostgateEmbeddingRulesUnion]?

    // Standard initializer
    public init(createdAt: ATProtocolDate, post: ATProtocolURI, detachedEmbeddingUris: [ATProtocolURI]?, embeddingRules: [AppBskyFeedPostgateEmbeddingRulesUnion]?) {
        self.createdAt = createdAt

        self.post = post

        self.detachedEmbeddingUris = detachedEmbeddingUris

        self.embeddingRules = embeddingRules
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

        post = try container.decode(ATProtocolURI.self, forKey: .post)

        detachedEmbeddingUris = try container.decodeIfPresent([ATProtocolURI].self, forKey: .detachedEmbeddingUris)

        embeddingRules = try container.decodeIfPresent([AppBskyFeedPostgateEmbeddingRulesUnion].self, forKey: .embeddingRules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(createdAt, forKey: .createdAt)

        try container.encode(post, forKey: .post)

        if let value = detachedEmbeddingUris {
            try container.encode(value, forKey: .detachedEmbeddingUris)
        }

        if let value = embeddingRules {
            try container.encode(value, forKey: .embeddingRules)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if createdAt != other.createdAt {
            return false
        }

        if post != other.post {
            return false
        }

        if detachedEmbeddingUris != other.detachedEmbeddingUris {
            return false
        }

        if embeddingRules != other.embeddingRules {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(createdAt)
        hasher.combine(post)
        if let value = detachedEmbeddingUris {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
        if let value = embeddingRules {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?) // Placeholder for nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case createdAt
        case post
        case detachedEmbeddingUris
        case embeddingRules
    }

    public struct DisableRule: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.postgate#disableRule"

        // Standard initializer
        public init(
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }

    public enum AppBskyFeedPostgateEmbeddingRulesUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case appBskyFeedPostgateDisableRule(AppBskyFeedPostgate.DisableRule)
        case unexpected(ATProtocolValueContainer)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.feed.postgate#disableRule":
                let value = try AppBskyFeedPostgate.DisableRule(from: decoder)
                self = .appBskyFeedPostgateDisableRule(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                try container.encode("app.bsky.feed.postgate#disableRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                hasher.combine("app.bsky.feed.postgate#disableRule")
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
            guard let otherValue = other as? AppBskyFeedPostgateEmbeddingRulesUnion else { return false }

            switch (self, otherValue) {
            case let (
                .appBskyFeedPostgateDisableRule(selfValue),
                .appBskyFeedPostgateDisableRule(otherValue)
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
