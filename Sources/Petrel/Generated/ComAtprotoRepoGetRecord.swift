import Foundation



// lexicon: 1, id: com.atproto.repo.getRecord


public struct ComAtprotoRepoGetRecord { 

    public static let typeIdentifier = "com.atproto.repo.getRecord"    
public struct Parameters: Parametrizable {
        public let repo: ATIdentifier
        public let collection: NSID
        public let rkey: RecordKey
        public let cid: CID?
        
        public init(
            repo: ATIdentifier, 
            collection: NSID, 
            rkey: RecordKey, 
            cid: CID? = nil
            ) {
            self.repo = repo
            self.collection = collection
            self.rkey = rkey
            self.cid = cid
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: ATProtocolURI
        
        public let cid: CID?
        
        public let value: ATProtocolValueContainer
        
        
        
        // Standard public initializer
        public init(
            
            
            uri: ATProtocolURI,
            
            cid: CID? = nil,
            
            value: ATProtocolValueContainer
            
            
        ) {
            
            
            self.uri = uri
            
            self.cid = cid
            
            self.value = value
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
            
            
            self.cid = try container.decodeIfPresent(CID.self, forKey: .cid)
            
            
            self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(uri, forKey: .uri)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)
            
            
            try container.encode(value, forKey: .value)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR
                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
            case value
        }
        
    }
        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case recordNotFound = "RecordNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Com.Atproto.Repo {
    // MARK: - getRecord

    /// Get a single record from a repository. Does not require auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getRecord(input: ComAtprotoRepoGetRecord.Parameters) async throws -> (responseCode: Int, data: ComAtprotoRepoGetRecord.Output?) {
        let endpoint = "com.atproto.repo.getRecord"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.repo.getRecord")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoRepoGetRecord.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.repo.getRecord: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

