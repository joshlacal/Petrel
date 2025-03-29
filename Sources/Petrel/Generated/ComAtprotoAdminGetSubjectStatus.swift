import Foundation



// lexicon: 1, id: com.atproto.admin.getSubjectStatus


public struct ComAtprotoAdminGetSubjectStatus { 

    public static let typeIdentifier = "com.atproto.admin.getSubjectStatus"    
public struct Parameters: Parametrizable {
        public let did: DID?
        public let uri: ATProtocolURI?
        public let blob: CID?
        
        public init(
            did: DID? = nil, 
            uri: ATProtocolURI? = nil, 
            blob: CID? = nil
            ) {
            self.did = did
            self.uri = uri
            self.blob = blob
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let subject: OutputSubjectUnion
        
        public let takedown: ComAtprotoAdminDefs.StatusAttr?
        
        public let deactivated: ComAtprotoAdminDefs.StatusAttr?
        
        
        
        // Standard public initializer
        public init(
            
            subject: OutputSubjectUnion,
            
            takedown: ComAtprotoAdminDefs.StatusAttr? = nil,
            
            deactivated: ComAtprotoAdminDefs.StatusAttr? = nil
            
            
        ) {
            
            self.subject = subject
            
            self.takedown = takedown
            
            self.deactivated = deactivated
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.subject = try container.decode(OutputSubjectUnion.self, forKey: .subject)
            
            
            self.takedown = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .takedown)
            
            
            self.deactivated = try container.decodeIfPresent(ComAtprotoAdminDefs.StatusAttr.self, forKey: .deactivated)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(subject, forKey: .subject)
            
            
            if let value = takedown {
                
                try container.encode(value, forKey: .takedown)
                
            }
            
            
            if let value = deactivated {
                
                try container.encode(value, forKey: .deactivated)
                
            }
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let subjectValue = try (subject as? DAGCBOREncodable)?.toCBORValue() ?? subject
            map = map.adding(key: "subject", value: subjectValue)
            
            
            
            if let value = takedown {
                
                
                let takedownValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "takedown", value: takedownValue)
                
            }
            
            
            
            if let value = deactivated {
                
                
                let deactivatedValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "deactivated", value: deactivatedValue)
                
            }
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case subject
            case takedown
            case deactivated
            
        }
    }






public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: ComAtprotoAdminDefs.RepoRef) {
        self = .comAtprotoAdminDefsRepoRef(value)
    }
    public init(_ value: ComAtprotoRepoStrongRef) {
        self = .comAtprotoRepoStrongRef(value)
    }
    public init(_ value: ComAtprotoAdminDefs.RepoBlobRef) {
        self = .comAtprotoAdminDefsRepoBlobRef(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "com.atproto.admin.defs#repoRef":
            let value = try ComAtprotoAdminDefs.RepoRef(from: decoder)
            self = .comAtprotoAdminDefsRepoRef(value)
        case "com.atproto.repo.strongRef":
            let value = try ComAtprotoRepoStrongRef(from: decoder)
            self = .comAtprotoRepoStrongRef(value)
        case "com.atproto.admin.defs#repoBlobRef":
            let value = try ComAtprotoAdminDefs.RepoBlobRef(from: decoder)
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            try container.encode("com.atproto.admin.defs#repoRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoRepoStrongRef(let value):
            try container.encode("com.atproto.repo.strongRef", forKey: .type)
            try value.encode(to: encoder)
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            try container.encode("com.atproto.admin.defs#repoBlobRef", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            hasher.combine("com.atproto.admin.defs#repoRef")
            hasher.combine(value)
        case .comAtprotoRepoStrongRef(let value):
            hasher.combine("com.atproto.repo.strongRef")
            hasher.combine(value)
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            hasher.combine("com.atproto.admin.defs#repoBlobRef")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: OutputSubjectUnion, rhs: OutputSubjectUnion) -> Bool {
        switch (lhs, rhs) {
        case (.comAtprotoAdminDefsRepoRef(let lhsValue),
              .comAtprotoAdminDefsRepoRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoRepoStrongRef(let lhsValue),
              .comAtprotoRepoStrongRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.comAtprotoAdminDefsRepoBlobRef(let lhsValue),
              .comAtprotoAdminDefsRepoBlobRef(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? OutputSubjectUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .comAtprotoAdminDefsRepoRef(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoRef")
            
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
        case .comAtprotoRepoStrongRef(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "com.atproto.repo.strongRef")
            
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
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            // Always add $type first
            map = map.adding(key: "$type", value: "com.atproto.admin.defs#repoBlobRef")
            
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
        case .unexpected(let container):
            return try container.toCBORValue()
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(let value):
            return value.hasPendingData
        case .comAtprotoRepoStrongRef(let value):
            return value.hasPendingData
        case .comAtprotoAdminDefsRepoBlobRef(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .comAtprotoAdminDefsRepoRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoRef(value)
        case .comAtprotoRepoStrongRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoRepoStrongRef(value)
        case .comAtprotoAdminDefsRepoBlobRef(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .comAtprotoAdminDefsRepoBlobRef(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


extension ATProtoClient.Com.Atproto.Admin {
    /// Get the service-specific admin status of a subject (account, record, or blob).
    public func getSubjectStatus(input: ComAtprotoAdminGetSubjectStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoAdminGetSubjectStatus.Output?) {
        let endpoint = "com.atproto.admin.getSubjectStatus"
        
        
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
        let decodedData = try? decoder.decode(ComAtprotoAdminGetSubjectStatus.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
