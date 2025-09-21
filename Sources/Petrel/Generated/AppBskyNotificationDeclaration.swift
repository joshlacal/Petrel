import Foundation



// lexicon: 1, id: app.bsky.notification.declaration


public struct AppBskyNotificationDeclaration: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.notification.declaration"
        public let allowSubscriptions: String

        // Standard initializer
        public init(allowSubscriptions: String) {
            
            self.allowSubscriptions = allowSubscriptions
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.allowSubscriptions = try container.decode(String.self, forKey: .allowSubscriptions)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(allowSubscriptions, forKey: .allowSubscriptions)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.allowSubscriptions != other.allowSubscriptions {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(allowSubscriptions)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let allowSubscriptionsValue = try allowSubscriptions.toCBORValue()
            map = map.adding(key: "allowSubscriptions", value: allowSubscriptionsValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowSubscriptions
        }



}


                           
