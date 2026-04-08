import Foundation



// lexicon: 1, id: place.stream.live.getSegments


public struct PlaceStreamLiveGetSegments { 

    public static let typeIdentifier = "place.stream.live.getSegments"    
public struct Parameters: Parametrizable {
        public let userDID: DID
        public let limit: Int?
        public let before: ATProtocolDate?
        
        public init(
            userDID: DID, 
            limit: Int? = nil, 
            before: ATProtocolDate? = nil
            ) {
            self.userDID = userDID
            self.limit = limit
            self.before = before
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let segments: [PlaceStreamSegment.SegmentView]?
        
        
        
        // Standard public initializer
        public init(
            
            
            segments: [PlaceStreamSegment.SegmentView]? = nil
            
            
        ) {
            
            
            self.segments = segments
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.segments = try container.decodeIfPresent([PlaceStreamSegment.SegmentView].self, forKey: .segments)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(segments, forKey: .segments)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = segments {
                // Encode optional property even if it's an empty array for CBOR
                let segmentsValue = try value.toCBORValue()
                map = map.adding(key: "segments", value: segmentsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case segments
        }
        
    }




}



extension ATProtoClient.Place.Stream.Live {
    // MARK: - getSegments

    /// Get a list of livestream segments for a user
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getSegments(input: PlaceStreamLiveGetSegments.Parameters) async throws -> (responseCode: Int, data: PlaceStreamLiveGetSegments.Output?) {
        let endpoint = "place.stream.live.getSegments"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.getSegments")
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
                let decodedData = try decoder.decode(PlaceStreamLiveGetSegments.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.getSegments: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

