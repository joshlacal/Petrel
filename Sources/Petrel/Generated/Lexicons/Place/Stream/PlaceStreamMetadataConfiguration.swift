import Foundation

// lexicon: 1, id: place.stream.metadata.configuration

public struct PlaceStreamMetadataConfiguration: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "place.stream.metadata.configuration"
    public let contentWarnings: PlaceStreamMetadataContentWarnings?
    public let contentRights: PlaceStreamMetadataContentRights?
    public let distributionPolicy: PlaceStreamMetadataDistributionPolicy?

    public init(contentWarnings: PlaceStreamMetadataContentWarnings?, contentRights: PlaceStreamMetadataContentRights?, distributionPolicy: PlaceStreamMetadataDistributionPolicy?) {
        self.contentWarnings = contentWarnings
        self.contentRights = contentRights
        self.distributionPolicy = distributionPolicy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            contentWarnings = try container.decodeIfPresent(PlaceStreamMetadataContentWarnings.self, forKey: .contentWarnings)
        } catch {
            // Forward compatibility: a malformed optional field must not fail the whole record.
            LogManager.logWarning("Decoding error for optional property 'contentWarnings' — degrading to nil: \(error)")
            contentWarnings = nil
        }
        do {
            contentRights = try container.decodeIfPresent(PlaceStreamMetadataContentRights.self, forKey: .contentRights)
        } catch {
            // Forward compatibility: a malformed optional field must not fail the whole record.
            LogManager.logWarning("Decoding error for optional property 'contentRights' — degrading to nil: \(error)")
            contentRights = nil
        }
        do {
            distributionPolicy = try container.decodeIfPresent(PlaceStreamMetadataDistributionPolicy.self, forKey: .distributionPolicy)
        } catch {
            // Forward compatibility: a malformed optional field must not fail the whole record.
            LogManager.logWarning("Decoding error for optional property 'distributionPolicy' — degrading to nil: \(error)")
            distributionPolicy = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        try container.encodeIfPresent(contentWarnings, forKey: .contentWarnings)
        try container.encodeIfPresent(contentRights, forKey: .contentRights)
        try container.encodeIfPresent(distributionPolicy, forKey: .distributionPolicy)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        if contentWarnings != other.contentWarnings {
            return false
        }
        if contentRights != other.contentRights {
            return false
        }
        if distributionPolicy != other.distributionPolicy {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        if let value = contentWarnings {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = contentRights {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
        if let value = distributionPolicy {
            hasher.combine(value)
        } else {
            hasher.combine(nil as Int?)
        }
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        if let value = contentWarnings {
            let contentWarningsValue = try value.toCBORValue()
            map = map.adding(key: "contentWarnings", value: contentWarningsValue)
        }
        if let value = contentRights {
            let contentRightsValue = try value.toCBORValue()
            map = map.adding(key: "contentRights", value: contentRightsValue)
        }
        if let value = distributionPolicy {
            let distributionPolicyValue = try value.toCBORValue()
            map = map.adding(key: "distributionPolicy", value: distributionPolicyValue)
        }
        return map
    }

    private enum CodingKeys: String, CodingKey {
        case typeIdentifier = "$type"
        case contentWarnings
        case contentRights
        case distributionPolicy
    }
}
