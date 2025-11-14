import Foundation



// lexicon: 1, id: blue.catbird.mls.demoteAdmin


public struct BlueCatbirdMlsDemoteAdmin { 

    public static let typeIdentifier = "blue.catbird.mls.demoteAdmin"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let targetDid: DID

            // Standard public initializer
            public init(convoId: String, targetDid: DID) {
                self.convoId = convoId
                self.targetDid = targetDid
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.targetDid = try container.decode(DID.self, forKey: .targetDid)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(targetDid, forKey: .targetDid)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case targetDid
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let targetDidValue = try targetDid.toCBORValue()
                map = map.adding(key: "targetDid", value: targetDidValue)
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let ok: Bool
        
        
        
        // Standard public initializer
        public init(
            
            
            ok: Bool
            
            
        ) {
            
            
            self.ok = ok
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.ok = try container.decode(Bool.self, forKey: .ok)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(ok, forKey: .ok)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let okValue = try ok.toCBORValue()
            map = map.adding(key: "ok", value: okValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case ok
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// Caller is not an admin (unless self-demotion)
                case notAdmin = "NotAdmin"
                /// Target is not a member
                case notMember = "NotMember"
                /// Target is not currently an admin
                case notAdminTarget = "NotAdminTarget"
                /// Cannot demote the last admin in the conversation
                case lastAdmin = "LastAdmin"
                /// Conversation not found
                case convoNotFound = "ConvoNotFound"
            public var description: String {
                return self.rawValue
            }
        }



}

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - demoteAdmin

    /// Demote an admin to regular member (admin-only, or self-demotion) Demote an admin to regular member. Caller must be an admin (unless demoting self). Cannot demote the last admin. Server enforces authorization, updates DB, and logs action.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func demoteAdmin(
        
        input: BlueCatbirdMlsDemoteAdmin.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDemoteAdmin.Output?) {
        let endpoint = "blue.catbird.mls.demoteAdmin"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.demoteAdmin")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDemoteAdmin.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.demoteAdmin: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsDemoteAdmin.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
        
    }
    
}
                           

