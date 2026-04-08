import Foundation



// lexicon: 1, id: place.stream.multistream.deleteTarget


public struct PlaceStreamMultistreamDeleteTarget { 

    public static let typeIdentifier = "place.stream.multistream.deleteTarget"
public struct Input: ATProtocolCodable {
        public let rkey: RecordKey

        /// Standard public initializer
        public init(rkey: RecordKey) {
            self.rkey = rkey
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.rkey = try container.decode(RecordKey.self, forKey: .rkey)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rkey, forKey: .rkey)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let rkeyValue = try rkey.toCBORValue()
            map = map.adding(key: "rkey", value: rkeyValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case rkey
        }
    }
    
public struct Output: ATProtocolCodable {
        
        // Empty output - no properties (response is {})
        
        
        // Standard public initializer
        public init(
            
        ) {
            
        }
        
        public init(from decoder: Decoder) throws {
            
            // Empty output - just validate it's an object by trying to get any container
            _ = try decoder.singleValueContainer()
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            // Empty output - encode empty object
            _ = encoder.singleValueContainer()
            
        }

        public func toCBORValue() throws -> Any {
            
            // Empty output - return empty CBOR map
            return OrderedCBORMap()
            
        }
        
        
    }




}

extension ATProtoClient.Place.Stream.Multistream {
    // MARK: - deleteTarget

    /// Delete a target for rebroadcasting a Streamplace stream.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deleteTarget(
        
        input: PlaceStreamMultistreamDeleteTarget.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamMultistreamDeleteTarget.Output?) {
        let endpoint = "place.stream.multistream.deleteTarget"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.multistream.deleteTarget")
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
                let decodedData = try decoder.decode(PlaceStreamMultistreamDeleteTarget.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.multistream.deleteTarget: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

