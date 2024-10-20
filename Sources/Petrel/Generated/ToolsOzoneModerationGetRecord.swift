import Foundation
import ZippyJSON


// lexicon: 1, id: tools.ozone.moderation.getRecord


public struct ToolsOzoneModerationGetRecord { 

    public static let typeIdentifier = "tools.ozone.moderation.getRecord"    
public struct Parameters: Parametrizable {
        public let uri: ATProtocolURI
        public let cid: String?
        
        public init(
            uri: ATProtocolURI, 
            cid: String? = nil
            ) {
            self.uri = uri
            self.cid = cid
            
        }
    }    
    public typealias Output = ToolsOzoneModerationDefs.RecordViewDetail
            
public enum Error: String, Swift.Error, CustomStringConvertible {
                case recordNotFound = "RecordNotFound."
            public var description: String {
                return self.rawValue
            }
        }



}


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about a record.
    public func getRecord(input: ToolsOzoneModerationGetRecord.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetRecord.Output?) {
        let endpoint = "tools.ozone.moderation.getRecord"
        
        
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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetRecord.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
