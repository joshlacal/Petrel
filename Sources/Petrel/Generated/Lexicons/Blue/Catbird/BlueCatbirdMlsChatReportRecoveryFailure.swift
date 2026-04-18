import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.reportRecoveryFailure


public struct BlueCatbirdMlsChatReportRecoveryFailure { 

    public static let typeIdentifier = "blue.catbird.mlsChat.reportRecoveryFailure"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let failureType: String?
        public let epochAuthenticator: String?

        /// Standard public initializer
        public init(convoId: String, failureType: String? = nil, epochAuthenticator: String? = nil) {
            self.convoId = convoId
            self.failureType = failureType
            self.epochAuthenticator = epochAuthenticator
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.failureType = try container.decodeIfPresent(String.self, forKey: .failureType)
            self.epochAuthenticator = try container.decodeIfPresent(String.self, forKey: .epochAuthenticator)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(failureType, forKey: .failureType)
            try container.encodeIfPresent(epochAuthenticator, forKey: .epochAuthenticator)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = failureType {
                let failureTypeValue = try value.toCBORValue()
                map = map.adding(key: "failureType", value: failureTypeValue)
            }
            if let value = epochAuthenticator {
                let epochAuthenticatorValue = try value.toCBORValue()
                map = map.adding(key: "epochAuthenticator", value: epochAuthenticatorValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case failureType
            case epochAuthenticator
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let recorded: Bool
        
        public let autoResetTriggered: Bool
        
        public let failureCount: Int
        
        public let memberCount: Int
        
        public let reason: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            recorded: Bool,
            
            autoResetTriggered: Bool,
            
            failureCount: Int,
            
            memberCount: Int,
            
            reason: String? = nil
            
            
        ) {
            
            
            self.recorded = recorded
            
            self.autoResetTriggered = autoResetTriggered
            
            self.failureCount = failureCount
            
            self.memberCount = memberCount
            
            self.reason = reason
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.recorded = try container.decode(Bool.self, forKey: .recorded)
            
            
            self.autoResetTriggered = try container.decode(Bool.self, forKey: .autoResetTriggered)
            
            
            self.failureCount = try container.decode(Int.self, forKey: .failureCount)
            
            
            self.memberCount = try container.decode(Int.self, forKey: .memberCount)
            
            
            self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(recorded, forKey: .recorded)
            
            
            try container.encode(autoResetTriggered, forKey: .autoResetTriggered)
            
            
            try container.encode(failureCount, forKey: .failureCount)
            
            
            try container.encode(memberCount, forKey: .memberCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reason, forKey: .reason)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let recordedValue = try recorded.toCBORValue()
            map = map.adding(key: "recorded", value: recordedValue)
            
            
            
            let autoResetTriggeredValue = try autoResetTriggered.toCBORValue()
            map = map.adding(key: "autoResetTriggered", value: autoResetTriggeredValue)
            
            
            
            let failureCountValue = try failureCount.toCBORValue()
            map = map.adding(key: "failureCount", value: failureCountValue)
            
            
            
            let memberCountValue = try memberCount.toCBORValue()
            map = map.adding(key: "memberCount", value: memberCountValue)
            
            
            
            if let value = reason {
                // Encode optional property even if it's an empty array for CBOR
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case recorded
            case autoResetTriggered
            case failureCount
            case memberCount
            case reason
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
    // MARK: - reportRecoveryFailure

    /// Report that recovery has been exhausted for a conversation Report that a client has exhausted all recovery attempts for a conversation. Any member may report. When votes from at least ceil(2/3) of the active identity DIDs carry a valid epoch_authenticator within the 1-hour expiry window, the server auto-resets the group (see ADR-002).
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func reportRecoveryFailure(
        
        input: BlueCatbirdMlsChatReportRecoveryFailure.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatReportRecoveryFailure.Output?) {
        let endpoint = "blue.catbird.mlsChat.reportRecoveryFailure"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.reportRecoveryFailure")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatReportRecoveryFailure.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.reportRecoveryFailure: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

