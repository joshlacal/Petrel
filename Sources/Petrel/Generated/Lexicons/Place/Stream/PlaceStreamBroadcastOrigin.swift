import Foundation



// lexicon: 1, id: place.stream.broadcast.origin


public struct PlaceStreamBroadcastOrigin: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.broadcast.origin"
        public let streamer: DID
        public let server: DID
        public let broadcaster: DID?
        public let updatedAt: ATProtocolDate
        public let irohTicket: String?
        public let websocketURL: URI?

        public init(streamer: DID, server: DID, broadcaster: DID?, updatedAt: ATProtocolDate, irohTicket: String?, websocketURL: URI?) {
            self.streamer = streamer
            self.server = server
            self.broadcaster = broadcaster
            self.updatedAt = updatedAt
            self.irohTicket = irohTicket
            self.websocketURL = websocketURL
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.server = try container.decode(DID.self, forKey: .server)
            self.broadcaster = try container.decodeIfPresent(DID.self, forKey: .broadcaster)
            self.updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)
            self.irohTicket = try container.decodeIfPresent(String.self, forKey: .irohTicket)
            self.websocketURL = try container.decodeIfPresent(URI.self, forKey: .websocketURL)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(streamer, forKey: .streamer)
            try container.encode(server, forKey: .server)
            try container.encodeIfPresent(broadcaster, forKey: .broadcaster)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(irohTicket, forKey: .irohTicket)
            try container.encodeIfPresent(websocketURL, forKey: .websocketURL)
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
            if broadcaster != other.broadcaster {
                return false
            }
            if updatedAt != other.updatedAt {
                return false
            }
            if irohTicket != other.irohTicket {
                return false
            }
            if websocketURL != other.websocketURL {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(streamer)
            hasher.combine(server)
            if let value = broadcaster {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(updatedAt)
            if let value = irohTicket {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = websocketURL {
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
            if let value = broadcaster {
                let broadcasterValue = try value.toCBORValue()
                map = map.adding(key: "broadcaster", value: broadcasterValue)
            }
            let updatedAtValue = try updatedAt.toCBORValue()
            map = map.adding(key: "updatedAt", value: updatedAtValue)
            if let value = irohTicket {
                let irohTicketValue = try value.toCBORValue()
                map = map.adding(key: "irohTicket", value: irohTicketValue)
            }
            if let value = websocketURL {
                let websocketURLValue = try value.toCBORValue()
                map = map.adding(key: "websocketURL", value: websocketURLValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case streamer
            case server
            case broadcaster
            case updatedAt
            case irohTicket
            case websocketURL
        }



}


                           

