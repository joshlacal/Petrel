import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.requestFailover


public struct BlueCatbirdMlsChatRequestFailover { 

    public static let typeIdentifier = "blue.catbird.mlsChat.requestFailover"
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
        
        
        public let success: Bool
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool
            
            
        ) {
            
            
            self.success = success
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
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

extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - requestFailover

    /// Request sequencer failover for a conversation (spec §8.8) Request sequencer failover for a conversation. Called when >= 3 consecutive send timeouts occur over >= 2 minutes.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func requestFailover(
        
        input: BlueCatbirdMlsChatRequestFailover.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatRequestFailover.Output?) {
        let endpoint = "blue.catbird.mlsChat.requestFailover"
        
        var headers: [String: String] = [:]
        
        headers["Content-Type"] = "application/json"
        
        
        
        headers["Accept"] = "application/json"
        

        let requestData: Data? = try JSONEncoder().encode(input)
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.requestFailover")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatRequestFailover.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.requestFailover: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

