import Foundation



// lexicon: 1, id: app.bsky.labeler.getServices


public struct AppBskyLabelerGetServices { 

    public static let typeIdentifier = "app.bsky.labeler.getServices"    
public struct Parameters: Parametrizable {
        public let dids: [String]
        public let detailed: Bool?
        
        public init(
            dids: [String], 
            detailed: Bool? = nil
            ) {
            self.dids = dids
            self.detailed = detailed
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let views: [OutputViewsUnion]
        
        
        
        // Standard public initializer
        public init(
            
            views: [OutputViewsUnion]
            
            
        ) {
            
            self.views = views
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.views = try container.decode([OutputViewsUnion].self, forKey: .views)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(views, forKey: .views)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case views
            
        }
    }






public enum OutputViewsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyLabelerDefsLabelerView(AppBskyLabelerDefs.LabelerView)
    case appBskyLabelerDefsLabelerViewDetailed(AppBskyLabelerDefs.LabelerViewDetailed)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyLabelerDefs.LabelerView) {
        self = .appBskyLabelerDefsLabelerView(value)
    }
    public init(_ value: AppBskyLabelerDefs.LabelerViewDetailed) {
        self = .appBskyLabelerDefsLabelerViewDetailed(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.labeler.defs#labelerView":
            let value = try AppBskyLabelerDefs.LabelerView(from: decoder)
            self = .appBskyLabelerDefsLabelerView(value)
        case "app.bsky.labeler.defs#labelerViewDetailed":
            let value = try AppBskyLabelerDefs.LabelerViewDetailed(from: decoder)
            self = .appBskyLabelerDefsLabelerViewDetailed(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyLabelerDefsLabelerView(let value):
            try container.encode("app.bsky.labeler.defs#labelerView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyLabelerDefsLabelerViewDetailed(let value):
            try container.encode("app.bsky.labeler.defs#labelerViewDetailed", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyLabelerDefsLabelerView(let value):
            hasher.combine("app.bsky.labeler.defs#labelerView")
            hasher.combine(value)
        case .appBskyLabelerDefsLabelerViewDetailed(let value):
            hasher.combine("app.bsky.labeler.defs#labelerViewDetailed")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputViewsUnion, rhs: OutputViewsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyLabelerDefsLabelerView(let lhsValue),
              .appBskyLabelerDefsLabelerView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyLabelerDefsLabelerViewDetailed(let lhsValue),
              .appBskyLabelerDefsLabelerViewDetailed(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputViewsUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyLabelerDefsLabelerView(let value):
            return value.hasPendingData
        case .appBskyLabelerDefsLabelerViewDetailed(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyLabelerDefsLabelerView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyLabelerDefsLabelerView(value)
        case .appBskyLabelerDefsLabelerViewDetailed(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyLabelerDefsLabelerViewDetailed(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.App.Bsky.Labeler {
    /// Get information about a list of labeler services.
    public func getServices(input: AppBskyLabelerGetServices.Parameters) async throws -> (responseCode: Int, data: AppBskyLabelerGetServices.Output?) {
        let endpoint = "app.bsky.labeler.getServices"
        
        
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
        let decodedData = try? decoder.decode(AppBskyLabelerGetServices.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
