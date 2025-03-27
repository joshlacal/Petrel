import Foundation



// lexicon: 1, id: com.atproto.sync.getBlob


public struct ComAtprotoSyncGetBlob { 

    public static let typeIdentifier = "com.atproto.sync.getBlob"    
public struct Parameters: Parametrizable {
        public let did: String
        public let cid: String
        
        public init(
            did: String, 
            cid: String
            ) {
            self.did = did
            self.cid = cid
            
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
            
            
            self.data = try container.decode(Data.self, forKey: .data)
            
            
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
                case blobNotFound = "BlobNotFound."
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
    /// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
    public func getBlob(input: ComAtprotoSyncGetBlob.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetBlob.Output?) {
        let endpoint = "com.atproto.sync.getBlob"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "*/*"],
            body: nil,
            queryItems: queryItems
        )
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "*/*", actual: "nil")
        }
        
        if !contentType.lowercased().contains("*/*") {
            throw NetworkError.invalidContentType(expected: "*/*", actual: contentType)
        }

        // Data decoding and validation
        
        let decodedData = ComAtprotoSyncGetBlob.Output(data: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
