import Foundation



// lexicon: 1, id: place.stream.broadcast.syndication


public struct PlaceStreamBroadcastSyndication: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.broadcast.syndication"
        public let broadcaster: DID
        public let streamer: DID
        public let createdAt: ATProtocolDate

        public init(broadcaster: DID, streamer: DID, createdAt: ATProtocolDate) {
            self.broadcaster = broadcaster
            self.streamer = streamer
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.broadcaster = try container.decode(DID.self, forKey: .broadcaster)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(broadcaster, forKey: .broadcaster)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if broadcaster != other.broadcaster {
                return false
            }
            if streamer != other.streamer {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(broadcaster)
            hasher.combine(streamer)
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let broadcasterValue = try broadcaster.toCBORValue()
            map = map.adding(key: "broadcaster", value: broadcasterValue)
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case broadcaster
            case streamer
            case createdAt
        }



}


                           

