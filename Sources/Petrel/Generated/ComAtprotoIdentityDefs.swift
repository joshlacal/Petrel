import Foundation

// lexicon: 1, id: com.atproto.identity.defs

public enum ComAtprotoIdentityDefs {
    public static let typeIdentifier = "com.atproto.identity.defs"

    public struct IdentityInfo: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "com.atproto.identity.defs#identityInfo"
        public let did: String
        public let handle: String
        public let didDoc: DIDDocument

        // Standard initializer
        public init(
            did: String, handle: String, didDoc: DIDDocument
        ) {
            self.did = did
            self.handle = handle
            self.didDoc = didDoc
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                did = try container.decode(String.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(String.self, forKey: .handle)

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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case didDoc
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = did as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = handle as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = didDoc as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = did as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    did = updatedValue
                }
            }

            if let loadable = handle as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    handle = updatedValue
                }
            }

            if let loadable = didDoc as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? DIDDocument {
                    didDoc = updatedValue
                }
            }
        }
    }
}
