import Foundation
import ZippyJSON


// lexicon: 1, id: tools.ozone.team.listMembers


public struct ToolsOzoneTeamListMembers { 

    public static let typeIdentifier = "tools.ozone.team.listMembers"    
public struct Parameters: Parametrizable {
        public let limit: Int?
        public let cursor: String?
        
        public init(
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.limit = limit
            self.cursor = cursor
            
        }
    }    
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let members: [ToolsOzoneTeamDefs.Member]
        
        
        
        // Standard public initializer
        public init(
            
            cursor: String? = nil,
            
            members: [ToolsOzoneTeamDefs.Member]
            
            
        ) {
            
            self.cursor = cursor
            
            self.members = members
            
            
        }
    }




}


extension ATProtoClient.Tools.Ozone.Team {
    /// List all members with access to the ozone service.
    public func listMembers(input: ToolsOzoneTeamListMembers.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneTeamListMembers.Output?) {
        let endpoint = "tools.ozone.team.listMembers"
        
        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
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
        
        let decoder = ZippyJSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneTeamListMembers.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
