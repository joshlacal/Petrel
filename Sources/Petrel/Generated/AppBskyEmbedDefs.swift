import Foundation



// lexicon: 1, id: app.bsky.embed.defs


public struct AppBskyEmbedDefs { 

    public static let typeIdentifier = "app.bsky.embed.defs"
        
public struct AspectRatio: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.embed.defs#aspectRatio"
            public let width: Int
            public let height: Int

        // Standard initializer
        public init(
            width: Int, height: Int
        ) {
            
            self.width = width
            self.height = height
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.width = try container.decode(Int.self, forKey: .width)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'width': \(error)")
                
                throw error
            }
            do {
                
                self.height = try container.decode(Int.self, forKey: .height)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'height': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(width, forKey: .width)
            
            
            try container.encode(height, forKey: .height)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.width != other.width {
                return false
            }
            
            
            if self.height != other.height {
                return false
            }
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let widthValue = try width.toCBORValue()
            map = map.adding(key: "width", value: widthValue)
            
            
            
            
            let heightValue = try height.toCBORValue()
            map = map.adding(key: "height", value: heightValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case width
            case height
        }
    }



}


                           
