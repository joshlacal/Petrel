import Foundation



// lexicon: 1, id: tools.ozone.set.deleteSet


public struct ToolsOzoneSetDeleteSet { 

    public static let typeIdentifier = "tools.ozone.set.deleteSet"
public struct Input: ATProtocolCodable {
            public let name: String

            // Standard public initializer
            public init(name: String) {
                self.name = name
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.name = try container.decode(String.self, forKey: .name)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(name, forKey: .name)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case name
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let nameValue = try (name as? DAGCBOREncodable)?.toCBORValue() ?? name
                map = map.adding(key: "name", value: nameValue)
                
                
                
                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        public let data: Data
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
        ) {
            
            
            self.data = data
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            return data
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case data
            
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
    /// Delete an entire set. Attempting to delete a set that does not exist will result in an error.
    public func deleteSet(
        
        input: ToolsOzoneSetDeleteSet.Input
        
    ) async throws -> (responseCode: Int, data: ToolsOzoneSetDeleteSet.Output?) {
        let endpoint = "tools.ozone.set.deleteSet"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        
        
        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers, 
            body: requestData,
            queryItems: nil
        )
        
        
        let (responseData, response) = try await networkManager.performRequest(urlRequest)
        let responseCode = response.statusCode

        // Content-Type validation
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }
        
        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Data decoding and validation
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneSetDeleteSet.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
