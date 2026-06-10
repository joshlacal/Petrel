import Foundation

// lexicon: 1, id: com.atproto.lexicon.schema

public struct ComAtprotoLexiconSchema: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "com.atproto.lexicon.schema"
    public let lexicon: Int

    public init(lexicon: Int) {
        self.lexicon = lexicon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lexicon = try container.decode(Int.self, forKey: .lexicon)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
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

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        let lexiconValue = try lexicon.toCBORValue()
        map = map.adding(key: "lexicon", value: lexiconValue)
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case lexicon
    }
}
