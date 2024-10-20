import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.graph.follow


public struct AppBskyGraphFollow: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.graph.follow"
        public let subject: String
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(subject: String, createdAt: ATProtocolDate) {
            
            self.subject = subject
            
            self.createdAt = createdAt
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.subject = try container.decode(String.self, forKey: .subject)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(subject, forKey: .subject)
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
        }
                                            
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.subject != other.subject {
                return false
            }
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            return true
        }
        

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            hasher.combine(createdAt)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case createdAt
        }



}


                           
