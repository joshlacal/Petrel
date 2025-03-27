import Foundation

// lexicon: 1, id: app.bsky.feed.like

public struct AppBskyFeedLike: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "app.bsky.feed.like"
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

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case subject
        case createdAt
    }

    // MARK: - PendingDataLoadable

    /// Check if any properties contain pending data that needs loading
    public var hasPendingData: Bool {
        var hasPending = false

        if !hasPending, let loadable = subject as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        if !hasPending, let loadable = createdAt as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        return hasPending
    }

    /// Load any pending data in properties
    public mutating func loadPendingData() async {
        if let loadable = subject as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? ComAtprotoRepoStrongRef {
                subject = updatedValue
            }
        }

        if let loadable = createdAt as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? ATProtocolDate {
                createdAt = updatedValue
            }
        }
    }
}
