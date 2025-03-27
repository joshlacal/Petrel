import Foundation

// lexicon: 1, id: com.atproto.lexicon.schema

public struct ComAtprotoLexiconSchema: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "com.atproto.lexicon.schema"
    public let lexicon: Int

    // Standard initializer
    public init(lexicon: Int) {
        self.lexicon = lexicon
    }

    // Codable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        lexicon = try container.decode(Int.self, forKey: .lexicon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode the $type field
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

        try container.encode(lexicon, forKey: .lexicon)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }

        if lexicon != other.lexicon {
            return false
        }

        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(lexicon)
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case lexicon
    }

    // MARK: - PendingDataLoadable

    /// Check if any properties contain pending data that needs loading
    public var hasPendingData: Bool {
        var hasPending = false

        if !hasPending, let loadable = lexicon as? PendingDataLoadable {
            hasPending = loadable.hasPendingData
        }

        return hasPending
    }

    /// Load any pending data in properties
    public mutating func loadPendingData() async {
        if let loadable = lexicon as? PendingDataLoadable, loadable.hasPendingData {
            var mutableValue = loadable
            await mutableValue.loadPendingData()
            // Only update if we can safely cast back to the expected type
            if let updatedValue = mutableValue as? Int {
                lexicon = updatedValue
            }
        }
    }
}
