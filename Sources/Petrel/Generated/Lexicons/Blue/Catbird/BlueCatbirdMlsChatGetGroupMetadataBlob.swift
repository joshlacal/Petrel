import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getGroupMetadataBlob


public struct BlueCatbirdMlsChatGetGroupMetadataBlob { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getGroupMetadataBlob"    
public struct Parameters: Parametrizable {
        public let blobLocator: String?
        public let groupId: String
        
        public init(
            blobLocator: String? = nil, 
            groupId: String
            ) {
            self.blobLocator = blobLocator
            self.groupId = groupId
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let blobLocator: String
        
        public let groupId: String
        
        public let data: Bytes
        
        public let size: Int?
        
        public let createdAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            blobLocator: String,
            
            groupId: String,
            
            data: Bytes,
            
            size: Int? = nil,
            
            createdAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.blobLocator = blobLocator
            
            self.groupId = groupId
            
            self.data = data
            
            self.size = size
            
            self.createdAt = createdAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.blobLocator = try container.decode(String.self, forKey: .blobLocator)
            
            
            self.groupId = try container.decode(String.self, forKey: .groupId)
            
            
            self.data = try container.decode(Bytes.self, forKey: .data)
            
            
            self.size = try container.decodeIfPresent(Int.self, forKey: .size)
            
            
            self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(blobLocator, forKey: .blobLocator)
            
            
            try container.encode(groupId, forKey: .groupId)
            
            
            try container.encode(data, forKey: .data)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(size, forKey: .size)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let blobLocatorValue = try blobLocator.toCBORValue()
            map = map.adding(key: "blobLocator", value: blobLocatorValue)
            
            
            
            let groupIdValue = try groupId.toCBORValue()
            map = map.adding(key: "groupId", value: groupIdValue)
            
            
            
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            
            
            
            if let value = size {
                // Encode optional property even if it's an empty array for CBOR
                let sizeValue = try value.toCBORValue()
                map = map.adding(key: "size", value: sizeValue)
            }
            
            
            
            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case blobLocator
            case groupId
            case data
            case size
            case createdAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case blobNotFound = "BlobNotFound.The specified blob locator was not found (may have been garbage collected)"
                case notMember = "NotMember.Caller is not a member of the specified group"
                case unauthorized = "Unauthorized.Authentication required"
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
    // MARK: - getGroupMetadataBlob

    /// Fetch an encrypted group metadata blob by locator or latest for a group Retrieve an encrypted group metadata blob from the server. If blobLocator is provided, fetches that specific blob. If only groupId is provided, returns the most recently uploaded blob for the group.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getGroupMetadataBlob(input: BlueCatbirdMlsChatGetGroupMetadataBlob.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetGroupMetadataBlob.Output?) {
        let endpoint = "blue.catbird.mlsChat.getGroupMetadataBlob"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getGroupMetadataBlob")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetGroupMetadataBlob.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getGroupMetadataBlob: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

