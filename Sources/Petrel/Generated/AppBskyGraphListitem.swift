import Foundation
internal import ZippyJSON

// lexicon: 1, id: app.bsky.graph.listitem

public struct AppBskyGraphListitem: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.graph.listitem"
    public let subject: String
    public let list: ATProtocolURI
    public let createdAt: ATProtocolDate

    // Standard initializer
    public init(subject: String, list: ATProtocolURI, createdAt: ATProtocolDate) {
        self.subject = subject

        self.list = list

        self.createdAt = createdAt
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        subject = try container.decode(String.self, forKey: .subject)

        list = try container.decode(ATProtocolURI.self, forKey: .list)

        createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(subject, forKey: .subject)

        try container.encode(list, forKey: .list)

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

        if list != other.list {
            return false
        }

        if createdAt != other.createdAt {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(subject)
        hasher.combine(list)
        hasher.combine(createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case subject
        case list
        case createdAt
    }
}
