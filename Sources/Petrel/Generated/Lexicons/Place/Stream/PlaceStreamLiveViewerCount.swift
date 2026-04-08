import Foundation



// lexicon: 1, id: place.stream.live.viewerCount


public struct PlaceStreamLiveViewerCount: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.live.viewerCount"
        public let streamer: DID
        public let server: DID
        public let count: Int
        public let updatedAt: ATProtocolDate?

        public init(streamer: DID, server: DID, count: Int, updatedAt: ATProtocolDate?) {
            self.streamer = streamer
            self.server = server
            self.count = count
            self.updatedAt = updatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.server = try container.decode(DID.self, forKey: .server)
            self.count = try container.decode(Int.self, forKey: .count)
            self.updatedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .updatedAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(server, forKey: .server)
            try container.encode(count, forKey: .count)
            try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if streamer != other.streamer {
                return false
            }
            if server != other.server {
                return false
            }
            if count != other.count {
                return false
            }
            if updatedAt != other.updatedAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(streamer)
            hasher.combine(server)
            hasher.combine(count)
            if let value = updatedAt {
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
            let serverValue = try server.toCBORValue()
            map = map.adding(key: "server", value: serverValue)
            let countValue = try count.toCBORValue()
            map = map.adding(key: "count", value: countValue)
            if let value = updatedAt {
                let updatedAtValue = try value.toCBORValue()
                map = map.adding(key: "updatedAt", value: updatedAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case streamer
            case server
            case count
            case updatedAt
        }



}


                           

