import Foundation



// lexicon: 1, id: com.atproto.sync.getLatestCommit


public struct ComAtprotoSyncGetLatestCommit { 

    public static let typeIdentifier = "com.atproto.sync.getLatestCommit"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cid: CID
        
        public let rev: TID
        
        
        
        // Standard public initializer
        public init(
            
            cid: CID,
            
            rev: TID
            
            
        ) {
            
            self.cid = cid
            
            self.rev = rev
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.cid = try container.decode(CID.self, forKey: .cid)
            
            
            self.rev = try container.decode(TID.self, forKey: .rev)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            try container.encode(rev, forKey: .rev)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let cidValue = try (cid as? DAGCBOREncodable)?.toCBORValue() ?? cid
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            let revValue = try (rev as? DAGCBOREncodable)?.toCBORValue() ?? rev
            map = map.adding(key: "rev", value: revValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case cid
            case rev
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case repoNotFound = "RepoNotFound."
                case repoTakendown = "RepoTakendown."
                case repoSuspended = "RepoSuspended."
                case repoDeactivated = "RepoDeactivated."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Sync {
    /// Get the current commit CID & revision of the specified repo. Does not require auth.
    public func getLatestCommit(input: ComAtprotoSyncGetLatestCommit.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetLatestCommit.Output?) {
        let endpoint = "com.atproto.sync.getLatestCommit"
        
        
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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetLatestCommit.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
