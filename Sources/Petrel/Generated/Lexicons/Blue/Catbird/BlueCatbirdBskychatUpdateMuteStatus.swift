import Foundation




// lexicon: 1, id: blue.catbird.bskychat.updateMuteStatus


public struct BlueCatbirdBskychatUpdateMuteStatus { 

    public static let typeIdentifier = "blue.catbird.bskychat.updateMuteStatus"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let muted: Bool

        /// Standard public initializer
        public init(convoId: String, muted: Bool) {
            self.convoId = convoId
            self.muted = muted
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.muted = try container.decode(Bool.self, forKey: .muted)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(muted, forKey: .muted)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let mutedValue = try muted.toCBORValue()
            map = map.adding(key: "muted", value: mutedValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case muted
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




}

extension ATProtoClient.Blue.Catbird.Bskychat {
    // MARK: - updateMuteStatus

    /// Update the server-side mute status for a conversation. Used for push notification suppression.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateMuteStatus(
        
        input: BlueCatbirdBskychatUpdateMuteStatus.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdBskychatUpdateMuteStatus.Output?) {
        let endpoint = "blue.catbird.bskychat.updateMuteStatus"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.bskychat.updateMuteStatus")
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
                let decodedData = try decoder.decode(BlueCatbirdBskychatUpdateMuteStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.bskychat.updateMuteStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
}
                           

