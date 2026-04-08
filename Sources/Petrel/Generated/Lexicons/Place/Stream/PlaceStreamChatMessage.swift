import Foundation



// lexicon: 1, id: place.stream.chat.message


public struct PlaceStreamChatMessage: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "place.stream.chat.message"
        public let text: String
        public let createdAt: ATProtocolDate
        public let facets: [PlaceStreamRichtextFacet]?
        public let streamer: DID
        public let reply: ReplyRef?

        public init(text: String, createdAt: ATProtocolDate, facets: [PlaceStreamRichtextFacet]?, streamer: DID, reply: ReplyRef?) {
            self.text = text
            self.createdAt = createdAt
            self.facets = facets
            self.streamer = streamer
            self.reply = reply
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.text = try container.decode(String.self, forKey: .text)
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            self.facets = try container.decodeIfPresent([PlaceStreamRichtextFacet].self, forKey: .facets)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.reply = try container.decodeIfPresent(ReplyRef.self, forKey: .reply)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(text, forKey: .text)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(facets, forKey: .facets)
            try container.encode(streamer, forKey: .streamer)
            try container.encodeIfPresent(reply, forKey: .reply)
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if text != other.text {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if facets != other.facets {
                return false
            }
            if streamer != other.streamer {
                return false
            }
            if reply != other.reply {
                return false
            }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(createdAt)
            if let value = facets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(streamer)
            if let value = reply {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let textValue = try text.toCBORValue()
            map = map.adding(key: "text", value: textValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = facets {
                let facetsValue = try value.toCBORValue()
                map = map.adding(key: "facets", value: facetsValue)
            }
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            if let value = reply {
                let replyValue = try value.toCBORValue()
                map = map.adding(key: "reply", value: replyValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case text
            case createdAt
            case facets
            case streamer
            case reply
        }
        
public struct ReplyRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.chat.message#replyRef"
            public let root: ComAtprotoRepoStrongRef
            public let parent: ComAtprotoRepoStrongRef

        public init(
            root: ComAtprotoRepoStrongRef, parent: ComAtprotoRepoStrongRef
        ) {
            self.root = root
            self.parent = parent
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.root = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .root)
            } catch {
                LogManager.logError("Decoding error for required property 'root': \(error)")
                throw error
            }
            do {
                self.parent = try container.decode(ComAtprotoRepoStrongRef.self, forKey: .parent)
            } catch {
                LogManager.logError("Decoding error for required property 'parent': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(root, forKey: .root)
            try container.encode(parent, forKey: .parent)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(root)
            hasher.combine(parent)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if root != other.root {
                return false
            }
            if parent != other.parent {
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
            let rootValue = try root.toCBORValue()
            map = map.adding(key: "root", value: rootValue)
            let parentValue = try parent.toCBORValue()
            map = map.adding(key: "parent", value: parentValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case root
            case parent
        }
    }



}


                           

