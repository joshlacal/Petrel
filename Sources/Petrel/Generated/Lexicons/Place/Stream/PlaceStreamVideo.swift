import Foundation



// lexicon: 1, id: place.stream.video


public struct PlaceStreamVideo: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.video"
        public let title: String
        public let duration: Int?
        public let createdAt: ATProtocolDate
        public let thumb: Blob?
        public let description: String?

        public init(title: String, duration: Int?, createdAt: ATProtocolDate, thumb: Blob?, description: String?) {
            self.title = title
            self.duration = duration
            self.createdAt = createdAt
            self.thumb = thumb
            self.description = description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decode(String.self, forKey: .title)
            self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.thumb = try container.decodeIfPresent(Blob.self, forKey: .thumb)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(thumb, forKey: .thumb)
            try container.encodeIfPresent(description, forKey: .description)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if title != other.title {
                return false
            }
            if duration != other.duration {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if thumb != other.thumb {
                return false
            }
            if description != other.description {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            if let value = duration {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
            if let value = thumb {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let titleValue = try title.toCBORValue()
            map = map.adding(key: "title", value: titleValue)
            if let value = duration {
                let durationValue = try value.toCBORValue()
                map = map.adding(key: "duration", value: durationValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = thumb {
                let thumbValue = try value.toCBORValue()
                map = map.adding(key: "thumb", value: thumbValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case title
            case duration
            case createdAt
            case thumb
            case description
        }



}


                           

