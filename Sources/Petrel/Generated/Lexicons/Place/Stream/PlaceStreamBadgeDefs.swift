import Foundation



// lexicon: 1, id: place.stream.badge.defs


public struct PlaceStreamBadgeDefs { 

    public static let typeIdentifier = "place.stream.badge.defs"
        
public struct BadgeView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.badge.defs#badgeView"
            public let badgeType: String
            public let issuer: DID
            public let recipient: DID
            public let signature: String?

        public init(
            badgeType: String, issuer: DID, recipient: DID, signature: String?
        ) {
            self.badgeType = badgeType
            self.issuer = issuer
            self.recipient = recipient
            self.signature = signature
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.badgeType = try container.decode(String.self, forKey: .badgeType)
            } catch {
                LogManager.logError("Decoding error for required property 'badgeType': \(error)")
                throw error
            }
            do {
                self.issuer = try container.decode(DID.self, forKey: .issuer)
            } catch {
                LogManager.logError("Decoding error for required property 'issuer': \(error)")
                throw error
            }
            do {
                self.recipient = try container.decode(DID.self, forKey: .recipient)
            } catch {
                LogManager.logError("Decoding error for required property 'recipient': \(error)")
                throw error
            }
            do {
                self.signature = try container.decodeIfPresent(String.self, forKey: .signature)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'signature': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(badgeType, forKey: .badgeType)
            try container.encode(issuer, forKey: .issuer)
            try container.encode(recipient, forKey: .recipient)
            try container.encodeIfPresent(signature, forKey: .signature)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(badgeType)
            hasher.combine(issuer)
            hasher.combine(recipient)
            if let value = signature {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if badgeType != other.badgeType {
                return false
            }
            if issuer != other.issuer {
                return false
            }
            if recipient != other.recipient {
                return false
            }
            if signature != other.signature {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let badgeTypeValue = try badgeType.toCBORValue()
            map = map.adding(key: "badgeType", value: badgeTypeValue)
            let issuerValue = try issuer.toCBORValue()
            map = map.adding(key: "issuer", value: issuerValue)
            let recipientValue = try recipient.toCBORValue()
            map = map.adding(key: "recipient", value: recipientValue)
            if let value = signature {
                let signatureValue = try value.toCBORValue()
                map = map.adding(key: "signature", value: signatureValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case badgeType
            case issuer
            case recipient
            case signature
        }
    }



}


                           

