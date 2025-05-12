import Foundation



// lexicon: 1, id: app.bsky.graph.getRelationships


public struct AppBskyGraphGetRelationships { 

    public static let typeIdentifier = "app.bsky.graph.getRelationships"    
public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
        public let others: [ATIdentifier]?
        
        public init(
            actor: ATIdentifier, 
            others: [ATIdentifier]? = nil
            ) {
            self.actor = actor
            self.others = others
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let actor: DID?
        
        public let relationships: [OutputRelationshipsUnion]
        
        
        
        // Standard public initializer
        public init(
            
            actor: DID? = nil,
            
            relationships: [OutputRelationshipsUnion]
            
            
        ) {
            
            self.actor = actor
            
            self.relationships = relationships
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.actor = try container.decodeIfPresent(DID.self, forKey: .actor)
            
            
            self.relationships = try container.decode([OutputRelationshipsUnion].self, forKey: .relationships)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(actor, forKey: .actor)
            
            
            try container.encode(relationships, forKey: .relationships)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = actor {
                // Encode optional property even if it's an empty array for CBOR
                let actorValue = try value.toCBORValue()
                map = map.adding(key: "actor", value: actorValue)
            }
            
            
            
            let relationshipsValue = try relationships.toCBORValue()
            map = map.adding(key: "relationships", value: relationshipsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case actor
            case relationships
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case actorNotFound = "ActorNotFound.the primary actor at-identifier could not be resolved"
            public var description: String {
                return self.rawValue
            }
        }





public enum OutputRelationshipsUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyGraphDefsRelationship(AppBskyGraphDefs.Relationship)
    case appBskyGraphDefsNotFoundActor(AppBskyGraphDefs.NotFoundActor)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyGraphDefs.Relationship) {
        self = .appBskyGraphDefsRelationship(value)
    }
    public init(_ value: AppBskyGraphDefs.NotFoundActor) {
        self = .appBskyGraphDefsNotFoundActor(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.graph.defs#relationship":
            let value = try AppBskyGraphDefs.Relationship(from: decoder)
            self = .appBskyGraphDefsRelationship(value)
        case "app.bsky.graph.defs#notFoundActor":
            let value = try AppBskyGraphDefs.NotFoundActor(from: decoder)
            self = .appBskyGraphDefsNotFoundActor(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyGraphDefsRelationship(let value):
            try container.encode("app.bsky.graph.defs#relationship", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyGraphDefsNotFoundActor(let value):
            try container.encode("app.bsky.graph.defs#notFoundActor", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyGraphDefsRelationship(let value):
            hasher.combine("app.bsky.graph.defs#relationship")
            hasher.combine(value)
        case .appBskyGraphDefsNotFoundActor(let value):
            hasher.combine("app.bsky.graph.defs#notFoundActor")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputRelationshipsUnion, rhs: OutputRelationshipsUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyGraphDefsRelationship(let lhsValue),
              .appBskyGraphDefsRelationship(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyGraphDefsNotFoundActor(let lhsValue),
              .appBskyGraphDefsNotFoundActor(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputRelationshipsUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyGraphDefsRelationship(let value):
            map = map.adding(key: "$type", value: "app.bsky.graph.defs#relationship")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .appBskyGraphDefsNotFoundActor(let value):
            map = map.adding(key: "$type", value: "app.bsky.graph.defs#notFoundActor")
            
            let valueDict = try value.toCBORValue()

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
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyGraphDefsRelationship(let value):
            return value.hasPendingData
        case .appBskyGraphDefsNotFoundActor(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyGraphDefsRelationship(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyGraphDefsRelationship(value)
        case .appBskyGraphDefsNotFoundActor(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyGraphDefsNotFoundActor(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.App.Bsky.Graph {
    // MARK: - getRelationships

    /// Enumerates public relationships between one account, and a list of other accounts. Does not require auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRelationships(input: AppBskyGraphGetRelationships.Parameters) async throws -> (responseCode: Int, data: AppBskyGraphGetRelationships.Output?) {
        let endpoint = "app.bsky.graph.getRelationships"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(AppBskyGraphGetRelationships.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
