import Foundation



// lexicon: 1, id: chat.bsky.group.disableJoinLink


public struct ChatBskyGroupDisableJoinLink { 

    public static let typeIdentifier = "chat.bsky.group.disableJoinLink"
public struct Input: ATProtocolCodable {
        public let convoId: String

        /// Standard public initializer
        public init(convoId: String) {
            self.convoId = convoId
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let joinLink: ChatBskyGroupDefs.JoinLinkView
        
        
        
        // Standard public initializer
        public init(
            
            
            joinLink: ChatBskyGroupDefs.JoinLinkView
            
            
        ) {
            
            
            self.joinLink = joinLink
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.joinLink = try container.decode(ChatBskyGroupDefs.JoinLinkView.self, forKey: .joinLink)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(joinLink, forKey: .joinLink)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let joinLinkValue = try joinLink.toCBORValue()
            map = map.adding(key: "joinLink", value: joinLinkValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case joinLink
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidConvo = "InvalidConvo."
                case insufficientRole = "InsufficientRole."
                case noJoinLink = "NoJoinLink."
            public var description: String {
                return self.rawValue
            }

            public var errorName: String {
                // Extract just the error name from the raw value
                let parts = self.rawValue.split(separator: ".")
                return String(parts.first ?? "")
            }
        }



}

extension ATProtoClient.Chat.Bsky.Group {
    // MARK: - disableJoinLink

    /// [NOTE: This is under active development and should be considered unstable while this note is here]. Disables the active join link for the group convo.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func disableJoinLink(
        
        input: ChatBskyGroupDisableJoinLink.Input
        
    ) async throws -> (responseCode: Int, data: ChatBskyGroupDisableJoinLink.Output?) {
        let endpoint = "chat.bsky.group.disableJoinLink"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        
        let requestData: Data? = try JSONEncoder().encode(input)
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.disableJoinLink")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200...299).contains(responseCode) {
            
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }
            

            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyGroupDisableJoinLink.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.disableJoinLink: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

