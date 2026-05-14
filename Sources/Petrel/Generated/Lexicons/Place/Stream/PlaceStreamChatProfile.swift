import Foundation



// lexicon: 1, id: place.stream.chat.profile


public struct PlaceStreamChatProfile: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.chat.profile"
        public let color: Color?

        public init(color: Color?) {
            self.color = color
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.color = try container.decodeIfPresent(Color.self, forKey: .color)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(color, forKey: .color)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if color != other.color {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            if let value = color {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            if let value = color {
                let colorValue = try value.toCBORValue()
                map = map.adding(key: "color", value: colorValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case color
        }
        
public struct Color: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.chat.profile#color"
            public let red: Int
            public let green: Int
            public let blue: Int

        public init(
            red: Int, green: Int, blue: Int
        ) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.red = try container.decode(Int.self, forKey: .red)
            } catch {
                LogManager.logError("Decoding error for required property 'red': \(error)")
                throw error
            }
            do {
                self.green = try container.decode(Int.self, forKey: .green)
            } catch {
                LogManager.logError("Decoding error for required property 'green': \(error)")
                throw error
            }
            do {
                self.blue = try container.decode(Int.self, forKey: .blue)
            } catch {
                LogManager.logError("Decoding error for required property 'blue': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(red, forKey: .red)
            try container.encode(green, forKey: .green)
            try container.encode(blue, forKey: .blue)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(red)
            hasher.combine(green)
            hasher.combine(blue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if red != other.red {
                return false
            }
            if green != other.green {
                return false
            }
            if blue != other.blue {
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
            let redValue = try red.toCBORValue()
            map = map.adding(key: "red", value: redValue)
            let greenValue = try green.toCBORValue()
            map = map.adding(key: "green", value: greenValue)
            let blueValue = try blue.toCBORValue()
            map = map.adding(key: "blue", value: blueValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case red
            case green
            case blue
        }
    }



}


                           

