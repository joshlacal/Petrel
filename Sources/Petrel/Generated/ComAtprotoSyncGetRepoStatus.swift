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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rev, forKey: .rev)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            let activeValue = try active.toCBORValue()
            map = map.adding(key: "active", value: activeValue)
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            
            if let value = rev {
                // Encode optional property even if it's an empty array for CBOR
                let revValue = try value.toCBORValue()
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
    // MARK: - getRepoStatus

    /// Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRepoStatus(input: ComAtprotoSyncGetRepoStatus.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRepoStatus.Output?) {
        let endpoint = "com.atproto.sync.getRepoStatus"

        
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
        let decodedData = try? decoder.decode(ComAtprotoSyncGetRepoStatus.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
