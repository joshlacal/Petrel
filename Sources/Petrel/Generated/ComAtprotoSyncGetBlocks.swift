import Foundation



// lexicon: 1, id: com.atproto.sync.getBlocks


public struct ComAtprotoSyncGetBlocks { 

    public static let typeIdentifier = "com.atproto.sync.getBlocks"    
public struct Parameters: Parametrizable {
        public let did: DID
        public let cids: [CID]
        
        public init(
            did: DID, 
            cids: [CID]
            ) {
            self.did = did
            self.cids = cids
            
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

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case data
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                
                case blockNotFound = "BlockNotFound"
                
                case repoNotFound = "RepoNotFound"
                
                case repoTakendown = "RepoTakendown"
                
                case repoSuspended = "RepoSuspended"
                
                case repoDeactivated = "RepoDeactivated"
            public var description: String {
                return self.rawValue
            }
        }



}



extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - getBlocks

    /// Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBlocks(input: ComAtprotoSyncGetBlocks.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetBlocks.Output?) {
        let endpoint = "com.atproto.sync.getBlocks"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.ipld.car"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.sync.getBlocks")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.ipld.car") {
            throw NetworkError.invalidContentType(expected: "application/vnd.ipld.car", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decodedData = ComAtprotoSyncGetBlocks.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.getBlocks: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: ComAtprotoSyncGetBlocks.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

