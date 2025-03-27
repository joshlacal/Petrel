import Foundation



// lexicon: 1, id: tools.ozone.moderation.getReporterStats


public struct ToolsOzoneModerationGetReporterStats { 

    public static let typeIdentifier = "tools.ozone.moderation.getReporterStats"    
public struct Parameters: Parametrizable {
        public let dids: [String]
        
        public init(
            dids: [String]
            ) {
            self.dids = dids
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let stats: [ToolsOzoneModerationDefs.ReporterStats]
        
        
        
        // Standard public initializer
        public init(
            
            stats: [ToolsOzoneModerationDefs.ReporterStats]
            
            
        ) {
            
            self.stats = stats
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.stats = try container.decode([ToolsOzoneModerationDefs.ReporterStats].self, forKey: .stats)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(stats, forKey: .stats)
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case stats
            
        }
    }




}


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get reporter stats for a list of users.
    public func getReporterStats(input: ToolsOzoneModerationGetReporterStats.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetReporterStats.Output?) {
        let endpoint = "tools.ozone.moderation.getReporterStats"
        
        
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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetReporterStats.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
