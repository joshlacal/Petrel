import Foundation



// lexicon: 1, id: tools.ozone.setting.upsertOption


public struct ToolsOzoneSettingUpsertOption { 

    public static let typeIdentifier = "tools.ozone.setting.upsertOption"
public struct Input: ATProtocolCodable {
            public let key: String
            public let scope: String
            public let value: ATProtocolValueContainer
            public let description: String?
            public let managerRole: String?

            // Standard public initializer
            public init(key: String, scope: String, value: ATProtocolValueContainer, description: String? = nil, managerRole: String? = nil) {
                self.key = key
                self.scope = scope
                self.value = value
                self.description = description
                self.managerRole = managerRole
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.key = try container.decode(String.self, forKey: .key)
                
                
                self.scope = try container.decode(String.self, forKey: .scope)
                
                
                self.value = try container.decode(ATProtocolValueContainer.self, forKey: .value)
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
                self.managerRole = try container.decodeIfPresent(String.self, forKey: .managerRole)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(key, forKey: .key)
                
                
                try container.encode(scope, forKey: .scope)
                
                
                try container.encode(value, forKey: .value)
                
                
                if let value = description {
                    
                    try container.encode(value, forKey: .description)
                    
                }
                
                
                if let value = managerRole {
                    
                    try container.encode(value, forKey: .managerRole)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case key
                case scope
                case value
                case description
                case managerRole
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let option: ToolsOzoneSettingDefs.Option
        
        
        
        // Standard public initializer
        public init(
            
            option: ToolsOzoneSettingDefs.Option
            
            
        ) {
            
            self.option = option
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.option = try container.decode(ToolsOzoneSettingDefs.Option.self, forKey: .option)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(option, forKey: .option)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case option
            
        }
    }




}

extension ATProtoClient.Tools.Ozone.Setting {
    /// Create or update setting option
    public func upsertOption(
        
        input: ToolsOzoneSettingUpsertOption.Input
        
    ) async throws -> (responseCode: Int, data: ToolsOzoneSettingUpsertOption.Output?) {
        let endpoint = "tools.ozone.setting.upsertOption"
        
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
        let decodedData = try? decoder.decode(ToolsOzoneSettingUpsertOption.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
