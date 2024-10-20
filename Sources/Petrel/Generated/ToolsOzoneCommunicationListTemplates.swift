import Foundation
import ZippyJSON


// lexicon: 1, id: tools.ozone.communication.listTemplates


public struct ToolsOzoneCommunicationListTemplates { 

    public static let typeIdentifier = "tools.ozone.communication.listTemplates"    
    
public struct Output: ATProtocolCodable {
        
        
        public let communicationTemplates: [ToolsOzoneCommunicationDefs.TemplateView]
        
        
        
        // Standard public initializer
        public init(
            
            communicationTemplates: [ToolsOzoneCommunicationDefs.TemplateView]
            
            
        ) {
            
            self.communicationTemplates = communicationTemplates
            
            
        }
    }




}


extension ATProtoClient.Tools.Ozone.Communication {
    /// Get list of all communication templates.
    public func listTemplates() async throws -> (responseCode: Int, data: ToolsOzoneCommunicationListTemplates.Output?) {
        let endpoint = "tools.ozone.communication.listTemplates"
        
        
        let queryItems: [URLQueryItem]? = nil
        
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
        let decodedData = try? decoder.decode(ToolsOzoneCommunicationListTemplates.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
