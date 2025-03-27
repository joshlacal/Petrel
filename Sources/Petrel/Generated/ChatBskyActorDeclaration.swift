import Foundation

// lexicon: 1, id: chat.bsky.actor.declaration

public struct ChatBskyActorDeclaration: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "chat.bsky.actor.declaration"
    public let allowIncoming: String

    // Standard initializer
    public init(allowIncoming: String) {
        self.allowIncoming = allowIncoming
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        allowIncoming = try container.decode(String.self, forKey: .allowIncoming)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(allowIncoming, forKey: .allowIncoming)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if allowIncoming != other.allowIncoming {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(allowIncoming)
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case allowIncoming
    }

    // MARK: - PendingDataLoadable

    /// Check if any properties contain pending data that needs loading
    public var hasPendingData: Bool {
        var hasPending = false

        if !hasPending, let loadable = allowIncoming as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        return hasPending
    }

    /// Load any pending data in properties
    public mutating func loadPendingData() async {
        if let loadable = allowIncoming as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? String {
                allowIncoming = updatedValue
            }
        }
    }
}
