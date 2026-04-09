import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.transferSequencer


public struct BlueCatbirdMlsDSTransferSequencer { 

    public static let typeIdentifier = "blue.catbird.mlsDS.transferSequencer"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let currentEpoch: Int?
        public let newSequencerTerm: Int

        /// Standard public initializer
        public init(convoId: String, currentEpoch: Int? = nil, newSequencerTerm: Int) {
            self.convoId = convoId
            self.currentEpoch = currentEpoch
            self.newSequencerTerm = newSequencerTerm
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.currentEpoch = try container.decodeIfPresent(Int.self, forKey: .currentEpoch)
            self.newSequencerTerm = try container.decode(Int.self, forKey: .newSequencerTerm)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encodeIfPresent(currentEpoch, forKey: .currentEpoch)
            try container.encode(newSequencerTerm, forKey: .newSequencerTerm)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            if let value = currentEpoch {
                let currentEpochValue = try value.toCBORValue()
                map = map.adding(key: "currentEpoch", value: currentEpochValue)
            }
            let newSequencerTermValue = try newSequencerTerm.toCBORValue()
            map = map.adding(key: "newSequencerTerm", value: newSequencerTermValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case currentEpoch
            case newSequencerTerm
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let accepted: Bool
        
        public let newSequencerTerm: Int
        
        
        
        // Standard public initializer
        public init(
            
            
            accepted: Bool,
            
            newSequencerTerm: Int
            
            
        ) {
            
            
            self.accepted = accepted
            
            self.newSequencerTerm = newSequencerTerm
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.accepted = try container.decode(Bool.self, forKey: .accepted)
            
            
            self.newSequencerTerm = try container.decode(Int.self, forKey: .newSequencerTerm)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(accepted, forKey: .accepted)
            
            
            try container.encode(newSequencerTerm, forKey: .newSequencerTerm)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let acceptedValue = try accepted.toCBORValue()
            map = map.adding(key: "accepted", value: acceptedValue)
            
            
            
            let newSequencerTermValue = try newSequencerTerm.toCBORValue()
            map = map.adding(key: "newSequencerTerm", value: newSequencerTermValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case accepted
            case newSequencerTerm
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case conversationNotFound = "ConversationNotFound."
                case notCurrentSequencer = "NotCurrentSequencer."
                case termStale = "TermStale."
                case transferFailed = "TransferFailed."
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
    // MARK: - transferSequencer

    /// Accept a sequencer role transfer from the current sequencer DS. Transfer sequencer responsibility for a conversation to this DS.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func transferSequencer(
        
        input: BlueCatbirdMlsDSTransferSequencer.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSTransferSequencer.Output?) {
        let endpoint = "blue.catbird.mlsDS.transferSequencer"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.transferSequencer")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSTransferSequencer.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.transferSequencer: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

