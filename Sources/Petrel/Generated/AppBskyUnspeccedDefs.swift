import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.unspecced.defs


public struct AppBskyUnspeccedDefs { 

    public static let typeIdentifier = "app.bsky.unspecced.defs"
        
public struct SkeletonSearchPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonSearchPost"
            public let uri: ATProtocolURI

        // Standard initializer
        public init(
            uri: ATProtocolURI
        ) {
            
            self.uri = uri
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
        }
    }
        
public struct SkeletonSearchActor: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.unspecced.defs#skeletonSearchActor"
            public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }



}


                           
