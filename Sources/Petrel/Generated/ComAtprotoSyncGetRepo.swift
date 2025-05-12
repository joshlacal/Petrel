import Foundation



// lexicon: 1, id: com.atproto.sync.getRepo


public struct ComAtprotoSyncGetRepo { 

    public static let typeIdentifier = "com.atproto.sync.getRepo"    
public struct Parameters: Parametrizable {
        public let did: DID
        public let since: TID?
        
        public init(
            did: DID, 
            since: TID? = nil
            ) {
            self.did = did
            self.since = since
            
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

        public func toCBORValue() throws -> Any {
            
            return data
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case data
            
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
    // MARK: - getRepo

    /// Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRepo(input: ComAtprotoSyncGetRepo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetRepo.Output?) {
        let endpoint = "com.atproto.sync.getRepo"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )

        let (responseData, response) = try await networkService.performRequest(urlRequest)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        
        let decodedData = ComAtprotoSyncGetRepo.Output(data: responseData)
        

        return (responseCode, decodedData)
    }
}                           
