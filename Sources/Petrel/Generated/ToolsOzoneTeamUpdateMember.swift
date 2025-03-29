import Foundation



// lexicon: 1, id: tools.ozone.team.updateMember


public struct ToolsOzoneTeamUpdateMember { 

    public static let typeIdentifier = "tools.ozone.team.updateMember"
public struct Input: ATProtocolCodable {
            public let did: DID
            public let disabled: Bool?
            public let role: String?

            // Standard public initializer
            public init(did: DID, disabled: Bool? = nil, role: String? = nil) {
                self.did = did
                self.disabled = disabled
                self.role = role
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
                self.disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
                
                
                self.role = try container.decodeIfPresent(String.self, forKey: .role)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(did, forKey: .did)
                
                
                if let value = disabled {
                    
                    try container.encode(value, forKey: .disabled)
                    
                }
                
                
                if let value = role {
                    
                    try container.encode(value, forKey: .role)
                    
                }
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case did
                case disabled
                case role
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()
                
                // Add fields in lexicon-defined order
                
                
                
                let didValue = try (did as? DAGCBOREncodable)?.toCBORValue() ?? did
                map = map.adding(key: "did", value: didValue)
                
                
                
                if let value = disabled {
                    
                    
                    let disabledValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "disabled", value: disabledValue)
                    
                }
                
                
                
                if let value = role {
                    
                    
                    let roleValue = try (value as? DAGCBOREncodable)?.toCBORValue() ?? value
                    map = map.adding(key: "role", value: roleValue)
                    
                }
                
                
                
                return map
            }
        }
    public typealias Output = ToolsOzoneTeamDefs.Member
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case memberNotFound = "MemberNotFound.The member being updated does not exist in the team"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Tools.Ozone.Team {
    /// Update a member in the ozone service. Requires admin role.
    public func updateMember(
        
        input: ToolsOzoneTeamUpdateMember.Input
        
    ) async throws -> (responseCode: Int, data: ToolsOzoneTeamUpdateMember.Output?) {
        let endpoint = "tools.ozone.team.updateMember"
        
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
        let decodedData = try? decoder.decode(ToolsOzoneTeamUpdateMember.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
