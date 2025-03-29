import Foundation



// lexicon: 1, id: tools.ozone.signature.defs


public struct ToolsOzoneSignatureDefs { 

    public static let typeIdentifier = "tools.ozone.signature.defs"
        
public struct SigDetail: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "tools.ozone.signature.defs#sigDetail"
            public let property: String
            public let value: String

        // Standard initializer
        public init(
            property: String, value: String
        ) {
            
            self.property = property
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.property = try container.decode(String.self, forKey: .property)
                
            } catch {
                LogManager.logError("Decoding error for property 'property': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(String.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(property, forKey: .property)
            
            
            try container.encode(value, forKey: .value)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(property)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.property != other.property {
                return false
            }
            
            
            if self.value != other.value {
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
            
            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            
            // Add remaining fields in lexicon-defined order
            
            
            
            let propertyValue = try (property as? DAGCBOREncodable)?.toCBORValue() ?? property
            map = map.adding(key: "property", value: propertyValue)
            
            
            
            
            let valueValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
            map = map.adding(key: "value", value: valueValue)
            
            
            
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case property
            case value
        }
    }



}


                           
