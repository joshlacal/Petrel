import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.repo.strongRef


public struct ComAtprotoRepoStrongRef: ATProtocolCodable, ATProtocolValue { 

    public static let typeIdentifier = "com.atproto.repo.strongRef"
        public let uri: ATProtocolURI
        public let cid: String

        public init(uri: ATProtocolURI, cid: String) {
            self.uri = uri
            self.cid = cid
            
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            
            
            self.cid = try container.decode(String.self, forKey: .cid)
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if self.uri != other.uri {
                return false
            }
            if self.cid != other.cid {
                return false
            }
            return true
        }
 
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }



        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
        }



}


                           
