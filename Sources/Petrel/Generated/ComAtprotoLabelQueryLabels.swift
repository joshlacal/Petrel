import Foundation



// lexicon: 1, id: com.atproto.label.queryLabels


public struct ComAtprotoLabelQueryLabels { 

    public static let typeIdentifier = "com.atproto.label.queryLabels"    
public struct Parameters: Parametrizable {
        public let uriPatterns: [String]
        public let sources: [DID]?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            uriPatterns: [String], 
            sources: [DID]? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.uriPatterns = uriPatterns
            self.sources = sources
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let cursor: String?
        
        public let labels: [ComAtprotoLabelDefs.Label]
        
        
        
        // Standard public initializer
        public init(
            
            
            cursor: String? = nil,
            
            labels: [ComAtprotoLabelDefs.Label]
            
            
        ) {
            
            
            self.cursor = cursor
            
            self.labels = labels
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
            self.labels = try container.decode([ComAtprotoLabelDefs.Label].self, forKey: .labels)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
            try container.encode(labels, forKey: .labels)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            
            
            let labelsValue = try labels.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case cursor
            case labels
        }
        
    }




}



extension ATProtoClient.Com.Atproto.Label {
    // MARK: - queryLabels

    /// Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func queryLabels(input: ComAtprotoLabelQueryLabels.Parameters) async throws -> (responseCode: Int, data: ComAtprotoLabelQueryLabels.Output?) {
        let endpoint = "com.atproto.label.queryLabels"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "com.atproto.label.queryLabels")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
        }

        if !contentType.lowercased().contains("application/json") {
            throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ComAtprotoLabelQueryLabels.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.label.queryLabels: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

