import Foundation

// lexicon: 1, id: com.atproto.repo.strongRef

public struct ComAtprotoRepoStrongRef: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "com.atproto.repo.strongRef"
    public let uri: ATProtocolURI
    public let cid: CID

    public init(uri: ATProtocolURI, cid: CID) {
        self.uri = uri
        self.cid = cid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uri = try container.decode(ATProtocolURI.self, forKey: .uri)

        cid = try container.decode(CID.self, forKey: .cid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uri, forKey: .uri)

        try container.encode(cid, forKey: .cid)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
        hasher.combine(cid)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if uri != other.uri {
            return false
        }
        if cid != other.cid {
            return false
        }
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    /// DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        let uriValue = try uri.toCBORValue()
        map = map.adding(key: "uri", value: uriValue)

        let cidValue = try cid.toCBORValue()
        map = map.adding(key: "cid", value: cidValue)

        return map
    }

    private enum CodingKeys: String, CodingKey {
        case uri
        case cid
    }
}
