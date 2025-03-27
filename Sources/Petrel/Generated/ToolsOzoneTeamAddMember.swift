import Foundation



// lexicon: 1, id: tools.ozone.team.addMember


public struct ToolsOzoneTeamAddMember { 

    public static let typeIdentifier = "tools.ozone.team.addMember"
public struct Input: ATProtocolCodable {
            public let did: String
            public let role: String

            // Standard public initializer
            public init(did: String, role: String) {
                self.did = did
                self.role = role
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.did = try container.decode(String.self, forKey: .did)
                
                
                self.role = try container.decode(String.self, forKey: .role)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(did, forKey: .did)
                
                
                try container.encode(role, forKey: .role)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case did
                case role
            }
        }
    public typealias Output = ToolsOzoneTeamDefs.Member
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case memberAlreadyExists = "MemberAlreadyExists.Member already exists in the team."
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Tools.Ozone.Team {
    /// Add a member to the ozone team. Requires admin role.
    public func addMember(
        
        input: ToolsOzoneTeamAddMember.Input
        
    ) async throws -> (responseCode: Int, data: ToolsOzoneTeamAddMember.Output?) {
        let endpoint = "tools.ozone.team.addMember"
        
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
        let decodedData = try? decoder.decode(ToolsOzoneTeamAddMember.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
        
    }
    
}
                           
