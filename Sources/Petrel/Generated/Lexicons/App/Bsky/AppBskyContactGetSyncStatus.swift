import Foundation



// lexicon: 1, id: app.bsky.contact.getSyncStatus


public struct AppBskyContactGetSyncStatus { 

    public static let typeIdentifier = "app.bsky.contact.getSyncStatus"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let syncStatus: AppBskyContactDefs.SyncStatus?
        
        
        
        // Standard public initializer
        public init(
            
            
            syncStatus: AppBskyContactDefs.SyncStatus? = nil
            
            
        ) {
            
            
            self.syncStatus = syncStatus
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.syncStatus = try container.decodeIfPresent(AppBskyContactDefs.SyncStatus.self, forKey: .syncStatus)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(syncStatus, forKey: .syncStatus)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = syncStatus {
                // Encode optional property even if it's an empty array for CBOR
                let syncStatusValue = try value.toCBORValue()
                map = map.adding(key: "syncStatus", value: syncStatusValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case syncStatus
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidDid = "InvalidDid."
                case internalError = "InternalError."
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



extension ATProtoClient.App.Bsky.Contact {
    // MARK: - getSyncStatus

    /// Gets the user's current contact import status. Requires authentication.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSyncStatus(input: AppBskyContactGetSyncStatus.Parameters) async throws -> (responseCode: Int, data: AppBskyContactGetSyncStatus.Output?) {
        let endpoint = "app.bsky.contact.getSyncStatus"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.contact.getSyncStatus")
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
                let decodedData = try decoder.decode(AppBskyContactGetSyncStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.contact.getSyncStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

