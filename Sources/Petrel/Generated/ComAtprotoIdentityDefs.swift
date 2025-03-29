import Foundation

// lexicon: 1, id: com.atproto.identity.defs

public enum ComAtprotoIdentityDefs {
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)

            } catch {
                LogManager.logError("Decoding error for property 'didDoc': \(error)")
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

            if did != other.did {
                return false
            }

            if handle != other.handle {
                return false
            }

            if didDoc != other.didDoc {
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

            // Always add $type first (AT Protocol convention)
            map = map.adding(key: "$type", value: Self.typeIdentifier)

            // Add remaining fields in lexicon-defined order

            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)

            let handleValue = try (handle as? DAGCBOREncodable)?.toCBORValue() ?? handle
            map = map.adding(key: "handle", value: handleValue)

            let didDocValue = try (didDoc as? DAGCBOREncodable)?.toCBORValue() ?? didDoc
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
