import Foundation



// lexicon: 1, id: app.bsky.feed.like


public struct AppBskyFeedLike: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.feed.like"
        public let subject: ComAtprotoRepoStrongRef
        public let createdAt: ATProtocolDate
        public let via: ComAtprotoRepoStrongRef?

        // Standard initializer
        public init(subject: ComAtprotoRepoStrongRef, createdAt: ATProtocolDate, via: ComAtprotoRepoStrongRef?) {
            
            self.subject = subject
            
            self.createdAt = createdAt
            
            self.via = via
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.subject = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .subject)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
            
            self.via = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .via)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(subject, forKey: .subject)
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(via, forKey: .via)
            
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
            
            
            if via != other.via {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            hasher.combine(createdAt)
            if let value = via {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?) // Placeholder for nil
            }
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            
            if let value = via {
                // Encode optional property even if it's an empty array for CBOR
                let viaValue = try value.toCBORValue()
                map = map.adding(key: "via", value: viaValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case createdAt
            case via
        }



}


                           
