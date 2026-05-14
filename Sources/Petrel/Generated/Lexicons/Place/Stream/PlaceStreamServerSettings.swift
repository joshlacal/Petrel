import Foundation



// lexicon: 1, id: place.stream.server.settings


public struct PlaceStreamServerSettings: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.server.settings"
        public let debugRecording: Bool?

        public init(debugRecording: Bool?) {
            self.debugRecording = debugRecording
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.debugRecording = try container.decodeIfPresent(Bool.self, forKey: .debugRecording)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(debugRecording, forKey: .debugRecording)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if debugRecording != other.debugRecording {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            if let value = debugRecording {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            if let value = debugRecording {
                let debugRecordingValue = try value.toCBORValue()
                map = map.adding(key: "debugRecording", value: debugRecordingValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case debugRecording
        }



}


                           

