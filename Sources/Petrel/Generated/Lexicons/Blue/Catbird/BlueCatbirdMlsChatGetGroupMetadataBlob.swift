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
                case blobNotFound = "BlobNotFound.Metadata blob does not exist or has been garbage collected"
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

    /// Fetch an encrypted group metadata blob by locator Download an encrypted metadata blob. Returns raw encrypted bytes. The blob is opaque — decryption requires the MLS epoch key derived by group members.
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
            headers: ["Accept": "*/*"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getGroupMetadataBlob")
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
                
                let decodedData = BlueCatbirdMlsChatGetGroupMetadataBlob.Output(data: responseData)
                
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
                           

