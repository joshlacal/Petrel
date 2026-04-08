import Foundation



// lexicon: 1, id: place.stream.ingest.defs


public struct PlaceStreamIngestDefs { 

    public static let typeIdentifier = "place.stream.ingest.defs"
        
public struct Ingest: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.ingest.defs#ingest"
            public let type: String
            public let url: URI

        public init(
            type: String, url: URI
        ) {
            self.type = type
            self.url = url
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.type = try container.decode(String.self, forKey: .type)
            } catch {
                LogManager.logError("Decoding error for required property 'type': \(error)")
                throw error
            }
            do {
                self.url = try container.decode(URI.self, forKey: .url)
            } catch {
                LogManager.logError("Decoding error for required property 'url': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(type, forKey: .type)
            try container.encode(url, forKey: .url)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(type)
            hasher.combine(url)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if type != other.type {
                return false
            }
            if url != other.url {
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
            let typeValue = try type.toCBORValue()
            map = map.adding(key: "type", value: typeValue)
            let urlValue = try url.toCBORValue()
            map = map.adding(key: "url", value: urlValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case type
            case url
        }
    }



}


                           

