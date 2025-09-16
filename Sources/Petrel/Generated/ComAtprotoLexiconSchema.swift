import Foundation



// lexicon: 1, id: com.atproto.lexicon.schema


public struct ComAtprotoLexiconSchema: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "com.atproto.lexicon.schema"
        public let lexicon: Int

        // Standard initializer
        public init(lexicon: Int) {
            
            self.lexicon = lexicon
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.lexicon = try container.decode(Int.self, forKey: .lexicon)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(lexicon, forKey: .lexicon)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.lexicon != other.lexicon {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(lexicon)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let lexiconValue = try lexicon.toCBORValue()
            map = map.adding(key: "lexicon", value: lexiconValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lexicon
        }



}


                           
