import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.policy


public struct BlueCatbirdMlsChatPolicy: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "blue.catbird.mlsChat.policy"
        public let whoCanMessageMe: String?
        public let allowFollowersBypass: Bool?
        public let allowFollowingBypass: Bool?
        public let autoExpireDays: Int?
        public let createdAt: ATProtocolDate

        public init(whoCanMessageMe: String?, allowFollowersBypass: Bool?, allowFollowingBypass: Bool?, autoExpireDays: Int?, createdAt: ATProtocolDate) {
            self.whoCanMessageMe = whoCanMessageMe
            self.allowFollowersBypass = allowFollowersBypass
            self.allowFollowingBypass = allowFollowingBypass
            self.autoExpireDays = autoExpireDays
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.whoCanMessageMe = try container.decodeIfPresent(String.self, forKey: .whoCanMessageMe)
            self.allowFollowersBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowersBypass)
            self.allowFollowingBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowingBypass)
            self.autoExpireDays = try container.decodeIfPresent(Int.self, forKey: .autoExpireDays)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(whoCanMessageMe, forKey: .whoCanMessageMe)
            try container.encodeIfPresent(allowFollowersBypass, forKey: .allowFollowersBypass)
            try container.encodeIfPresent(allowFollowingBypass, forKey: .allowFollowingBypass)
            try container.encodeIfPresent(autoExpireDays, forKey: .autoExpireDays)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if whoCanMessageMe != other.whoCanMessageMe {
                return false
            }
            if allowFollowersBypass != other.allowFollowersBypass {
                return false
            }
            if allowFollowingBypass != other.allowFollowingBypass {
                return false
            }
            if autoExpireDays != other.autoExpireDays {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            if let value = whoCanMessageMe {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowFollowersBypass {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowFollowingBypass {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = autoExpireDays {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            if let value = whoCanMessageMe {
                let whoCanMessageMeValue = try value.toCBORValue()
                map = map.adding(key: "whoCanMessageMe", value: whoCanMessageMeValue)
            }
            if let value = allowFollowersBypass {
                let allowFollowersBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)
            }
            if let value = allowFollowingBypass {
                let allowFollowingBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)
            }
            if let value = autoExpireDays {
                let autoExpireDaysValue = try value.toCBORValue()
                map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case whoCanMessageMe
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
            case createdAt
        }



}


                           

