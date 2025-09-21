import Foundation



// lexicon: 1, id: app.bsky.graph.verification


public struct AppBskyGraphVerification: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.graph.verification"
        public let subject: DID
        public let handle: Handle
        public let displayName: String
        public let createdAt: ATProtocolDate

        // Standard initializer
        public init(subject: DID, handle: Handle, displayName: String, createdAt: ATProtocolDate) {
            
            self.subject = subject
            
            self.handle = handle
            
            self.displayName = displayName
            
            self.createdAt = createdAt
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.subject = try container.decode(DID.self, forKey: .subject)
            
            
            self.handle = try container.decode(Handle.self, forKey: .handle)
            
            
            self.displayName = try container.decode(String.self, forKey: .displayName)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode the $type field
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(subject, forKey: .subject)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(displayName, forKey: .displayName)
            
            
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
            
            
            if self.handle != other.handle {
                return false
            }
            
            
            if self.displayName != other.displayName {
                return false
            }
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            return true
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            hasher.combine(handle)
            hasher.combine(displayName)
            hasher.combine(createdAt)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            let displayNameValue = try displayName.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case handle
            case displayName
            case createdAt
        }



}


                           
