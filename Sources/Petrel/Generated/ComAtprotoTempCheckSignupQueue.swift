import Foundation



// lexicon: 1, id: com.atproto.temp.checkSignupQueue


public struct ComAtprotoTempCheckSignupQueue { 

    public static let typeIdentifier = "com.atproto.temp.checkSignupQueue"
    
public struct Output: ATProtocolCodable {
        
        
        public let activated: Bool
        
        public let placeInQueue: Int?
        
        public let estimatedTimeMs: Int?
        
        
        
        // Standard public initializer
        public init(
            
            activated: Bool,
            
            placeInQueue: Int? = nil,
            
            estimatedTimeMs: Int? = nil
            
            
        ) {
            
            self.activated = activated
            
            self.placeInQueue = placeInQueue
            
            self.estimatedTimeMs = estimatedTimeMs
            
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            
            self.activated = try container.decode(Bool.self, forKey: .activated)
            
            
            self.placeInQueue = try container.decodeIfPresent(Int.self, forKey: .placeInQueue)
            
            
            self.estimatedTimeMs = try container.decodeIfPresent(Int.self, forKey: .estimatedTimeMs)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            
            try container.encode(activated, forKey: .activated)
            
            
            if let value = placeInQueue {
                
                try container.encode(value, forKey: .placeInQueue)
                
            }
            
            
            if let value = estimatedTimeMs {
                
                try container.encode(value, forKey: .estimatedTimeMs)
                
            }
            
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case activated
            case placeInQueue
            case estimatedTimeMs
            
        }
    }




}


extension ATProtoClient.Com.Atproto.Temp {
    /// Check accounts location in signup queue.
    public func checkSignupQueue() async throws -> (responseCode: Int, data: ComAtprotoTempCheckSignupQueue.Output?) {
        let endpoint = "com.atproto.temp.checkSignupQueue"
        
        
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
        
        let decoder = JSONDecoder()
        let decodedData = try? decoder.decode(ComAtprotoTempCheckSignupQueue.Output.self, from: responseData)
        
        
        return (responseCode, decodedData)
    }
}                           
