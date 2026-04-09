import Foundation



// lexicon: 1, id: place.stream.server.getServerTime


public struct PlaceStreamServerGetServerTime { 

    public static let typeIdentifier = "place.stream.server.getServerTime"    
public struct Parameters: Parametrizable {
        
        public init(
            ) {
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let serverTime: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            serverTime: ATProtocolDate
            
            
        ) {
            
            
            self.serverTime = serverTime
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.serverTime = try container.decode(ATProtocolDate.self, forKey: .serverTime)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(serverTime, forKey: .serverTime)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let serverTimeValue = try serverTime.toCBORValue()
            map = map.adding(key: "serverTime", value: serverTimeValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case serverTime
        }
        
    }




}



extension ATProtoClient.Place.Stream.Server {
    // MARK: - getServerTime

    /// Get the current server time for client clock synchronization
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getServerTime(input: PlaceStreamServerGetServerTime.Parameters) async throws -> (responseCode: Int, data: PlaceStreamServerGetServerTime.Output?) {
        let endpoint = "place.stream.server.getServerTime"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "place.stream.server.getServerTime")
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
                let decodedData = try decoder.decode(PlaceStreamServerGetServerTime.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for place.stream.server.getServerTime: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

