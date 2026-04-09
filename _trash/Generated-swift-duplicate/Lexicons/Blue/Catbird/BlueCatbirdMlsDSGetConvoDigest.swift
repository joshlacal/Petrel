import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.getConvoDigest


public struct BlueCatbirdMlsDSGetConvoDigest { 

    public static let typeIdentifier = "blue.catbird.mlsDS.getConvoDigest"    
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
        
        public let sequencerDsDid: String
        
        public let sequencerTerm: Int
        
        public let epoch: Int
        
        public let lastSeq: Int
        
        public let eventCount: Int
        
        public let digestSha256: String
        
        public let generatedAt: ATProtocolDate
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            sequencerDsDid: String,
            
            sequencerTerm: Int,
            
            epoch: Int,
            
            lastSeq: Int,
            
            eventCount: Int,
            
            digestSha256: String,
            
            generatedAt: ATProtocolDate
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.sequencerDsDid = sequencerDsDid
            
            self.sequencerTerm = sequencerTerm
            
            self.epoch = epoch
            
            self.lastSeq = lastSeq
            
            self.eventCount = eventCount
            
            self.digestSha256 = digestSha256
            
            self.generatedAt = generatedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.sequencerDsDid = try container.decode(String.self, forKey: .sequencerDsDid)
            
            
            self.sequencerTerm = try container.decode(Int.self, forKey: .sequencerTerm)
            
            
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            
            
            self.lastSeq = try container.decode(Int.self, forKey: .lastSeq)
            
            
            self.eventCount = try container.decode(Int.self, forKey: .eventCount)
            
            
            self.digestSha256 = try container.decode(String.self, forKey: .digestSha256)
            
            
            self.generatedAt = try container.decode(ATProtocolDate.self, forKey: .generatedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(sequencerDsDid, forKey: .sequencerDsDid)
            
            
            try container.encode(sequencerTerm, forKey: .sequencerTerm)
            
            
            try container.encode(epoch, forKey: .epoch)
            
            
            try container.encode(lastSeq, forKey: .lastSeq)
            
            
            try container.encode(eventCount, forKey: .eventCount)
            
            
            try container.encode(digestSha256, forKey: .digestSha256)
            
            
            try container.encode(generatedAt, forKey: .generatedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let sequencerDsDidValue = try sequencerDsDid.toCBORValue()
            map = map.adding(key: "sequencerDsDid", value: sequencerDsDidValue)
            
            
            
            let sequencerTermValue = try sequencerTerm.toCBORValue()
            map = map.adding(key: "sequencerTerm", value: sequencerTermValue)
            
            
            
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            
            
            
            let lastSeqValue = try lastSeq.toCBORValue()
            map = map.adding(key: "lastSeq", value: lastSeqValue)
            
            
            
            let eventCountValue = try eventCount.toCBORValue()
            map = map.adding(key: "eventCount", value: eventCountValue)
            
            
            
            let digestSha256Value = try digestSha256.toCBORValue()
            map = map.adding(key: "digestSha256", value: digestSha256Value)
            
            
            
            let generatedAtValue = try generatedAt.toCBORValue()
            map = map.adding(key: "generatedAt", value: generatedAtValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case sequencerDsDid
            case sequencerTerm
            case epoch
            case lastSeq
            case eventCount
            case digestSha256
            case generatedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case conversationNotFound = "ConversationNotFound."
                case notAuthorized = "NotAuthorized."
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



extension ATProtoClient.Blue.Catbird.MlsDS {
    // MARK: - getConvoDigest

    /// Get a cryptographic digest of all messages in a conversation for reconciliation. Compute and return a SHA-256 digest over all messages in a conversation, along with sequencer state.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getConvoDigest(input: BlueCatbirdMlsDSGetConvoDigest.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSGetConvoDigest.Output?) {
        let endpoint = "blue.catbird.mlsDS.getConvoDigest"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.getConvoDigest")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSGetConvoDigest.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.getConvoDigest: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

