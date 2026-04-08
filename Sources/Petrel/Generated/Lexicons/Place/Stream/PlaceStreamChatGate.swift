import Foundation



// lexicon: 1, id: place.stream.chat.gate


public struct PlaceStreamChatGate: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.chat.gate"
        public let hiddenMessage: ATProtocolURI

        public init(hiddenMessage: ATProtocolURI) {
            self.hiddenMessage = hiddenMessage
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hiddenMessage = try container.decode(ATProtocolURI.self, forKey: .hiddenMessage)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(hiddenMessage, forKey: .hiddenMessage)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if hiddenMessage != other.hiddenMessage {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(hiddenMessage)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let hiddenMessageValue = try hiddenMessage.toCBORValue()
            map = map.adding(key: "hiddenMessage", value: hiddenMessageValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case hiddenMessage
        }



}


                           

