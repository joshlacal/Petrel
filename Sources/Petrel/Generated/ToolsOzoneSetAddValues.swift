import Foundation



// lexicon: 1, id: tools.ozone.set.addValues


public struct ToolsOzoneSetAddValues { 

    public static let typeIdentifier = "tools.ozone.set.addValues"
public struct Input: ATProtocolCodable {
            public let name: String
            public let values: [String]

            // Standard public initializer
            public init(name: String, values: [String]) {
                self.name = name
                self.values = values
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.name = try container.decode(String.self, forKey: .name)
                
                
                self.values = try container.decode([String].self, forKey: .values)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(name, forKey: .name)
                
                
                try container.encode(values, forKey: .values)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case name
                case values
            }
        }



}

extension ATProtoClient.Tools.Ozone.Set {
    /// Add values to a specific set. Attempting to add values to a set that does not exist will result in an error.
    public func addValues(
        
        input: ToolsOzoneSetAddValues.Input
        
    ) async throws -> Int {
        let endpoint = "tools.ozone.set.addValues"
        
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
                           
