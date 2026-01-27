import Foundation



// lexicon: 1, id: chat.bsky.convo.getConvoForMembers


public struct ChatBskyConvoGetConvoForMembers { 

    public static let typeIdentifier = "chat.bsky.convo.getConvoForMembers"    
public struct Parameters: Parametrizable {
        public let members: [DID]
        
        public init(
            members: [DID]
            ) {
            self.members = members
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convo: ChatBskyConvoDefs.ConvoView
        
        
        
        // Standard public initializer
        public init(
            
            
            convo: ChatBskyConvoDefs.ConvoView
            
            
        ) {
            
            
            self.convo = convo
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convo = try container.decode(ChatBskyConvoDefs.ConvoView.self, forKey: .convo)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convo, forKey: .convo)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convo
        }
        
    }




}



extension ATProtoClient.Chat.Bsky.Convo {
    // MARK: - getConvoForMembers

    /// 
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getConvoForMembers(input: ChatBskyConvoGetConvoForMembers.Parameters) async throws -> (responseCode: Int, data: ChatBskyConvoGetConvoForMembers.Output?) {
        let endpoint = "chat.bsky.convo.getConvoForMembers"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.convo.getConvoForMembers")
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
                let decodedData = try decoder.decode(ChatBskyConvoGetConvoForMembers.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.convo.getConvoForMembers: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

