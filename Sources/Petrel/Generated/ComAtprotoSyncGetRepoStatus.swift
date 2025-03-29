import Foundation



// lexicon: 1, id: com.atproto.sync.getRepoStatus


public struct ComAtprotoSyncGetRepoStatus { 

    public static let typeIdentifier = "com.atproto.sync.getRepoStatus"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let did: DID
        
        public let active: Bool
        
        public let status: String?
        
        public let rev: TID?
        
        
        
        // Standard public initializer
        public init(
            
            did: DID,
            
            active: Bool,
            
            status: String? = nil,
            
            rev: TID? = nil
            
            
        ) {
            
            self.did = did
            
            self.active = active
            
            self.status = status
            
            self.rev = rev
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.did = try container.decode(DID.self, forKey: .did)
            
            
            self.active = try container.decode(Bool.self, forKey: .active)
            
            
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
            
            
            self.rev = try container.decodeIfPresent(TID.self, forKey: .rev)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(active, forKey: .active)
            
            
            if let value = status {
                
                try container.encode(value, forKey: .status)
                
            }
            
            
            if let value = rev {
                
                try container.encode(value, forKey: .rev)
                
            }
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            let activeValue = try (active as? DAGCBOREncodable)?.toCBORValue() ?? active
            map = map.adding(key: "active", value: activeValue)
            
            
            
            if let value = status {
                
                
                let statusValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "status", value: statusValue)
                
            }
            
            
            
            if let value = rev {
                
                
                let revValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                map = map.adding(key: "rev", value: revValue)
                
            }
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case did
            case active
            case status
            case rev
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case repoNotFound = "RepoNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Sync {
    /// Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
    public func getRepoStatus(input: ComAtprotoSyncGetRepoStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRepoStatus.Output?) {
        let endpoint = "com.atproto.sync.getRepoStatus"
        
        
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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetRepoStatus.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
