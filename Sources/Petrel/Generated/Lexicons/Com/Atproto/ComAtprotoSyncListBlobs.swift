import Foundation



// lexicon: 1, id: com.atproto.sync.listBlobs


public struct ComAtprotoSyncListBlobs { 

    public static let typeIdentifier = "com.atproto.sync.listBlobs"    
public struct Parameters: Parametrizable {
        public let did: DID
        public let since: TID?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            did: DID, 
            since: TID? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.did = did
            self.since = since
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let cids: [CID]
        
        
        
        // Standard public initializer
        public init(
            
            
            cursor: String? = nil,
            
            cids: [CID]
            
            
        ) {
            
            
            self.cursor = cursor
            
            self.cids = cids
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.cids = try container.decode([CID].self, forKey: .cids)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(cids, forKey: .cids)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let cidsValue = try cids.toCBORValue()
            map = map.adding(key: "cids", value: cidsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cursor
            case cids
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case repoNotFound = "RepoNotFound."
                case repoTakendown = "RepoTakendown."
                case repoSuspended = "RepoSuspended."
                case repoDeactivated = "RepoDeactivated."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}



extension ATProtoClient.Com.Atproto.Sync {
    // MARK: - listBlobs

    /// List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func listBlobs(input: ComAtprotoSyncListBlobs.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncListBlobs.Output?) {
        let endpoint = "com.atproto.sync.listBlobs"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.sync.listBlobs")
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
                let decodedData = try decoder.decode(ComAtprotoSyncListBlobs.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.listBlobs: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

