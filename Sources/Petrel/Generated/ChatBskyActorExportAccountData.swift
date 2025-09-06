import Foundation



// lexicon: 1, id: chat.bsky.actor.exportAccountData


public struct ChatBskyActorExportAccountData { 

    public static let typeIdentifier = "chat.bsky.actor.exportAccountData"
    
public struct Output: ATProtocolCodable {
        
        public let data: Data
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
        ) {
            
            
            self.data = data
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let data = try container.decode(Data.self, forKey: .data)
            self.data = data
            
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
        }

        public func toCBORValue() throws -> Any {
            
            return data
            
        }
        
        private enum CodingKeys: String, CodingKey {
            
            case data
            
        }
    }




}


extension ATProtoClient.Chat.Bsky.Actor {
    // MARK: - exportAccountData

    /// 
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func exportAccountData() async throws -> (responseCode: Int, data: ChatBskyActorExportAccountData.Output?) {
        let endpoint = "chat.bsky.actor.exportAccountData"

        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/jsonl"],
            body: nil,
            queryItems: queryItems
        )

        
        // Chat endpoint - use proxy header
        let proxyHeaders = ["atproto-proxy": "did:web:api.bsky.chat#bsky_chat"]
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "application/jsonl", actual: "nil")
        }

        if !contentType.lowercased().contains("application/jsonl") {
            throw NetworkError.invalidContentType(expected: "application/jsonl", actual: contentType)
        }

        
        let decodedData = ChatBskyActorExportAccountData.Output(data: responseData)
        

        return (responseCode, decodedData)
    }
}                           
