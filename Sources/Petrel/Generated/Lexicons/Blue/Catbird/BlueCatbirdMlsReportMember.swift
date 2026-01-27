import Foundation



// lexicon: 1, id: blue.catbird.mls.reportMember


public struct BlueCatbirdMlsReportMember { 

    public static let typeIdentifier = "blue.catbird.mls.reportMember"
public struct Input: ATProtocolCodable {
            public let convoId: String
            public let reportedDid: DID
            public let category: String
            public let encryptedContent: Bytes
            public let messageIds: [String]?

            // Standard public initializer
            public init(convoId: String, reportedDid: DID, category: String, encryptedContent: Bytes, messageIds: [String]? = nil) {
                self.convoId = convoId
                self.reportedDid = reportedDid
                self.category = category
                self.encryptedContent = encryptedContent
                self.messageIds = messageIds
                
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
                self.reportedDid = try container.decode(DID.self, forKey: .reportedDid)
                
                
                self.category = try container.decode(String.self, forKey: .category)
                
                
                self.encryptedContent = try container.decode(Bytes.self, forKey: .encryptedContent)
                
                
                self.messageIds = try container.decodeIfPresent([String].self, forKey: .messageIds)
                
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(convoId, forKey: .convoId)
                
                
                try container.encode(reportedDid, forKey: .reportedDid)
                
                
                try container.encode(category, forKey: .category)
                
                
                try container.encode(encryptedContent, forKey: .encryptedContent)
                
                
                // Encode optional property even if it's an empty array
                try container.encodeIfPresent(messageIds, forKey: .messageIds)
                
            }
            
            private enum CodingKeys: String, CodingKey {
                case convoId
                case reportedDid
                case category
                case encryptedContent
                case messageIds
            }
            
            public func toCBORValue() throws -> Any {
                var map = OrderedCBORMap()

                
                
                let convoIdValue = try convoId.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
                
                
                
                let reportedDidValue = try reportedDid.toCBORValue()
                map = map.adding(key: "reportedDid", value: reportedDidValue)
                
                
                
                let categoryValue = try category.toCBORValue()
                map = map.adding(key: "category", value: categoryValue)
                
                
                
                let encryptedContentValue = try encryptedContent.toCBORValue()
                map = map.adding(key: "encryptedContent", value: encryptedContentValue)
                
                
                
                if let value = messageIds {
                    // Encode optional property even if it's an empty array for CBOR
                    let messageIdsValue = try value.toCBORValue()
                    map = map.adding(key: "messageIds", value: messageIdsValue)
                }
                
                

                return map
            }
        }
    
public struct Output: ATProtocolCodable {
        
        
        public let reportId: String
        
        public let submittedAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            reportId: String,
            
            submittedAt: ATProtocolDate
            
            
        ) {
            
            
            self.reportId = reportId
            
            self.submittedAt = submittedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.reportId = try container.decode(String.self, forKey: .reportId)
            
            
            self.submittedAt = try container.decode(ATProtocolDate.self, forKey: .submittedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(reportId, forKey: .reportId)
            
            
            try container.encode(submittedAt, forKey: .submittedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let reportIdValue = try reportId.toCBORValue()
            map = map.adding(key: "reportId", value: reportIdValue)
            
            
            
            let submittedAtValue = try submittedAt.toCBORValue()
            map = map.adding(key: "submittedAt", value: submittedAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case reportId
            case submittedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case notMember = "NotMember.Caller is not a member"
                case targetNotMember = "TargetNotMember.Reported user is not a member"
                case cannotReportSelf = "CannotReportSelf.Cannot report yourself"
                case convoNotFound = "ConvoNotFound.Conversation not found"
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
    // MARK: - reportMember

    /// Report a member for moderation (end-to-end encrypted) Submit an encrypted report about a conversation member to admins. Report content is E2EE and only admins can decrypt. Server stores metadata and routes to admins. Any member can report; cannot report self.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func reportMember(
        
        input: BlueCatbirdMlsReportMember.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsReportMember.Output?) {
        let endpoint = "blue.catbird.mls.reportMember"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.reportMember")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsReportMember.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.reportMember: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

