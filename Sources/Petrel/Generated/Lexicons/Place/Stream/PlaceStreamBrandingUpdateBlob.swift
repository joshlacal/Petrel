import Foundation



// lexicon: 1, id: place.stream.branding.updateBlob


public struct PlaceStreamBrandingUpdateBlob { 

    public static let typeIdentifier = "place.stream.branding.updateBlob"
public struct Input: ATProtocolCodable {
        public let key: String
        public let broadcaster: DID?
        public let data: String
        public let mimeType: String
        public let width: Int?
        public let height: Int?

        /// Standard public initializer
        public init(key: String, broadcaster: DID? = nil, data: String, mimeType: String, width: Int? = nil, height: Int? = nil) {
            self.key = key
            self.broadcaster = broadcaster
            self.data = data
            self.mimeType = mimeType
            self.width = width
            self.height = height
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.key = try container.decode(String.self, forKey: .key)
            self.broadcaster = try container.decodeIfPresent(DID.self, forKey: .broadcaster)
            self.data = try container.decode(String.self, forKey: .data)
            self.mimeType = try container.decode(String.self, forKey: .mimeType)
            self.width = try container.decodeIfPresent(Int.self, forKey: .width)
            self.height = try container.decodeIfPresent(Int.self, forKey: .height)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(key, forKey: .key)
            try container.encodeIfPresent(broadcaster, forKey: .broadcaster)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encodeIfPresent(width, forKey: .width)
            try container.encodeIfPresent(height, forKey: .height)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let keyValue = try key.toCBORValue()
            map = map.adding(key: "key", value: keyValue)
            if let value = broadcaster {
                let broadcasterValue = try value.toCBORValue()
                map = map.adding(key: "broadcaster", value: broadcasterValue)
            }
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            let mimeTypeValue = try mimeType.toCBORValue()
            map = map.adding(key: "mimeType", value: mimeTypeValue)
            if let value = width {
                let widthValue = try value.toCBORValue()
                map = map.adding(key: "width", value: widthValue)
            }
            if let value = height {
                let heightValue = try value.toCBORValue()
                map = map.adding(key: "height", value: heightValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case key
            case broadcaster
            case data
            case mimeType
            case width
            case height
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool
            
            
        ) {
            
            
            self.success = success
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.The authenticated DID is not authorized to modify branding"
                case blobTooLarge = "BlobTooLarge.The blob exceeds the maximum size limit"
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

extension ATProtoClient.Place.Stream.Branding {
    // MARK: - updateBlob

    /// Update or create a branding asset blob. Requires admin authorization.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateBlob(
        
        input: PlaceStreamBrandingUpdateBlob.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamBrandingUpdateBlob.Output?) {
        let endpoint = "place.stream.branding.updateBlob"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.branding.updateBlob")
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
                let decodedData = try decoder.decode(PlaceStreamBrandingUpdateBlob.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.branding.updateBlob: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

