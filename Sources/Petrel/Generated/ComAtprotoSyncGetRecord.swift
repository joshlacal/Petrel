import Foundation



// lexicon: 1, id: com.atproto.sync.getRecord


public struct ComAtprotoSyncGetRecord { 

    public static let typeIdentifier = "com.atproto.sync.getRecord"    
public struct Parameters: Parametrizable {
        public let did: String
        public let collection: String
        public let rkey: String
        
        public init(
            did: String, 
            collection: String, 
            rkey: String
            ) {
            self.did = did
            self.collection = collection
            self.rkey = rkey
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        public let data: Data
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
        ) {
            
            
            self.data = data
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case data
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case recordNotFound = "RecordNotFound."
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
    /// Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.
    public func getRecord(input: ComAtprotoSyncGetRecord.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRecord.Output?) {
        let endpoint = "com.atproto.sync.getRecord"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }
        
        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        // Data decoding and validation
        
        let decodedData = ComAtprotoSyncGetRecord.Output(data: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
