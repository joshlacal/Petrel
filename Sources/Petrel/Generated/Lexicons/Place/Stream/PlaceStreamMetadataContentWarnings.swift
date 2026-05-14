import Foundation



// lexicon: 1, id: place.stream.metadata.contentWarnings


public struct PlaceStreamMetadataContentWarnings: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.metadata.contentWarnings"
        public let warnings: [String]?

        public init(warnings: [String]?) {
            self.warnings = warnings
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.warnings = try container.decodeIfPresent([String].self, forKey: .warnings)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(warnings, forKey: .warnings)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = warnings {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if warnings != other.warnings {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            if let value = warnings {
                let warningsValue = try value.toCBORValue()
                map = map.adding(key: "warnings", value: warningsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case warnings
        }



}


                           

