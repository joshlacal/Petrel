import Foundation

// lexicon: 1, id: tools.ozone.moderation.getRecords

public enum ToolsOzoneModerationGetRecords {
    public static let typeIdentifier = "tools.ozone.moderation.getRecords"
    public struct Parameters: Parametrizable {
        public let uris: [ATProtocolURI]

        public init(
            uris: [ATProtocolURI]
        ) {
            self.uris = uris
        }
    }

    public struct Output: ATProtocolCodable {
        public let records: [OutputRecordsUnion]

        // Standard public initializer
        public init(
            records: [OutputRecordsUnion]

        ) {
            self.records = records
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            records = try container.decode([OutputRecordsUnion].self, forKey: .records)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(records, forKey: .records)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            // Add fields in lexicon-defined order

            let recordsValue = try (records as? DAGCBOREncodable)?.toCBORValue() ?? records
            map = map.adding(key: "records", value: recordsValue)

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case records
        }
    }

    public enum OutputRecordsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case toolsOzoneModerationDefsRecordViewDetail(ToolsOzoneModerationDefs.RecordViewDetail)
        case toolsOzoneModerationDefsRecordViewNotFound(ToolsOzoneModerationDefs.RecordViewNotFound)
        case unexpected(ATProtocolValueContainer)

        public init(_ value: ToolsOzoneModerationDefs.RecordViewDetail) {
            self = .toolsOzoneModerationDefsRecordViewDetail(value)
        }

        public init(_ value: ToolsOzoneModerationDefs.RecordViewNotFound) {
            self = .toolsOzoneModerationDefsRecordViewNotFound(value)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeValue = try container.decode(String.self, forKey: .type)

            switch typeValue {
            case "tools.ozone.moderation.defs#recordViewDetail":
                let value = try ToolsOzoneModerationDefs.RecordViewDetail(from: decoder)
                self = .toolsOzoneModerationDefsRecordViewDetail(value)
            case "tools.ozone.moderation.defs#recordViewNotFound":
                let value = try ToolsOzoneModerationDefs.RecordViewNotFound(from: decoder)
                self = .toolsOzoneModerationDefsRecordViewNotFound(value)
            default:
                let unknownValue = try ATProtocolValueContainer(from: decoder)
                self = .unexpected(unknownValue)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case let .toolsOzoneModerationDefsRecordViewDetail(value):
                try container.encode("tools.ozone.moderation.defs#recordViewDetail", forKey: .type)
                try value.encode(to: encoder)
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                try container.encode("tools.ozone.moderation.defs#recordViewNotFound", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .toolsOzoneModerationDefsRecordViewDetail(value):
                hasher.combine("tools.ozone.moderation.defs#recordViewDetail")
                hasher.combine(value)
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                hasher.combine("tools.ozone.moderation.defs#recordViewNotFound")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: OutputRecordsUnion, rhs: OutputRecordsUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .toolsOzoneModerationDefsRecordViewDetail(lhsValue),
                .toolsOzoneModerationDefsRecordViewDetail(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .toolsOzoneModerationDefsRecordViewNotFound(lhsValue),
                .toolsOzoneModerationDefsRecordViewNotFound(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
            default:
                return false
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? OutputRecordsUnion else { return false }
            return self == other
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            // Create an ordered map to maintain field order
            var map = OrderedCBORMap()

            switch self {
            case let .toolsOzoneModerationDefsRecordViewDetail(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordViewDetail")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                // Always add $type first
                map = map.adding(key: "$type", value: "tools.ozone.moderation.defs#recordViewNotFound")

                // Add the value's fields while preserving their order
                if let encodableValue = value as? DAGCBOREncodable {
                    let valueDict = try encodableValue.toCBORValue()

                    // If the value is already an OrderedCBORMap, merge its entries
                    if let orderedMap = valueDict as? OrderedCBORMap {
                        for (key, value) in orderedMap.entries where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    } else if let dict = valueDict as? [String: Any] {
                        // Otherwise add each key-value pair from the dictionary
                        for (key, value) in dict where key != "$type" {
                            map = map.adding(key: key, value: value)
                        }
                    }
                }
                return map
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .toolsOzoneModerationDefsRecordViewDetail(value):
                return value.hasPendingData
            case let .toolsOzoneModerationDefsRecordViewNotFound(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .toolsOzoneModerationDefsRecordViewDetail(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordViewDetail(value)
            case var .toolsOzoneModerationDefsRecordViewNotFound(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .toolsOzoneModerationDefsRecordViewNotFound(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}

public extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about some records.
    func getRecords(input: ToolsOzoneModerationGetRecords.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRecords.Output?) {
        let endpoint = "tools.ozone.moderation.getRecords"

        let queryItems = input.asQueryItems()

        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation

        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRecords.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
