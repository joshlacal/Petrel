import Foundation



// lexicon: 1, id: place.stream.broadcast.defs


public struct PlaceStreamBroadcastDefs { 

    public static let typeIdentifier = "place.stream.broadcast.defs"
        
public struct BroadcastOriginView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.broadcast.defs#broadcastOriginView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let author: AppBskyActorDefs.ProfileViewBasic
            public let record: ATProtocolValueContainer

        public init(
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.record = record
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                throw error
            }
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)
            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(author, forKey: .author)
            try container.encode(record, forKey: .record)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(record)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if author != other.author {
                return false
            }
            if record != other.record {
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
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case record
        }
    }



}


                           

