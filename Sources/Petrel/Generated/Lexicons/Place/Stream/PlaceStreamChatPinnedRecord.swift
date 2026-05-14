import Foundation



// lexicon: 1, id: place.stream.chat.pinnedRecord


public struct PlaceStreamChatPinnedRecord: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.chat.pinnedRecord"
        public let pinnedMessage: ATProtocolURI
        public let pinnedBy: DID?
        public let createdAt: ATProtocolDate
        public let expiresAt: ATProtocolDate?

        public init(pinnedMessage: ATProtocolURI, pinnedBy: DID?, createdAt: ATProtocolDate, expiresAt: ATProtocolDate?) {
            self.pinnedMessage = pinnedMessage
            self.pinnedBy = pinnedBy
            self.createdAt = createdAt
            self.expiresAt = expiresAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.pinnedMessage = try container.decode(ATProtocolURI.self, forKey: .pinnedMessage)
            self.pinnedBy = try container.decodeIfPresent(DID.self, forKey: .pinnedBy)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(pinnedMessage, forKey: .pinnedMessage)
            try container.encodeIfPresent(pinnedBy, forKey: .pinnedBy)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if pinnedMessage != other.pinnedMessage {
                return false
            }
            if pinnedBy != other.pinnedBy {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if expiresAt != other.expiresAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(pinnedMessage)
            if let value = pinnedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
            if let value = expiresAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let pinnedMessageValue = try pinnedMessage.toCBORValue()
            map = map.adding(key: "pinnedMessage", value: pinnedMessageValue)
            if let value = pinnedBy {
                let pinnedByValue = try value.toCBORValue()
                map = map.adding(key: "pinnedBy", value: pinnedByValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = expiresAt {
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case pinnedMessage
            case pinnedBy
            case createdAt
            case expiresAt
        }



}


                           

