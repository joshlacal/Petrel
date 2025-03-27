import Foundation



// lexicon: 1, id: tools.ozone.team.deleteMember


public struct ToolsOzoneTeamDeleteMember { 

    public static let typeIdentifier = "tools.ozone.team.deleteMember"
public struct Input: ATProtocolCodable {
            public let did: String

            // Standard public initializer
            public init(did: String) {
                self.did = did
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.did = try container.decode(String.self, forKey: .did)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(did, forKey: .did)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case did
            }
        }        
public enum Error: String, Swift.Error, CustomStringConvertible {
                case memberNotFound = "MemberNotFound.The member being deleted does not exist"
                case cannotDeleteSelf = "CannotDeleteSelf.You can not delete yourself from the team"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Tools.Ozone.Team {
    /// Delete a member from ozone team. Requires admin role.
    public func deleteMember(
        
        input: ToolsOzoneTeamDeleteMember.Input
        
    ) async throws -> Int {
        let endpoint = "tools.ozone.team.deleteMember"
        
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
                           
