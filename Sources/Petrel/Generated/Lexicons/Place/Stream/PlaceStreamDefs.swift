import Foundation



// lexicon: 1, id: place.stream.defs


public struct PlaceStreamDefs { 

    public static let typeIdentifier = "place.stream.defs"
        
public struct BlockView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.defs#blockView"
            public let uri: ATProtocolURI
            public let cid: CID
            public let blocker: AppBskyActorDefs.ProfileViewBasic
            public let record: AppBskyGraphBlock
            public let indexedAt: ATProtocolDate

        public init(
            uri: ATProtocolURI, cid: CID, blocker: AppBskyActorDefs.ProfileViewBasic, record: AppBskyGraphBlock, indexedAt: ATProtocolDate
        ) {
            self.uri = uri
            self.cid = cid
            self.blocker = blocker
            self.record = record
            self.indexedAt = indexedAt
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
                self.blocker = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .blocker)
            } catch {
                LogManager.logError("Decoding error for required property 'blocker': \(error)")
                throw error
            }
            do {
                self.record = try container.decode(AppBskyGraphBlock.self, forKey: .record)
            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")
                throw error
            }
            do {
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(uri, forKey: .uri)
            try container.encode(cid, forKey: .cid)
            try container.encode(blocker, forKey: .blocker)
            try container.encode(record, forKey: .record)
            try container.encode(indexedAt, forKey: .indexedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(blocker)
            hasher.combine(record)
            hasher.combine(indexedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if uri != other.uri {
                return false
            }
            if cid != other.cid {
                return false
            }
            if blocker != other.blocker {
                return false
            }
            if record != other.record {
                return false
            }
            if indexedAt != other.indexedAt {
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
            let blockerValue = try blocker.toCBORValue()
            map = map.adding(key: "blocker", value: blockerValue)
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case blocker
            case record
            case indexedAt
        }
    }
        
public struct Renditions: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.defs#renditions"
            public let renditions: [Rendition]

        public init(
            renditions: [Rendition]
        ) {
            self.renditions = renditions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.renditions = try container.decode([Rendition].self, forKey: .renditions)
            } catch {
                LogManager.logError("Decoding error for required property 'renditions': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(renditions, forKey: .renditions)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(renditions)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if renditions != other.renditions {
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
            let renditionsValue = try renditions.toCBORValue()
            map = map.adding(key: "renditions", value: renditionsValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case renditions
        }
    }
        
public struct Rendition: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "place.stream.defs#rendition"
            public let name: String

        public init(
            name: String
        ) {
            self.name = name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.name = try container.decode(String.self, forKey: .name)
            } catch {
                LogManager.logError("Decoding error for required property 'name': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(name, forKey: .name)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if name != other.name {
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
            let nameValue = try name.toCBORValue()
            map = map.adding(key: "name", value: nameValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
        }
    }



}


                           

