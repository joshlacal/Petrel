import Foundation



// lexicon: 1, id: place.stream.live.teleport


public struct PlaceStreamLiveTeleport: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.live.teleport"
        public let streamer: DID
        public let startsAt: ATProtocolDate
        public let durationSeconds: Int?

        public init(streamer: DID, startsAt: ATProtocolDate, durationSeconds: Int?) {
            self.streamer = streamer
            self.startsAt = startsAt
            self.durationSeconds = durationSeconds
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.startsAt = try container.decode(ATProtocolDate.self, forKey: .startsAt)
            self.durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(startsAt, forKey: .startsAt)
            try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if streamer != other.streamer {
                return false
            }
            if startsAt != other.startsAt {
                return false
            }
            if durationSeconds != other.durationSeconds {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(streamer)
            hasher.combine(startsAt)
            if let value = durationSeconds {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            let startsAtValue = try startsAt.toCBORValue()
            map = map.adding(key: "startsAt", value: startsAtValue)
            if let value = durationSeconds {
                let durationSecondsValue = try value.toCBORValue()
                map = map.adding(key: "durationSeconds", value: durationSecondsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case streamer
            case startsAt
            case durationSeconds
        }



}


                           

