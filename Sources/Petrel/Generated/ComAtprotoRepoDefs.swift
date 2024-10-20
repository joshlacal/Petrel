import Foundation
import ZippyJSON

// lexicon: 1, id: com.atproto.repo.defs

public enum ComAtprotoRepoDefs {
    public static let typeIdentifier = "com.atproto.repo.defs"

    public struct CommitMeta: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.repo.defs#commitMeta"
        public let cid: String
        public let rev: String

        // Standard initializer
        public init(
            cid: String, rev: String
        ) {
            self.cid = cid
            self.rev = rev
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                cid = try container.decode(String.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                rev = try container.decode(String.self, forKey: .rev)

            } catch {
                LogManager.logError("Decoding error for property 'rev': \(error)")
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cid
            case rev
        }
    }
}
