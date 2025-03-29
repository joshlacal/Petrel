import Foundation



// lexicon: 1, id: tools.ozone.set.deleteValues


public struct ToolsOzoneSetDeleteValues { 

    public static let typeIdentifier = "tools.ozone.set.deleteValues"
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
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let nameValue = try (name as? DAGCBOREncodable)?.toCBORValue() ?? name
                map = map.adding(key: "name", value: nameValue)
                
                
                
                
                let valuesValue = try (values as? DAGCBOREncodable)?.toCBORValue() ?? values
                map = map.adding(key: "values", value: valuesValue)
                
                
                
                return map
            }
        }        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case setNotFound = "SetNotFound.set with the given name does not exist"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Tools.Ozone.Set {
    /// Delete values from a specific set. Attempting to delete values that are not in the set will not result in an error
    public func deleteValues(
        
        input: ToolsOzoneSetDeleteValues.Input
        
    ) async throws -> Int {
        let endpoint = "tools.ozone.set.deleteValues"
        
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
                           
