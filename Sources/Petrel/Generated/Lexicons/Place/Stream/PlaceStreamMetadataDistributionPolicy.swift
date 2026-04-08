import Foundation



// lexicon: 1, id: place.stream.metadata.distributionPolicy


public struct PlaceStreamMetadataDistributionPolicy: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.metadata.distributionPolicy"
        public let deleteAfter: Int?
        public let allowedBroadcasters: [String]?

        public init(deleteAfter: Int?, allowedBroadcasters: [String]?) {
            self.deleteAfter = deleteAfter
            self.allowedBroadcasters = allowedBroadcasters
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.deleteAfter = try container.decodeIfPresent(Int.self, forKey: .deleteAfter)
            self.allowedBroadcasters = try container.decodeIfPresent([String].self, forKey: .allowedBroadcasters)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(deleteAfter, forKey: .deleteAfter)
            try container.encodeIfPresent(allowedBroadcasters, forKey: .allowedBroadcasters)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = deleteAfter {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowedBroadcasters {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if deleteAfter != other.deleteAfter {
                return false
            }
            if allowedBroadcasters != other.allowedBroadcasters {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            if let value = deleteAfter {
                let deleteAfterValue = try value.toCBORValue()
                map = map.adding(key: "deleteAfter", value: deleteAfterValue)
            }
            if let value = allowedBroadcasters {
                let allowedBroadcastersValue = try value.toCBORValue()
                map = map.adding(key: "allowedBroadcasters", value: allowedBroadcastersValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case deleteAfter
            case allowedBroadcasters
        }



}


                           

