import Foundation



// lexicon: 1, id: tools.ozone.moderation.getRepo


public struct ToolsOzoneModerationGetRepo { 

    public static let typeIdentifier = "tools.ozone.moderation.getRepo"    
public struct Parameters: Parametrizable {
        public let did: DID
        
        public init(
            did: DID
            ) {
            self.did = did
            
        }
    }
    public typealias Output = ToolsOzoneModerationDefs.RepoViewDetail
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case repoNotFound = "RepoNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about a repository.
    public func getRepo(input: ToolsOzoneModerationGetRepo.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRepo.Output?) {
        let endpoint = "tools.ozone.moderation.getRepo"
        
        
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRepo.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
