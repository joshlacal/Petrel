import Foundation



// lexicon: 1, id: place.stream.key


public struct PlaceStreamKey: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.key"
        public let signingKey: String
        public let createdAt: ATProtocolDate
        public let createdBy: String?

        public init(signingKey: String, createdAt: ATProtocolDate, createdBy: String?) {
            self.signingKey = signingKey
            self.createdAt = createdAt
            self.createdBy = createdBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.signingKey = try container.decode(String.self, forKey: .signingKey)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(signingKey, forKey: .signingKey)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(createdBy, forKey: .createdBy)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if signingKey != other.signingKey {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if createdBy != other.createdBy {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(signingKey)
            hasher.combine(createdAt)
            if let value = createdBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let signingKeyValue = try signingKey.toCBORValue()
            map = map.adding(key: "signingKey", value: signingKeyValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = createdBy {
                let createdByValue = try value.toCBORValue()
                map = map.adding(key: "createdBy", value: createdByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case signingKey
            case createdAt
            case createdBy
        }



}


                           

