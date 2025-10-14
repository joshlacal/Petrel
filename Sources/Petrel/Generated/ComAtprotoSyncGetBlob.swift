import Foundation



// lexicon: 1, id: com.atproto.sync.getBlob


public struct ComAtprotoSyncGetBlob { 

    public static let typeIdentifier = "com.atproto.sync.getBlob"    
public struct Parameters: Parametrizable {
        public let did: DID
        public let cid: CID
        
        public init(
            did: DID, 
            cid: CID
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
    // MARK: - getBlob

    /// Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBlob(input: ComAtprotoSyncGetBlob.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetBlob.Output?) {
        let endpoint = "com.atproto.sync.getBlob"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "*/*"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.sync.getBlob")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "*/*", actual: "nil")
        }

        if !contentType.lowercased().contains("*/*") {
            throw NetworkError.invalidContentType(expected: "*/*", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decodedData = ComAtprotoSyncGetBlob.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.getBlob: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
