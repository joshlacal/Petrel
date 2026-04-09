import Foundation



// lexicon: 1, id: place.stream.muxl.defs


public struct PlaceStreamMuxlDefs { 

    public static let typeIdentifier = "place.stream.muxl.defs"
        
public struct Track: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.muxl.defs#track"
            public let id: Int
            public let codec: String
            public let width: Int?
            public let height: Int?
            public let rate: Int?
            public let channels: Int?

        public init(
            id: Int, codec: String, width: Int?, height: Int?, rate: Int?, channels: Int?
        ) {
            self.id = id
            self.codec = codec
            self.width = width
            self.height = height
            self.rate = rate
            self.channels = channels
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.id = try container.decode(Int.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                self.codec = try container.decode(String.self, forKey: .codec)
            } catch {
                LogManager.logError("Decoding error for required property 'codec': \(error)")
                throw error
            }
            do {
                self.width = try container.decodeIfPresent(Int.self, forKey: .width)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'width': \(error)")
                throw error
            }
            do {
                self.height = try container.decodeIfPresent(Int.self, forKey: .height)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'height': \(error)")
                throw error
            }
            do {
                self.rate = try container.decodeIfPresent(Int.self, forKey: .rate)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'rate': \(error)")
                throw error
            }
            do {
                self.channels = try container.decodeIfPresent(Int.self, forKey: .channels)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'channels': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(codec, forKey: .codec)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
            try container.encodeIfPresent(rate, forKey: .rate)
            try container.encodeIfPresent(channels, forKey: .channels)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(codec)
            if let value = width {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = height {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = rate {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = channels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if codec != other.codec {
                return false
            }
            if width != other.width {
                return false
            }
            if height != other.height {
                return false
            }
            if rate != other.rate {
                return false
            }
            if channels != other.channels {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let codecValue = try codec.toCBORValue()
            map = map.adding(key: "codec", value: codecValue)
            if let value = width {
                let widthValue = try value.toCBORValue()
                map = map.adding(key: "width", value: widthValue)
            }
            if let value = height {
                let heightValue = try value.toCBORValue()
                map = map.adding(key: "height", value: heightValue)
            }
            if let value = rate {
                let rateValue = try value.toCBORValue()
                map = map.adding(key: "rate", value: rateValue)
            }
            if let value = channels {
                let channelsValue = try value.toCBORValue()
                map = map.adding(key: "channels", value: channelsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case codec
            case width
            case height
            case rate
            case channels
        }
    }



}


                           

