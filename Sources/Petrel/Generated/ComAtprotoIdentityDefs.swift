import Foundation



// lexicon: 1, id: com.atproto.identity.defs


public struct ComAtprotoIdentityDefs { 

    public static let typeIdentifier = "com.atproto.identity.defs"
        
public struct IdentityInfo: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "com.atproto.identity.defs#identityInfo"
            public let did: DID
            public let handle: Handle
            public let didDoc: DIDDocument

        // Standard initializer
        public init(
            did: DID, handle: Handle, didDoc: DIDDocument
        ) {
            
            self.did = did
            self.handle = handle
            self.didDoc = didDoc
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(DID.self, forKey: .did)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                self.handle = try container.decode(Handle.self, forKey: .handle)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'handle': \(error)")
                
                throw error
            }
            do {
                
                self.didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'didDoc': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(didDoc, forKey: .didDoc)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            hasher.combine(didDoc)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            
            if self.handle != other.handle {
                return false
            }
            
            
            if self.didDoc != other.didDoc {
                return false
            }
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            
            let didDocValue = try didDoc.toCBORValue()
            map = map.adding(key: "didDoc", value: didDocValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case didDoc
        }
    }



}


                           
