import Foundation



// lexicon: 1, id: blue.catbird.mls.removeMember


public struct BlueCatbirdMlsRemoveMember { 

    public static let typeIdentifier = "blue.catbird.mls.removeMember"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let targetDid: DID
            public let idempotencyKey: String
            public let reason: String?

            // Standard public initializer
            public init(convoId: String, targetDid: DID, idempotencyKey: String, reason: String? = nil) {
                self.convoId = convoId
                self.targetDid = targetDid
                self.idempotencyKey = idempotencyKey
                self.reason = reason
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.targetDid = try container.decode(DID.self, forKey: .targetDid)
                
                
                self.idempotencyKey = try container.decode(String.self, forKey: .idempotencyKey)
                
                
                self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(targetDid, forKey: .targetDid)
                
                
                try container.encode(idempotencyKey, forKey: .idempotencyKey)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(reason, forKey: .reason)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case targetDid
                case idempotencyKey
                case reason
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let targetDidValue = try targetDid.toCBORValue()
                map = map.adding(key: "targetDid", value: targetDidValue)
                
                
                
                let idempotencyKeyValue = try idempotencyKey.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
                
                
                
                if let value = reason {
                    // Encode optional property even if it's an empty array for CBOR
                    let reasonValue = try value.toCBORValue()
                    map = map.adding(key: "reason", value: reasonValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let ok: Bool
        
        public let epochHint: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            ok: Bool,
            
            epochHint: Int
            
            
        ) {
            
            
            self.ok = ok
            
            self.epochHint = epochHint
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ok = try container.decode(Bool.self, forKey: .ok)
            
            
            self.epochHint = try container.decode(Int.self, forKey: .epochHint)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ok, forKey: .ok)
            
            
            try container.encode(epochHint, forKey: .epochHint)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let okValue = try ok.toCBORValue()
            map = map.adding(key: "ok", value: okValue)
            
            
            
            let epochHintValue = try epochHint.toCBORValue()
            map = map.adding(key: "epochHint", value: epochHintValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case ok
            case epochHint
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// Caller is not an admin
                case notAdmin = "NotAdmin"
                /// Target is not a member
                case notMember = "NotMember"
                /// Use leaveConvo to remove yourself
                case cannotRemoveSelf = "CannotRemoveSelf"
                /// Conversation not found
                case convoNotFound = "ConvoNotFound"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - removeMember

    /// Remove (kick) a member from conversation (admin-only) Remove a member from the conversation. Admin-only operation. Server authorizes, soft-deletes membership (sets left_at), and logs action. The admin client must issue an MLS Remove commit via the standard MLS flow to cryptographically remove the member and advance the epoch.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func removeMember(
        
        input: BlueCatbirdMlsRemoveMember.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsRemoveMember.Output?) {
        let endpoint = "blue.catbird.mls.removeMember"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.removeMember")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsRemoveMember.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.removeMember: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsRemoveMember.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

