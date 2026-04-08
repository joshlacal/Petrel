import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.reportSpam


public struct BlueCatbirdMlsChatReportSpam { 

    public static let typeIdentifier = "blue.catbird.mlsChat.reportSpam"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let reportedDid: DID
        public let reason: String?

        /// Standard public initializer
        public init(convoId: String, reportedDid: DID, reason: String? = nil) {
            self.convoId = convoId
            self.reportedDid = reportedDid
            self.reason = reason
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.reportedDid = try container.decode(DID.self, forKey: .reportedDid)
            self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(reportedDid, forKey: .reportedDid)
            try container.encodeIfPresent(reason, forKey: .reason)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let reportedDidValue = try reportedDid.toCBORValue()
            map = map.adding(key: "reportedDid", value: reportedDidValue)
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case reportedDid
            case reason
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let id: String
        
        public let createdAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            id: String,
            
            createdAt: ATProtocolDate
            
            
        ) {
            
            
            self.id = id
            
            self.createdAt = createdAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(String.self, forKey: .id)
            
            
            self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case id
            case createdAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.Authentication required"
                case notFound = "NotFound.Conversation or member not found"
                case duplicateReport = "DuplicateReport.A report for this member in this conversation already exists"
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
    // MARK: - reportSpam

    /// Report a conversation member for spam
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func reportSpam(
        
        input: BlueCatbirdMlsChatReportSpam.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatReportSpam.Output?) {
        let endpoint = "blue.catbird.mlsChat.reportSpam"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.reportSpam")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatReportSpam.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.reportSpam: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

