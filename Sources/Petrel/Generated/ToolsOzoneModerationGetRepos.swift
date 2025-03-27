import Foundation



// lexicon: 1, id: tools.ozone.moderation.getRepos


public struct ToolsOzoneModerationGetRepos { 

    public static let typeIdentifier = "tools.ozone.moderation.getRepos"    
public struct Parameters: Parametrizable {
        public let dids: [String]
        
        public init(
            dids: [String]
            ) {
            self.dids = dids
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let repos: [OutputReposUnion]
        
        
        
        // Standard public initializer
        public init(
            
            repos: [OutputReposUnion]
            
            
        ) {
            
            self.repos = repos
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.repos = try container.decode([OutputReposUnion].self, forKey: .repos)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(repos, forKey: .repos)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case repos
            
        }
    }






public enum OutputReposUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case toolsOzoneModerationDefsRepoViewDetail(ToolsOzoneModerationDefs.RepoViewDetail)
    case toolsOzoneModerationDefsRepoViewNotFound(ToolsOzoneModerationDefs.RepoViewNotFound)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ToolsOzoneModerationDefs.RepoViewDetail) {
        self = .toolsOzoneModerationDefsRepoViewDetail(value)
    }
    public init(_ value: ToolsOzoneModerationDefs.RepoViewNotFound) {
        self = .toolsOzoneModerationDefsRepoViewNotFound(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "tools.ozone.moderation.defs#repoViewDetail":
            let value = try ToolsOzoneModerationDefs.RepoViewDetail(from: decoder)
            self = .toolsOzoneModerationDefsRepoViewDetail(value)
        case "tools.ozone.moderation.defs#repoViewNotFound":
            let value = try ToolsOzoneModerationDefs.RepoViewNotFound(from: decoder)
            self = .toolsOzoneModerationDefsRepoViewNotFound(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .toolsOzoneModerationDefsRepoViewDetail(let value):
            try container.encode("tools.ozone.moderation.defs#repoViewDetail", forKey: .type)
            try value.encode(to: encoder)
        case .toolsOzoneModerationDefsRepoViewNotFound(let value):
            try container.encode("tools.ozone.moderation.defs#repoViewNotFound", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .toolsOzoneModerationDefsRepoViewDetail(let value):
            hasher.combine("tools.ozone.moderation.defs#repoViewDetail")
            hasher.combine(value)
        case .toolsOzoneModerationDefsRepoViewNotFound(let value):
            hasher.combine("tools.ozone.moderation.defs#repoViewNotFound")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputReposUnion, rhs: OutputReposUnion) -> Bool {
        switch (lhs, rhs) {
        case (.toolsOzoneModerationDefsRepoViewDetail(let lhsValue),
              .toolsOzoneModerationDefsRepoViewDetail(let rhsValue)):
            return lhsValue == rhsValue
        case (.toolsOzoneModerationDefsRepoViewNotFound(let lhsValue),
              .toolsOzoneModerationDefsRepoViewNotFound(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputReposUnion else { return false }
        return self == other
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .toolsOzoneModerationDefsRepoViewDetail(let value):
            return value.hasPendingData
        case .toolsOzoneModerationDefsRepoViewNotFound(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .toolsOzoneModerationDefsRepoViewDetail(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsRepoViewDetail(value)
        case .toolsOzoneModerationDefsRepoViewNotFound(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .toolsOzoneModerationDefsRepoViewNotFound(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about some repositories.
    public func getRepos(input: ToolsOzoneModerationGetRepos.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRepos.Output?) {
        let endpoint = "tools.ozone.moderation.getRepos"
        
        
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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRepos.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
