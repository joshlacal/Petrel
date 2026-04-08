import Foundation



// lexicon: 1, id: place.stream.moderation.permission


public struct PlaceStreamModerationPermission: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.moderation.permission"
        public let moderator: DID
        public let permissions: [String]
        public let createdAt: ATProtocolDate
        public let expirationTime: ATProtocolDate?

        public init(moderator: DID, permissions: [String], createdAt: ATProtocolDate, expirationTime: ATProtocolDate?) {
            self.moderator = moderator
            self.permissions = permissions
            self.createdAt = createdAt
            self.expirationTime = expirationTime
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.moderator = try container.decode(DID.self, forKey: .moderator)
            self.permissions = try container.decode([String].self, forKey: .permissions)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.expirationTime = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expirationTime)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(moderator, forKey: .moderator)
            try container.encode(permissions, forKey: .permissions)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(expirationTime, forKey: .expirationTime)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if moderator != other.moderator {
                return false
            }
            if permissions != other.permissions {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if expirationTime != other.expirationTime {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(moderator)
            hasher.combine(permissions)
            hasher.combine(createdAt)
            if let value = expirationTime {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let moderatorValue = try moderator.toCBORValue()
            map = map.adding(key: "moderator", value: moderatorValue)
            let permissionsValue = try permissions.toCBORValue()
            map = map.adding(key: "permissions", value: permissionsValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = expirationTime {
                let expirationTimeValue = try value.toCBORValue()
                map = map.adding(key: "expirationTime", value: expirationTimeValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case moderator
            case permissions
            case createdAt
            case expirationTime
        }



}


                           

