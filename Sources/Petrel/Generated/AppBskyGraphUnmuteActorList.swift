import Foundation



// lexicon: 1, id: app.bsky.graph.unmuteActorList


public struct AppBskyGraphUnmuteActorList { 

    public static let typeIdentifier = "app.bsky.graph.unmuteActorList"
public struct Input: ATProtocolCodable {
            public let list: ATProtocolURI

            // Standard public initializer
            public init(list: ATProtocolURI) {
                self.list = list
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.list = try container.decode(ATProtocolURI.self, forKey: .list)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(list, forKey: .list)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case list
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let listValue = try (list as? DAGCBOREncodable)?.toCBORValue() ?? list
                map = map.adding(key: "list", value: listValue)
                
                
                
                return map
            }
        }



}

extension ATProtoClient.App.Bsky.Graph {
    /// Unmutes the specified list of accounts. Requires auth.
    public func unmuteActorList(
        
        input: AppBskyGraphUnmuteActorList.Input
        
    ) async throws -> Int {
        let endpoint = "app.bsky.graph.unmuteActorList"
        
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
                           
