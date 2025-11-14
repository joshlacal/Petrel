import Foundation



// lexicon: 1, id: blue.catbird.mls.getBlockStatus


public struct BlueCatbirdMlsGetBlockStatus { 

    public static let typeIdentifier = "blue.catbird.mls.getBlockStatus"    
public struct Parameters: Parametrizable {
        public let convoId: String
        
        public init(
            convoId: String
            ) {
            self.convoId = convoId
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convoId: String
        
        public let hasConflicts: Bool
        
        public let blocks: [BlueCatbirdMlsCheckBlocks.BlockRelationship]
        
        public let checkedAt: ATProtocolDate
        
        public let memberCount: Int?
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            hasConflicts: Bool,
            
            blocks: [BlueCatbirdMlsCheckBlocks.BlockRelationship],
            
            checkedAt: ATProtocolDate,
            
            memberCount: Int? = nil
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.hasConflicts = hasConflicts
            
            self.blocks = blocks
            
            self.checkedAt = checkedAt
            
            self.memberCount = memberCount
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.hasConflicts = try container.decode(Bool.self, forKey: .hasConflicts)
            
            
            self.blocks = try container.decode([BlueCatbirdMlsCheckBlocks.BlockRelationship].self, forKey: .blocks)
            
            
            self.checkedAt = try container.decode(ATProtocolDate.self, forKey: .checkedAt)
            
            
            self.memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(hasConflicts, forKey: .hasConflicts)
            
            
            try container.encode(blocks, forKey: .blocks)
            
            
            try container.encode(checkedAt, forKey: .checkedAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(memberCount, forKey: .memberCount)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let hasConflictsValue = try hasConflicts.toCBORValue()
            map = map.adding(key: "hasConflicts", value: hasConflictsValue)
            
            
            
            let blocksValue = try blocks.toCBORValue()
            map = map.adding(key: "blocks", value: blocksValue)
            
            
            
            let checkedAtValue = try checkedAt.toCBORValue()
            map = map.adding(key: "checkedAt", value: checkedAtValue)
            
            
            
            if let value = memberCount {
                // Encode optional property even if it's an empty array for CBOR
                let memberCountValue = try value.toCBORValue()
                map = map.adding(key: "memberCount", value: memberCountValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case hasConflicts
            case blocks
            case checkedAt
            case memberCount
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                /// Conversation not found
                case convoNotFound = "ConvoNotFound"
                /// Caller is not a member of this conversation
                case notMember = "NotMember"
                /// Only admins can check block status
                case notAdmin = "NotAdmin"
            public var description: String {
                return self.rawValue
            }
        }



}



extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - getBlockStatus

    /// Get block relationships relevant to a specific conversation Query block status for all members of a conversation. Returns any block relationships between current members. Useful for admins to identify and resolve block conflicts.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getBlockStatus(input: BlueCatbirdMlsGetBlockStatus.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsGetBlockStatus.Output?) {
        let endpoint = "blue.catbird.mls.getBlockStatus"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.getBlockStatus")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsGetBlockStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.getBlockStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Try to parse structured error response
            if let atprotoError = ATProtoErrorParser.parse(
                data: responseData,
                statusCode: responseCode,
                errorType: BlueCatbirdMlsGetBlockStatus.Error.self
            ) {
                throw atprotoError
            }
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

