import Foundation



// lexicon: 1, id: tools.ozone.moderation.getSubjects


public struct ToolsOzoneModerationGetSubjects { 

    public static let typeIdentifier = "tools.ozone.moderation.getSubjects"    
public struct Parameters: Parametrizable {
        public let subjects: [String]
        
        public init(
            subjects: [String]
            ) {
            self.subjects = subjects
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let subjects: [ToolsOzoneModerationDefs.SubjectView]
        
        
        
        // Standard public initializer
        public init(
            
            subjects: [ToolsOzoneModerationDefs.SubjectView]
            
            
        ) {
            
            self.subjects = subjects
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.subjects = try container.decode([ToolsOzoneModerationDefs.SubjectView].self, forKey: .subjects)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(subjects, forKey: .subjects)
            
            
        }
        
        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()
            
            // Add fields in lexicon-defined order
            
            
            
            let subjectsValue = try (subjects as? DAGCBOREncodable)?.toCBORValue() ?? subjects
            map = map.adding(key: "subjects", value: subjectsValue)
            
            
            
            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case subjects
            
        }
    }




}


extension ATProtoClient.Tools.Ozone.Moderation {
    /// Get details about subjects.
    public func getSubjects(input: ToolsOzoneModerationGetSubjects.Parameters) async throws -> (responseCode: Int, data: ToolsOzoneModerationGetSubjects.Output?) {
        let endpoint = "tools.ozone.moderation.getSubjects"
        
        
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
        let decodedData = try? decoder.decode(ToolsOzoneModerationGetSubjects.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
