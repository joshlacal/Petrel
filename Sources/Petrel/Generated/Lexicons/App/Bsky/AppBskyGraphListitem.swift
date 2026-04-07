import Foundation



// lexicon: 1, id: app.bsky.graph.listitem


public struct AppBskyGraphListitem: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "app.bsky.graph.listitem"
        public let subject: DID
        public let list: ATProtocolURI
        public let createdAt: ATProtocolDate

        public init(subject: DID, list: ATProtocolURI, createdAt: ATProtocolDate) {
            self.subject = subject
            self.list = list
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.subject = try container.decode(DID.self, forKey: .subject)
            self.list = try container.decode(ATProtocolURI.self, forKey: .list)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(subject, forKey: .subject)
            try container.encode(list, forKey: .list)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if subject != other.subject {
                return false
            }
            if list != other.list {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(subject)
            hasher.combine(list)
            hasher.combine(createdAt)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let subjectValue = try subject.toCBORValue()
            map = map.adding(key: "subject", value: subjectValue)
            let listValue = try list.toCBORValue()
            map = map.adding(key: "list", value: listValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case subject
            case list
            case createdAt
        }



}


                           

