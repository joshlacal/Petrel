import Foundation

// lexicon: 1, id: com.atproto.sync.defs

public enum ComAtprotoSyncDefs {
    public static let typeIdentifier = "com.atproto.sync.defs"

    public struct HostStatus: Codable, ATProtocolCodable, ATProtocolValue {
        public let rawValue: String

        // Predefined constants
        //
        public static let active = HostStatus(rawValue: "active")
        //
        public static let idle = HostStatus(rawValue: "idle")
        //
        public static let offline = HostStatus(rawValue: "offline")
        //
        public static let throttled = HostStatus(rawValue: "throttled")
        //
        public static let banned = HostStatus(rawValue: "banned")

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? HostStatus else { return false }
            return rawValue == otherValue.rawValue
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // For string-based enum types, we return the raw string value directly
            return rawValue
        }

        // Provide allCases-like functionality
        public static var predefinedValues: [HostStatus] {
            return [
                .active,
                .idle,
                .offline,
                .throttled,
                .banned,
            ]
        }
    }
}
