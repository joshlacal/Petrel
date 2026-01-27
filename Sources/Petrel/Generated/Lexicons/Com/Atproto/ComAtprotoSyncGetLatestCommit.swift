import Foundation



// lexicon: 1, id: com.atproto.sync.getLatestCommit


public struct ComAtprotoSyncGetLatestCommit { 

    public static let typeIdentifier = "com.atproto.sync.getLatestCommit"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cid: CID
        
        public let rev: TID
        
        
        
        // Standard public initializer
        public init(
            
            
            cid: CID,
            
            rev: TID
            
            
        ) {
            
            
            self.cid = cid
            
            self.rev = rev
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cid = try container.decode(CID.self, forKey: .cid)
            
            
            self.rev = try container.decode(TID.self, forKey: .rev)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(cid, forKey: .cid)
            
            
            try container.encode(rev, forKey: .rev)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            let revValue = try rev.toCBORValue()
            map = map.adding(key: "rev", value: revValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cid
            case rev
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
    // MARK: - getLatestCommit

    /// Get the current commit CID & revision of the specified repo. Does not require auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getLatestCommit(input: ComAtprotoSyncGetLatestCommit.Parameters) async throws -> (responseCode: Int, data: ComAtprotoSyncGetLatestCommit.Output?) {
        let endpoint = "com.atproto.sync.getLatestCommit"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.sync.getLatestCommit")
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
                let decodedData = try decoder.decode(ComAtprotoSyncGetLatestCommit.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.sync.getLatestCommit: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

