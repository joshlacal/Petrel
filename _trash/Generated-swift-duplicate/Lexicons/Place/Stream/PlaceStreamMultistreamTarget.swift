import Foundation



// lexicon: 1, id: place.stream.multistream.target


public struct PlaceStreamMultistreamTarget: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.multistream.target"
        public let url: URI
        public let active: Bool
        public let createdAt: ATProtocolDate
        public let name: String?

        public init(url: URI, active: Bool, createdAt: ATProtocolDate, name: String?) {
            self.url = url
            self.active = active
            self.createdAt = createdAt
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.url = try container.decode(URI.self, forKey: .url)
            self.active = try container.decode(Bool.self, forKey: .active)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(url, forKey: .url)
            try container.encode(active, forKey: .active)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(name, forKey: .name)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if url != other.url {
                return false
            }
            if active != other.active {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if name != other.name {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(active)
            hasher.combine(createdAt)
            if let value = name {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let urlValue = try url.toCBORValue()
            map = map.adding(key: "url", value: urlValue)
            let activeValue = try active.toCBORValue()
            map = map.adding(key: "active", value: activeValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case url
            case active
            case createdAt
            case name
        }



}


                           

