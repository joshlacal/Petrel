import Foundation



// lexicon: 1, id: com.atproto.repo.describeRepo


public struct ComAtprotoRepoDescribeRepo { 

    public static let typeIdentifier = "com.atproto.repo.describeRepo"    
public struct Parameters: Parametrizable {
        public let repo: ATIdentifier
        
        public init(
            repo: ATIdentifier
            ) {
            self.repo = repo
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let handle: Handle
        
        public let did: DID
        
        public let didDoc: DIDDocument
        
        public let collections: [NSID]
        
        public let handleIsCorrect: Bool
        
        
        
        // Standard public initializer
        public init(
            
            handle: Handle,
            
            did: DID,
            
            didDoc: DIDDocument,
            
            collections: [NSID],
            
            handleIsCorrect: Bool
            
            
        ) {
            
            self.handle = handle
            
            self.did = did
            
            self.didDoc = didDoc
            
            self.collections = collections
            
            self.handleIsCorrect = handleIsCorrect
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.handle = try container.decode(Handle.self, forKey: .handle)
            
            
            self.did = try container.decode(DID.self, forKey: .did)
            
            
            self.didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)
            
            
            self.collections = try container.decode([NSID].self, forKey: .collections)
            
            
            self.handleIsCorrect = try container.decode(Bool.self, forKey: .handleIsCorrect)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(didDoc, forKey: .didDoc)
            
            
            try container.encode(collections, forKey: .collections)
            
            
            try container.encode(handleIsCorrect, forKey: .handleIsCorrect)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            let didDocValue = try didDoc.toCBORValue()
            map = map.adding(key: "didDoc", value: didDocValue)
            
            
            
            let collectionsValue = try collections.toCBORValue()
            map = map.adding(key: "collections", value: collectionsValue)
            
            
            
            let handleIsCorrectValue = try handleIsCorrect.toCBORValue()
            map = map.adding(key: "handleIsCorrect", value: handleIsCorrectValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case handle
            case did
            case didDoc
            case collections
            case handleIsCorrect
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - describeRepo

    /// Get information about an account and repository, including the list of collections. Does not require auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func describeRepo(input: ComAtprotoRepoDescribeRepo.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoDescribeRepo.Output?) {
        let endpoint = "com.atproto.repo.describeRepo"

        
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
        let decodedData = try? decoder.decode(ComAtprotoRepoDescribeRepo.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
