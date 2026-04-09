import Foundation



// lexicon: 1, id: place.stream.broadcast.getBroadcaster


public struct PlaceStreamBroadcastGetBroadcaster { 

    public static let typeIdentifier = "place.stream.broadcast.getBroadcaster"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let broadcaster: DID
        
        public let server: DID?
        
        public let admins: [DID]?
        
        
        
        // Standard public initializer
        public init(
            
            
            broadcaster: DID,
            
            server: DID? = nil,
            
            admins: [DID]? = nil
            
            
        ) {
            
            
            self.broadcaster = broadcaster
            
            self.server = server
            
            self.admins = admins
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.broadcaster = try container.decode(DID.self, forKey: .broadcaster)
            
            
            self.server = try container.decodeIfPresent(DID.self, forKey: .server)
            
            
            self.admins = try container.decodeIfPresent([DID].self, forKey: .admins)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(broadcaster, forKey: .broadcaster)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(server, forKey: .server)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(admins, forKey: .admins)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let broadcasterValue = try broadcaster.toCBORValue()
            map = map.adding(key: "broadcaster", value: broadcasterValue)
            
            
            
            if let value = server {
                // Encode optional property even if it's an empty array for CBOR
                let serverValue = try value.toCBORValue()
                map = map.adding(key: "server", value: serverValue)
            }
            
            
            
            if let value = admins {
                // Encode optional property even if it's an empty array for CBOR
                let adminsValue = try value.toCBORValue()
                map = map.adding(key: "admins", value: adminsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case broadcaster
            case server
            case admins
        }
        
    }




}



extension ATProtoClient.Place.Stream.Broadcast {
    // MARK: - getBroadcaster

    /// Get information about a Streamplace broadcaster.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBroadcaster(input: PlaceStreamBroadcastGetBroadcaster.Parameters) async throws -> (responseCode: Int, data: PlaceStreamBroadcastGetBroadcaster.Output?) {
        let endpoint = "place.stream.broadcast.getBroadcaster"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.broadcast.getBroadcaster")
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
                let decodedData = try decoder.decode(PlaceStreamBroadcastGetBroadcaster.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.broadcast.getBroadcaster: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

