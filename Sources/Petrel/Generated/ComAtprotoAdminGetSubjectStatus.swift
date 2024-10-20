import Foundation
import ZippyJSON


// lexicon: 1, id: com.atproto.admin.getSubjectStatus


public struct ComAtprotoAdminGetSubjectStatus { 

    public static let typeIdentifier = "com.atproto.admin.getSubjectStatus"    
public struct Parameters: Parametrizable {
        public let did: String?
        public let uri: ATProtocolURI?
        public let blob: String?
        
        public init(
            did: String? = nil, 
            uri: ATProtocolURI? = nil, 
            blob: String? = nil
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
    }






public enum OutputSubjectUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case comAtprotoAdminDefsRepoRef(ComAtprotoAdminDefs.RepoRef)
    case comAtprotoRepoStrongRef(ComAtprotoRepoStrongRef)
    case comAtprotoAdminDefsRepoBlobRef(ComAtprotoAdminDefs.RepoBlobRef)
    case unexpected(ATProtocolValueContainer)

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
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
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
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? OutputSubjectUnion else { return false }

        switch (self, otherValue) {
            case (.comAtprotoAdminDefsRepoRef(let selfValue), 
                .comAtprotoAdminDefsRepoRef(let otherValue)):
                return selfValue == otherValue
            case (.comAtprotoRepoStrongRef(let selfValue), 
                .comAtprotoRepoStrongRef(let otherValue)):
                return selfValue == otherValue
            case (.comAtprotoAdminDefsRepoBlobRef(let selfValue), 
                .comAtprotoAdminDefsRepoBlobRef(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoAdminGetSubjectStatus.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
