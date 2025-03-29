import Foundation



// lexicon: 1, id: app.bsky.graph.unmuteThread


public struct AppBskyGraphUnmuteThread { 

    public static let typeIdentifier = "app.bsky.graph.unmuteThread"
public struct Input: ATProtocolCodable {
            public let root: ATProtocolURI

            // Standard public initializer
            public init(root: ATProtocolURI) {
                self.root = root
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.root = try container.decode(ATProtocolURI.self, forKey: .root)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(root, forKey: .root)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case root
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let rootValue = try (root as? DAGCBOREncodable)?.toCBORValue() ?? root
                map = map.adding(key: "root", value: rootValue)
                
                
                
                return map
            }
        }



}

extension ATProtoClient.App.Bsky.Graph {
    /// Unmutes the specified thread. Requires auth.
    public func unmuteThread(
        
        input: AppBskyGraphUnmuteThread.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteThread"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (_, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode
        return responseCode
        
    }
    
}
                           
