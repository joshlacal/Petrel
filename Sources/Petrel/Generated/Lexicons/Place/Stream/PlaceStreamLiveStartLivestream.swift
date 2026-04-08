import Foundation



// lexicon: 1, id: place.stream.live.startLivestream


public struct PlaceStreamLiveStartLivestream { 

    public static let typeIdentifier = "place.stream.live.startLivestream"
public struct Input: ATProtocolCodable {
        public let livestream: PlaceStreamLivestream
        public let streamer: DID
        public let createBlueskyPost: Bool?

        /// Standard public initializer
        public init(livestream: PlaceStreamLivestream, streamer: DID, createBlueskyPost: Bool? = nil) {
            self.livestream = livestream
            self.streamer = streamer
            self.createBlueskyPost = createBlueskyPost
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.livestream = try container.decode(PlaceStreamLivestream.self, forKey: .livestream)
            self.streamer = try container.decode(DID.self, forKey: .streamer)
            self.createBlueskyPost = try container.decodeIfPresent(Bool.self, forKey: .createBlueskyPost)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(livestream, forKey: .livestream)
            try container.encode(streamer, forKey: .streamer)
            try container.encodeIfPresent(createBlueskyPost, forKey: .createBlueskyPost)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let livestreamValue = try livestream.toCBORValue()
            map = map.adding(key: "livestream", value: livestreamValue)
            let streamerValue = try streamer.toCBORValue()
            map = map.adding(key: "streamer", value: streamerValue)
            if let value = createBlueskyPost {
                let createBlueskyPostValue = try value.toCBORValue()
                map = map.adding(key: "createBlueskyPost", value: createBlueskyPostValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case livestream
            case streamer
            case createBlueskyPost
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let uri: URI
        
        public let cid: CID
        
        
        
        // Standard public initializer
        public init(
            
            
            uri: URI,
            
            cid: CID
            
            
        ) {
            
            
            self.uri = uri
            
            self.cid = cid
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.uri = try container.decode(URI.self, forKey: .uri)
            
            
            self.cid = try container.decode(CID.self, forKey: .cid)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case uri
            case cid
        }
        
    }




}

extension ATProtoClient.Place.Stream.Live {
    // MARK: - startLivestream

    /// Create a new place.stream.livestream record, automatically populating a thumbnail and creating a Bluesky post and whatnot. You can do this manually by creating a record but this method can work better for mobile livestreaming and such.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func startLivestream(
        
        input: PlaceStreamLiveStartLivestream.Input
        
    ) async throws -> (responseCode: Int, data: PlaceStreamLiveStartLivestream.Output?) {
        let endpoint = "place.stream.live.startLivestream"
        
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
        let serviceDID = await networkService.getServiceDID(for: "place.stream.live.startLivestream")
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
                let decodedData = try decoder.decode(PlaceStreamLiveStartLivestream.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.live.startLivestream: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

