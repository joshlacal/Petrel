import Foundation

// lexicon: 1, id: app.bsky.actor.status

public struct AppBskyActorStatus: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.actor.status"
    public let status: String
    public let embed: AppBskyActorStatusEmbedUnion?
    public let durationMinutes: Int?
    public let createdAt: ATProtocolDate

    public init(status: String, embed: AppBskyActorStatusEmbedUnion?, durationMinutes: Int?, createdAt: ATProtocolDate) {
        self.status = status
        self.embed = embed
        self.durationMinutes = durationMinutes
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        embed = try container.decodeIfPresent(AppBskyActorStatusEmbedUnion.self, forKey: .embed)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(embed, forKey: .embed)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if status != other.status {
            return false
        }
        if embed != other.embed {
            return false
        }
        if durationMinutes != other.durationMinutes {
            return false
        }
        if createdAt != other.createdAt {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(status)
        if let value = embed {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = durationMinutes {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        hasher.combine(createdAt)
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        let statusValue = try status.toCBORValue()
        map = map.adding(key: "status", value: statusValue)
        if let value = embed {
            let embedValue = try value.toCBORValue()
            map = map.adding(key: "embed", value: embedValue)
        }
        if let value = durationMinutes {
            let durationMinutesValue = try value.toCBORValue()
            map = map.adding(key: "durationMinutes", value: durationMinutesValue)
        }
        let createdAtValue = try createdAt.toCBORValue()
        map = map.adding(key: "createdAt", value: createdAtValue)
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case status
        case embed
        case durationMinutes
        case createdAt
    }

    public enum AppBskyActorStatusEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyEmbedExternal(AppBskyEmbedExternal)
        case unexpected(ATProtocolValueContainer)
        public init(_ value: AppBskyEmbedExternal) {
            self = .appBskyEmbedExternal(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "app.bsky.embed.external":
                let value = try AppBskyEmbedExternal(from: decoder)
                self = .appBskyEmbedExternal(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .appBskyEmbedExternal(value):
                try container.encode("app.bsky.embed.external", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedExternal(value):
                hasher.combine("app.bsky.embed.external")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: AppBskyActorStatusEmbedUnion, rhs: AppBskyActorStatusEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedExternal(lhsValue),
                .appBskyEmbedExternal(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? AppBskyActorStatusEmbedUnion else { return false }
            return self == other
        }

        /// DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .appBskyEmbedExternal(value):
                map = map.adding(key: "$type", value: "app.bsky.embed.external")

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
