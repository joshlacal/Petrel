import Foundation



// lexicon: 1, id: place.stream.playback.getPlaybackServer


public struct PlaceStreamPlaybackGetPlaybackServer { 

    public static let typeIdentifier = "place.stream.playback.getPlaybackServer"    
public struct Parameters: Parametrizable {
        public let stream: String
        
        public init(
            stream: String
            ) {
            self.stream = stream
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let servers: [String]
        
        
        
        // Standard public initializer
        public init(
            
            
            servers: [String]
            
            
        ) {
            
            
            self.servers = servers
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.servers = try container.decode([String].self, forKey: .servers)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(servers, forKey: .servers)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let serversValue = try servers.toCBORValue()
            map = map.adding(key: "servers", value: serversValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case servers
        }
        
    }




}



extension ATProtoClient.Place.Stream.Playback {
    // MARK: - getPlaybackServer

    /// Get available playback servers for a livestream.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPlaybackServer(input: PlaceStreamPlaybackGetPlaybackServer.Parameters) async throws -> (responseCode: Int, data: PlaceStreamPlaybackGetPlaybackServer.Output?) {
        let endpoint = "place.stream.playback.getPlaybackServer"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.playback.getPlaybackServer")
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
                let decodedData = try decoder.decode(PlaceStreamPlaybackGetPlaybackServer.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.playback.getPlaybackServer: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

