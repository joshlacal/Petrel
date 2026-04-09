import Foundation



// lexicon: 1, id: place.stream.playback.getVideoPlaylist


public struct PlaceStreamPlaybackGetVideoPlaylist { 

    public static let typeIdentifier = "place.stream.playback.getVideoPlaylist"    
public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let track: Int?
        
        public init(
            uri: ATProtocolURI, 
            track: Int? = nil
            ) {
            self.uri = uri
            self.track = track
            
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




}



extension ATProtoClient.Place.Stream.Playback {
    // MARK: - getVideoPlaylist

    /// Get the HLS playlist for a video
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getVideoPlaylist(input: PlaceStreamPlaybackGetVideoPlaylist.Parameters) async throws -> (responseCode: Int, data: PlaceStreamPlaybackGetVideoPlaylist.Output?) {
        let endpoint = "place.stream.playback.getVideoPlaylist"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/vnd.apple.mpegurl"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.playback.getVideoPlaylist")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/vnd.apple.mpegurl", actual: "nil")
        }

        if !contentType.lowercased().contains("application/vnd.apple.mpegurl") {
            throw NetworkError.invalidContentType(expected: "application/vnd.apple.mpegurl", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decodedData = PlaceStreamPlaybackGetVideoPlaylist.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.playback.getVideoPlaylist: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

