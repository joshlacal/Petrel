import Foundation



// lexicon: 1, id: tools.ozone.communication.deleteTemplate


public struct ToolsOzoneCommunicationDeleteTemplate { 

    public static let typeIdentifier = "tools.ozone.communication.deleteTemplate"
public struct Input: ATProtocolCodable {
            public let id: String

            // Standard public initializer
            public init(id: String) {
                self.id = id
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.id = try container.decode(String.self, forKey: .id)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(id, forKey: .id)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case id
            }
        }



}

extension ATProtoClient.Tools.Ozone.Communication {
    /// Delete a communication template.
    public func deleteTemplate(
        
        input: ToolsOzoneCommunicationDeleteTemplate.Input
        
    ) async throws -> Int {
        let endpoint = "tools.ozone.communication.deleteTemplate"
        
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
                           
