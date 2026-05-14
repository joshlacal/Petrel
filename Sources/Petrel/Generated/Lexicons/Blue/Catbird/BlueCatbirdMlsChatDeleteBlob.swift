import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.deleteBlob


public struct BlueCatbirdMlsChatDeleteBlob { 

    public static let typeIdentifier = "blue.catbird.mlsChat.deleteBlob"
public struct Input: ATProtocolCodable {
        public let blobId: String

        /// Standard public initializer
        public init(blobId: String) {
            self.blobId = blobId
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.blobId = try container.decode(String.self, forKey: .blobId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(blobId, forKey: .blobId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let blobIdValue = try blobId.toCBORValue()
            map = map.adding(key: "blobId", value: blobIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case blobId
        }
    }        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case blobNotFound = "BlobNotFound.Blob does not exist or is not owned by the authenticated user"
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

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - deleteBlob

    /// Delete an encrypted blob (owner only) Soft-delete an encrypted blob. Only the blob owner can delete it. The MLS message still contains the embed reference, but blob download will return 404 (same UX as expired blobs). Allows users to free quota space before the 90-day TTL.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deleteBlob(
        
        input: BlueCatbirdMlsChatDeleteBlob.Input
        
    ) async throws -> Int {
        let endpoint = "blue.catbird.mlsChat.deleteBlob"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.deleteBlob")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

