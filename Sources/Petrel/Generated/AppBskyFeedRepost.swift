import Foundation

// lexicon: 1, id: app.bsky.feed.repost

public struct AppBskyFeedRepost: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.feed.repost"
    public let subject: ComAtprotoRepoStrongRef
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(subject: ComAtprotoRepoStrongRef, createdAt: ATProtocolDate) {
        self.subject = subject

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        subject = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .subject)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(subject, forKey: .subject)

        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if subject != other.subject {
            return false
        }

        if createdAt != other.createdAt {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(subject)
        hasher.combine(createdAt)
    }

    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        map = map.adding(key: "$type", value: Self.typeIdentifier)

        let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
        map = map.adding(key: "subject", value: subjectValue)

        let createdAtValue = try (createdAt as? DAGCBOREncodable)?.toCBORValue() ?? createdAt
        map = map.adding(key: "createdAt", value: createdAtValue)

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case subject
        case createdAt
    }
}
