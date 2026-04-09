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
        
        
        public let newSequencerDid: DID
        
        public let convoId: String
        
        public let epoch: Int
        
        public let sequencerTerm: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            newSequencerDid: DID,
            
            convoId: String,
            
            epoch: Int,
            
            sequencerTerm: Int
            
            
        ) {
            
            
            self.newSequencerDid = newSequencerDid
            
            self.convoId = convoId
            
            self.epoch = epoch
            
            self.sequencerTerm = sequencerTerm
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.newSequencerDid = try container.decode(DID.self, forKey: .newSequencerDid)
            
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            
            
            self.sequencerTerm = try container.decode(Int.self, forKey: .sequencerTerm)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(newSequencerDid, forKey: .newSequencerDid)
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(epoch, forKey: .epoch)
            
            
            try container.encode(sequencerTerm, forKey: .sequencerTerm)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let newSequencerDidValue = try newSequencerDid.toCBORValue()
            map = map.adding(key: "newSequencerDid", value: newSequencerDidValue)
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            
            
            
            let sequencerTermValue = try sequencerTerm.toCBORValue()
            map = map.adding(key: "sequencerTerm", value: sequencerTermValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case newSequencerDid
            case convoId
            case epoch
            case sequencerTerm
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of the conversation"
                case sequencerHealthy = "SequencerHealthy.Current sequencer is still healthy, failover denied"
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

    /// Request sequencer failover when the current sequencer is unreachable Request sequencer failover for a conversation. Only members may call this. The handler health-checks the current sequencer before allowing the takeover. Returns CONFLICT if the current sequencer is still healthy.
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
        
        
        let queryItems: [URLQueryItem]? = nil
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: queryItems
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
                           

