import Foundation



// lexicon: 1, id: place.stream.config.getEnv


public struct PlaceStreamConfigGetEnv { 

    public static let typeIdentifier = "place.stream.config.getEnv"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let playbackWorkerUrl: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            playbackWorkerUrl: String? = nil
            
            
        ) {
            
            
            self.playbackWorkerUrl = playbackWorkerUrl
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.playbackWorkerUrl = try container.decodeIfPresent(String.self, forKey: .playbackWorkerUrl)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(playbackWorkerUrl, forKey: .playbackWorkerUrl)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = playbackWorkerUrl {
                // Encode optional property even if it's an empty array for CBOR
                let playbackWorkerUrlValue = try value.toCBORValue()
                map = map.adding(key: "playbackWorkerUrl", value: playbackWorkerUrlValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case playbackWorkerUrl
        }
        
    }




}



extension ATProtoClient.Place.Stream.Config {
    // MARK: - getEnv

    /// Get client-facing environment configuration from the server.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getEnv(input: PlaceStreamConfigGetEnv.Parameters) async throws -> (responseCode: Int, data: PlaceStreamConfigGetEnv.Output?) {
        let endpoint = "place.stream.config.getEnv"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.config.getEnv")
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
                let decodedData = try decoder.decode(PlaceStreamConfigGetEnv.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.config.getEnv: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

