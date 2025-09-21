import Foundation



// lexicon: 1, id: com.atproto.temp.fetchLabels


public struct ComAtprotoTempFetchLabels { 

    public static let typeIdentifier = "com.atproto.temp.fetchLabels"    
public struct Parameters: Parametrizable {
        public let since: Int?
        public let limit: Int?
        
        public init(
            since: Int? = nil, 
            limit: Int? = nil
            ) {
            self.since = since
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let labels: [ComAtprotoLabelDefs.Label]
        
        
        
        // Standard public initializer
        public init(
            
            labels: [ComAtprotoLabelDefs.Label]
            
            
        ) {
            
            self.labels = labels
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.labels = try container.decode([ComAtprotoLabelDefs.Label].self, forKey: .labels)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(labels, forKey: .labels)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let labelsValue = try labels.toCBORValue()
            map = map.adding(key: "labels", value: labelsValue)
            
            

            return map
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case labels
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Temp {
    // MARK: - fetchLabels

    /// DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func fetchLabels(input: ComAtprotoTempFetchLabels.Parameters) async throws -> (responseCode: Int, data: ComAtprotoTempFetchLabels.Output?) {
        let endpoint = "com.atproto.temp.fetchLabels"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        
        let (responseData, response) = try await networkService.performRequest(urlRequest)
        
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
                let decodedData = try decoder.decode(ComAtprotoTempFetchLabels.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for com.atproto.temp.fetchLabels: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           
