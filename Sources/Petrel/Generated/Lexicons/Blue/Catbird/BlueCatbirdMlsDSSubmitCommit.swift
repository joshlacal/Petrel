import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.submitCommit


public struct BlueCatbirdMlsDSSubmitCommit { 

    public static let typeIdentifier = "blue.catbird.mlsDS.submitCommit"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let senderDsDid: String
        public let epoch: Int
        public let proposedEpoch: Int
        public let commitData: Bytes
        public let sequencerTerm: Int

        /// Standard public initializer
        public init(convoId: String, senderDsDid: String, epoch: Int, proposedEpoch: Int, commitData: Bytes, sequencerTerm: Int) {
            self.convoId = convoId
            self.senderDsDid = senderDsDid
            self.epoch = epoch
            self.proposedEpoch = proposedEpoch
            self.commitData = commitData
            self.sequencerTerm = sequencerTerm
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.senderDsDid = try container.decode(String.self, forKey: .senderDsDid)
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            self.proposedEpoch = try container.decode(Int.self, forKey: .proposedEpoch)
            self.commitData = try container.decode(Bytes.self, forKey: .commitData)
            self.sequencerTerm = try container.decode(Int.self, forKey: .sequencerTerm)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(senderDsDid, forKey: .senderDsDid)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(proposedEpoch, forKey: .proposedEpoch)
            try container.encode(commitData, forKey: .commitData)
            try container.encode(sequencerTerm, forKey: .sequencerTerm)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let senderDsDidValue = try senderDsDid.toCBORValue()
            map = map.adding(key: "senderDsDid", value: senderDsDidValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let proposedEpochValue = try proposedEpoch.toCBORValue()
            map = map.adding(key: "proposedEpoch", value: proposedEpochValue)
            let commitDataValue = try commitData.toCBORValue()
            map = map.adding(key: "commitData", value: commitDataValue)
            let sequencerTermValue = try sequencerTerm.toCBORValue()
            map = map.adding(key: "sequencerTerm", value: sequencerTermValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case senderDsDid
            case epoch
            case proposedEpoch
            case commitData
            case sequencerTerm
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let accepted: Bool
        
        public let assignedEpoch: Int
        
        public let sequencerTerm: Int
        
        public let receipt: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            accepted: Bool,
            
            assignedEpoch: Int,
            
            sequencerTerm: Int,
            
            receipt: String? = nil
            
            
        ) {
            
            
            self.accepted = accepted
            
            self.assignedEpoch = assignedEpoch
            
            self.sequencerTerm = sequencerTerm
            
            self.receipt = receipt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.accepted = try container.decode(Bool.self, forKey: .accepted)
            
            
            self.assignedEpoch = try container.decode(Int.self, forKey: .assignedEpoch)
            
            
            self.sequencerTerm = try container.decode(Int.self, forKey: .sequencerTerm)
            
            
            self.receipt = try container.decodeIfPresent(String.self, forKey: .receipt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(accepted, forKey: .accepted)
            
            
            try container.encode(assignedEpoch, forKey: .assignedEpoch)
            
            
            try container.encode(sequencerTerm, forKey: .sequencerTerm)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(receipt, forKey: .receipt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let acceptedValue = try accepted.toCBORValue()
            map = map.adding(key: "accepted", value: acceptedValue)
            
            
            
            let assignedEpochValue = try assignedEpoch.toCBORValue()
            map = map.adding(key: "assignedEpoch", value: assignedEpochValue)
            
            
            
            let sequencerTermValue = try sequencerTerm.toCBORValue()
            map = map.adding(key: "sequencerTerm", value: sequencerTermValue)
            
            
            
            if let value = receipt {
                // Encode optional property even if it's an empty array for CBOR
                let receiptValue = try value.toCBORValue()
                map = map.adding(key: "receipt", value: receiptValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case accepted
            case assignedEpoch
            case sequencerTerm
            case receipt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case conversationNotFound = "ConversationNotFound."
                case notSequencer = "NotSequencer."
                case termStale = "TermStale."
                case commitConflict = "CommitConflict."
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
    // MARK: - submitCommit

    /// Submit a commit for CAS sequencing on the sequencer DS. Submit an MLS commit for epoch ordering via compare-and-swap. The sequencer assigns the epoch and returns a receipt.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func submitCommit(
        
        input: BlueCatbirdMlsDSSubmitCommit.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSSubmitCommit.Output?) {
        let endpoint = "blue.catbird.mlsDS.submitCommit"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.submitCommit")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSSubmitCommit.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.submitCommit: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

