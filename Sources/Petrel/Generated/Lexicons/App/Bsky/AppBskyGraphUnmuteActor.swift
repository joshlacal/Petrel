import Foundation



// lexicon: 1, id: app.bsky.graph.unmuteActor


public struct AppBskyGraphUnmuteActor { 

    public static let typeIdentifier = "app.bsky.graph.unmuteActor"
public struct Input: ATProtocolCodable {
            public let actor: ATIdentifier

            // Standard public initializer
            public init(actor: ATIdentifier) {
                self.actor = actor
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.actor = try container.decode(ATIdentifier.self, forKey: .actor)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(actor, forKey: .actor)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case actor
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let actorValue = try actor.toCBORValue()
                map = map.adding(key: "actor", value: actorValue)
                
                

                return map
            }
        }



}

extension ATProtoClient.App.Bsky.Graph {
    // MARK: - unmuteActor

    /// Unmutes the specified account. Requires auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: The HTTP response code
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func unmuteActor(
        
        input: AppBskyGraphUnmuteActor.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteActor"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "app.bsky.graph.unmuteActor")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (_, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        return responseCode
        
    }
    
}
                           

