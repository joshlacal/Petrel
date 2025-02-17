import Foundation
import ZippyJSON

// lexicon: 1, id: tools.ozone.moderation.getRecords

public struct ToolsOzoneModerationGetRecords {
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
    }

    public enum OutputRecordsUnion: Codable, ATProtocolCodable, ATProtocolValue {
        case toolsOzoneModerationDefsRecordViewDetail(ToolsOzoneModerationDefs.RecordViewDetail)
        case toolsOzoneModerationDefsRecordViewNotFound(ToolsOzoneModerationDefs.RecordViewNotFound)
        case unexpected(ATProtocolValueContainer)

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
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
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
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? OutputRecordsUnion else { return false }

            switch (self, otherValue) {
            case let (
                .toolsOzoneModerationDefsRecordViewDetail(selfValue),
                .toolsOzoneModerationDefsRecordViewDetail(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .toolsOzoneModerationDefsRecordViewNotFound(selfValue),
                .toolsOzoneModerationDefsRecordViewNotFound(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
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

        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRecords.Output.self, from: responseData)

        return (responseCode, decodedData)
    }
}
