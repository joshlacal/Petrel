import Foundation



// lexicon: 1, id: chat.bsky.group.getGroupPublicInfo


public struct ChatBskyGroupGetGroupPublicInfo { 

    public static let typeIdentifier = "chat.bsky.group.getGroupPublicInfo"    
public struct Parameters: Parametrizable {
        public let code: String
        
        public init(
            code: String
            ) {
            self.code = code
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let group: ChatBskyGroupDefs.GroupPublicView
        
        
        
        // Standard public initializer
        public init(
            
            
            group: ChatBskyGroupDefs.GroupPublicView
            
            
        ) {
            
            
            self.group = group
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.group = try container.decode(ChatBskyGroupDefs.GroupPublicView.self, forKey: .group)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(group, forKey: .group)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let groupValue = try group.toCBORValue()
            map = map.adding(key: "group", value: groupValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case group
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidCode = "InvalidCode."
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
    // MARK: - getGroupPublicInfo

    /// [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about a group from an join link.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getGroupPublicInfo(input: ChatBskyGroupGetGroupPublicInfo.Parameters) async throws -> (responseCode: Int, data: ChatBskyGroupGetGroupPublicInfo.Output?) {
        let endpoint = "chat.bsky.group.getGroupPublicInfo"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "chat.bsky.group.getGroupPublicInfo")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled via the status code / structured error parser below.
        if (200...299).contains(responseCode) {
            
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }
            

            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(ChatBskyGroupGetGroupPublicInfo.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for chat.bsky.group.getGroupPublicInfo: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

