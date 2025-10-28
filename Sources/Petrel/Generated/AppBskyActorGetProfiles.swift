import Foundation



// lexicon: 1, id: app.bsky.actor.getProfiles


public struct AppBskyActorGetProfiles { 

    public static let typeIdentifier = "app.bsky.actor.getProfiles"    
public struct Parameters: Parametrizable {
        public let actors: [ATIdentifier]
        
        public init(
            actors: [ATIdentifier]
            ) {
            self.actors = actors
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let profiles: [AppBskyActorDefs.ProfileViewDetailed]
        
        
        
        // Standard public initializer
        public init(
            
            
            profiles: [AppBskyActorDefs.ProfileViewDetailed]
            
            
        ) {
            
            
            self.profiles = profiles
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.profiles = try container.decode([AppBskyActorDefs.ProfileViewDetailed].self, forKey: .profiles)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(profiles, forKey: .profiles)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let profilesValue = try profiles.toCBORValue()
            map = map.adding(key: "profiles", value: profilesValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case profiles
        }
        
    }




}


extension ATProtoClient.App.Bsky.Actor {
    // MARK: - getProfiles

    /// Get detailed profile views of multiple actors.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getProfiles(input: AppBskyActorGetProfiles.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfiles.Output?) {
        let endpoint = "app.bsky.actor.getProfiles"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.actor.getProfiles")
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
                let decodedData = try decoder.decode(AppBskyActorGetProfiles.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for app.bsky.actor.getProfiles: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

