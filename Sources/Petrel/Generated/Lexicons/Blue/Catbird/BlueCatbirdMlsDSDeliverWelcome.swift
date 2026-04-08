import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.deliverWelcome


public struct BlueCatbirdMlsDSDeliverWelcome { 

    public static let typeIdentifier = "blue.catbird.mlsDS.deliverWelcome"
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let recipientDid: String
        public let senderDsDid: String
        public let keyPackageHash: String
        public let welcomeData: Bytes
        public let initialEpoch: Int

        /// Standard public initializer
        public init(convoId: String, recipientDid: String, senderDsDid: String, keyPackageHash: String, welcomeData: Bytes, initialEpoch: Int) {
            self.convoId = convoId
            self.recipientDid = recipientDid
            self.senderDsDid = senderDsDid
            self.keyPackageHash = keyPackageHash
            self.welcomeData = welcomeData
            self.initialEpoch = initialEpoch
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.recipientDid = try container.decode(String.self, forKey: .recipientDid)
            self.senderDsDid = try container.decode(String.self, forKey: .senderDsDid)
            self.keyPackageHash = try container.decode(String.self, forKey: .keyPackageHash)
            self.welcomeData = try container.decode(Bytes.self, forKey: .welcomeData)
            self.initialEpoch = try container.decode(Int.self, forKey: .initialEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(recipientDid, forKey: .recipientDid)
            try container.encode(senderDsDid, forKey: .senderDsDid)
            try container.encode(keyPackageHash, forKey: .keyPackageHash)
            try container.encode(welcomeData, forKey: .welcomeData)
            try container.encode(initialEpoch, forKey: .initialEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let recipientDidValue = try recipientDid.toCBORValue()
            map = map.adding(key: "recipientDid", value: recipientDidValue)
            let senderDsDidValue = try senderDsDid.toCBORValue()
            map = map.adding(key: "senderDsDid", value: senderDsDidValue)
            let keyPackageHashValue = try keyPackageHash.toCBORValue()
            map = map.adding(key: "keyPackageHash", value: keyPackageHashValue)
            let welcomeDataValue = try welcomeData.toCBORValue()
            map = map.adding(key: "welcomeData", value: welcomeDataValue)
            let initialEpochValue = try initialEpoch.toCBORValue()
            map = map.adding(key: "initialEpoch", value: initialEpochValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case recipientDid
            case senderDsDid
            case keyPackageHash
            case welcomeData
            case initialEpoch
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let accepted: Bool
        
        public let ack: BlueCatbirdMlsDSDeliverMessage.DeliveryAck?
        
        
        
        // Standard public initializer
        public init(
            
            
            accepted: Bool,
            
            ack: BlueCatbirdMlsDSDeliverMessage.DeliveryAck? = nil
            
            
        ) {
            
            
            self.accepted = accepted
            
            self.ack = ack
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.accepted = try container.decode(Bool.self, forKey: .accepted)
            
            
            self.ack = try container.decodeIfPresent(BlueCatbirdMlsDSDeliverMessage.DeliveryAck.self, forKey: .ack)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(accepted, forKey: .accepted)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(ack, forKey: .ack)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let acceptedValue = try accepted.toCBORValue()
            map = map.adding(key: "accepted", value: acceptedValue)
            
            
            
            if let value = ack {
                // Encode optional property even if it's an empty array for CBOR
                let ackValue = try value.toCBORValue()
                map = map.adding(key: "ack", value: ackValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case accepted
            case ack
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case recipientNotFound = "RecipientNotFound."
                case notSequencer = "NotSequencer."
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
    // MARK: - deliverWelcome

    /// Accept a Welcome message for a new member from a remote DS. Deliver a federated MLS Welcome message to add a user to a group on the local DS.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deliverWelcome(
        
        input: BlueCatbirdMlsDSDeliverWelcome.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSDeliverWelcome.Output?) {
        let endpoint = "blue.catbird.mlsDS.deliverWelcome"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.deliverWelcome")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSDeliverWelcome.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.deliverWelcome: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

