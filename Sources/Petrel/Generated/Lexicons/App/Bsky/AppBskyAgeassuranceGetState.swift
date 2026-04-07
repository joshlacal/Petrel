import Foundation



// lexicon: 1, id: app.bsky.ageassurance.getState


public struct AppBskyAgeassuranceGetState { 

    public static let typeIdentifier = "app.bsky.ageassurance.getState"    
public struct Parameters: Parametrizable {
        public let countryCode: String
        public let regionCode: String?
        
        public init(
            countryCode: String, 
            regionCode: String? = nil
            ) {
            self.countryCode = countryCode
            self.regionCode = regionCode
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let state: AppBskyAgeassuranceDefs.State
        
        public let metadata: AppBskyAgeassuranceDefs.StateMetadata
        
        
        
        // Standard public initializer
        public init(
            
            
            state: AppBskyAgeassuranceDefs.State,
            
            metadata: AppBskyAgeassuranceDefs.StateMetadata
            
            
        ) {
            
            
            self.state = state
            
            self.metadata = metadata
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.state = try container.decode(AppBskyAgeassuranceDefs.State.self, forKey: .state)
            
            
            self.metadata = try container.decode(AppBskyAgeassuranceDefs.StateMetadata.self, forKey: .metadata)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(state, forKey: .state)
            
            
            try container.encode(metadata, forKey: .metadata)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let stateValue = try state.toCBORValue()
            map = map.adding(key: "state", value: stateValue)
            
            
            
            let metadataValue = try metadata.toCBORValue()
            map = map.adding(key: "metadata", value: metadataValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case state
            case metadata
        }
        
    }




}



extension ATProtoClient.App.Bsky.Ageassurance {
    // MARK: - getState

    /// Returns server-computed Age Assurance state, if available, and any additional metadata needed to compute Age Assurance state client-side.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getState(input: AppBskyAgeassuranceGetState.Parameters) async throws -> (responseCode: Int, data: AppBskyAgeassuranceGetState.Output?) {
        let endpoint = "app.bsky.ageassurance.getState"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.ageassurance.getState")
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
                let decodedData = try decoder.decode(AppBskyAgeassuranceGetState.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.ageassurance.getState: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

