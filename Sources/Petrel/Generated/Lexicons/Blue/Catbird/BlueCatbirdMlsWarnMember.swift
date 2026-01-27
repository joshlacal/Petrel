import Foundation



// lexicon: 1, id: blue.catbird.mls.warnMember


public struct BlueCatbirdMlsWarnMember { 

    public static let typeIdentifier = "blue.catbird.mls.warnMember"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let memberDid: DID
            public let reason: String
            public let expiresAt: ATProtocolDate?

            // Standard public initializer
            public init(convoId: String, memberDid: DID, reason: String, expiresAt: ATProtocolDate? = nil) {
                self.convoId = convoId
                self.memberDid = memberDid
                self.reason = reason
                self.expiresAt = expiresAt
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.memberDid = try container.decode(DID.self, forKey: .memberDid)
                
                
                self.reason = try container.decode(String.self, forKey: .reason)
                
                
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(memberDid, forKey: .memberDid)
                
                
                try container.encode(reason, forKey: .reason)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case memberDid
                case reason
                case expiresAt
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let memberDidValue = try memberDid.toCBORValue()
                map = map.adding(key: "memberDid", value: memberDidValue)
                
                
                
                let reasonValue = try reason.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
                
                
                
                if let value = expiresAt {
                    // Encode optional property even if it's an empty array for CBOR
                    let expiresAtValue = try value.toCBORValue()
                    map = map.adding(key: "expiresAt", value: expiresAtValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let warningId: String
        
        public let deliveredAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            warningId: String,
            
            deliveredAt: ATProtocolDate
            
            
        ) {
            
            
            self.warningId = warningId
            
            self.deliveredAt = deliveredAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.warningId = try container.decode(String.self, forKey: .warningId)
            
            
            self.deliveredAt = try container.decode(ATProtocolDate.self, forKey: .deliveredAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(warningId, forKey: .warningId)
            
            
            try container.encode(deliveredAt, forKey: .deliveredAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let warningIdValue = try warningId.toCBORValue()
            map = map.adding(key: "warningId", value: warningIdValue)
            
            
            
            let deliveredAtValue = try deliveredAt.toCBORValue()
            map = map.adding(key: "deliveredAt", value: deliveredAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case warningId
            case deliveredAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notAdmin = "NotAdmin.Only admins can warn members"
                case targetNotMember = "TargetNotMember.Target user is not a member"
                case cannotWarnAdmin = "CannotWarnAdmin.Cannot warn other admins"
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

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - warnMember

    /// Send warning to group member (admin action) Send a warning to a conversation member. Admin-only action. Warning is delivered as a system message and tracked server-side.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func warnMember(
        
        input: BlueCatbirdMlsWarnMember.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsWarnMember.Output?) {
        let endpoint = "blue.catbird.mls.warnMember"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.warnMember")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsWarnMember.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.warnMember: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

