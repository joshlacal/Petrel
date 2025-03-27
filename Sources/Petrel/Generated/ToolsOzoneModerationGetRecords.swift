import Foundation



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
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.records = try container.decode([OutputRecordsUnion].self, forKey: .records)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(records, forKey: .records)
            
            
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
        case .toolsOzoneModerationDefsRecordViewDetail(let value):
            try container.encode("tools.ozone.moderation.defs#recordViewDetail", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsRecordViewNotFound(let value):
            try container.encode("tools.ozone.moderation.defs#recordViewNotFound", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .toolsOzoneModerationDefsRecordViewDetail(let value):
            hasher.combine("tools.ozone.moderation.defs#recordViewDetail")
            hasher.combine(value)
        case .toolsOzoneModerationDefsRecordViewNotFound(let value):
            hasher.combine("tools.ozone.moderation.defs#recordViewNotFound")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputRecordsUnion, rhs: OutputRecordsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.toolsOzoneModerationDefsRecordViewDetail(let lhsValue),
              .toolsOzoneModerationDefsRecordViewDetail(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsRecordViewNotFound(let lhsValue),
              .toolsOzoneModerationDefsRecordViewNotFound(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputRecordsUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .toolsOzoneModerationDefsRecordViewDetail(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsRecordViewNotFound(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .toolsOzoneModerationDefsRecordViewDetail(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsRecordViewDetail(value)
        case .toolsOzoneModerationDefsRecordViewNotFound(var value):
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


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about some records.
    public func getRecords(input: ToolsOzoneModerationGetRecords.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRecords.Output?) {
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
