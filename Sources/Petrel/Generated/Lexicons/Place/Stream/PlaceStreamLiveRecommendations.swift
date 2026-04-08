import Foundation



// lexicon: 1, id: place.stream.live.recommendations


public struct PlaceStreamLiveRecommendations: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.live.recommendations"
        public let streamers: [DID]
        public let createdAt: ATProtocolDate

        public init(streamers: [DID], createdAt: ATProtocolDate) {
            self.streamers = streamers
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamers = try container.decode([DID].self, forKey: .streamers)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(streamers, forKey: .streamers)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if streamers != other.streamers {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(streamers)
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let streamersValue = try streamers.toCBORValue()
            map = map.adding(key: "streamers", value: streamersValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case streamers
            case createdAt
        }



}


                           

