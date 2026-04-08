import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getBlob


public struct BlueCatbirdMlsChatGetBlob { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getBlob"    
public struct Parameters: Parametrizable {
        public let blobId: String
        
        public init(
            blobId: String
            ) {
            self.blobId = blobId
            
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
                case blobNotFound = "BlobNotFound.Blob does not exist or has expired/been deleted"
                case notAMember = "NotAMember.Requester is not an active member of the blob's conversation"
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
    // MARK: - getBlob

    /// Download an encrypted blob by ID Fetch an encrypted blob from the blob store. Returns raw encrypted bytes (application/octet-stream). Only active members of the blob's conversation can download it.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBlob(input: BlueCatbirdMlsChatGetBlob.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetBlob.Output?) {
        let endpoint = "blue.catbird.mlsChat.getBlob"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "*/*"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getBlob")
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
                
                let decodedData = BlueCatbirdMlsChatGetBlob.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getBlob: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

