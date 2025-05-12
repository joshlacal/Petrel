import Foundation



// lexicon: 1, id: com.atproto.identity.resolveDid


public struct ComAtprotoIdentityResolveDid { 

    public static let typeIdentifier = "com.atproto.identity.resolveDid"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let didDoc: DIDDocument
        
        
        
        // Standard public initializer
        public init(
            
            didDoc: DIDDocument
            
            
        ) {
            
            self.didDoc = didDoc
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.didDoc = try container.decode(DIDDocument.self, forKey: .didDoc)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(didDoc, forKey: .didDoc)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let didDocValue = try didDoc.toCBORValue()
            map = map.adding(key: "didDoc", value: didDocValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case didDoc
            
        }
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case didNotFound = "DidNotFound.The DID resolution process confirmed that there is no current DID."
                case didDeactivated = "DidDeactivated.The DID previously existed, but has been deactivated."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Identity {
    // MARK: - resolveDid

    /// Resolves DID to DID document. Does not bi-directionally verify handle.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func resolveDid(input: ComAtprotoIdentityResolveDid.Parameters) async throws -> (responseCode: Int, data: ComAtprotoIdentityResolveDid.Output?) {
        let endpoint = "com.atproto.identity.resolveDid"

        
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
        let decodedData = try? decoder.decode(ComAtprotoIdentityResolveDid.Output.self, from: responseData)
        

        return (responseCode, decodedData)
    }
}                           
