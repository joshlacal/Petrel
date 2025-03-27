import Foundation

// lexicon: 1, id: tools.ozone.signature.defs

public enum ToolsOzoneSignatureDefs {
    public static let typeIdentifier = "tools.ozone.signature.defs"

    public struct SigDetail: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "tools.ozone.signature.defs#sigDetail"
        public let property: String
        public let value: String

        // Standard initializer
        public init(
            property: String, value: String
        ) {
            self.property = property
            self.value = value
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                property = try container.decode(String.self, forKey: .property)

            } catch {
                LogManager.logError("Decoding error for property 'property': \(error)")
                throw error
            }
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(property, forKey: .property)

            try container.encode(value, forKey: .value)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(property)
            hasher.combine(value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if property != other.property {
                return false
            }

            if value != other.value {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case property
            case value
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = property as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = property as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    property = updatedValue
                }
            }

            if let loadable = value as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    value = updatedValue
                }
            }
        }
    }
}
