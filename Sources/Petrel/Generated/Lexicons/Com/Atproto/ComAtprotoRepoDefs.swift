import Foundation



// lexicon: 1, id: com.atproto.repo.defs


public struct ComAtprotoRepoDefs { 

    public static let typeIdentifier = "com.atproto.repo.defs"
        
public struct CommitMeta: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.repo.defs#commitMeta"
            public let cid: CID
            public let rev: TID

        public init(
            cid: CID, rev: TID
        ) {
            self.cid = cid
            self.rev = rev
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.cid = try container.decode(CID.self, forKey: .cid)
            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")
                throw error
            }
            do {
                self.rev = try container.decode(TID.self, forKey: .rev)
            } catch {
                LogManager.logError("Decoding error for required property 'rev': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(cid, forKey: .cid)
            try container.encode(rev, forKey: .rev)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cid)
            hasher.combine(rev)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if cid != other.cid {
                return false
            }
            if rev != other.rev {
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
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case rev
        }
    }



}


                           

