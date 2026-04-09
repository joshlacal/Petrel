import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.deliverMessage


public struct BlueCatbirdMlsDSDeliverMessage { 

    public static let typeIdentifier = "blue.catbird.mlsDS.deliverMessage"
        
public struct DeliveryAck: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsDS.deliverMessage#deliveryAck"
            public let sig: String
            public let msgId: String?
            public let convoId: String?
            public let epoch: Int?
            public let term: Int?

        public init(
            sig: String, msgId: String?, convoId: String?, epoch: Int?, term: Int?
        ) {
            self.sig = sig
            self.msgId = msgId
            self.convoId = convoId
            self.epoch = epoch
            self.term = term
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.sig = try container.decode(String.self, forKey: .sig)
            } catch {
                LogManager.logError("Decoding error for required property 'sig': \(error)")
                throw error
            }
            do {
                self.msgId = try container.decodeIfPresent(String.self, forKey: .msgId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'msgId': \(error)")
                throw error
            }
            do {
                self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'convoId': \(error)")
                throw error
            }
            do {
                self.epoch = try container.decodeIfPresent(Int.self, forKey: .epoch)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'epoch': \(error)")
                throw error
            }
            do {
                self.term = try container.decodeIfPresent(Int.self, forKey: .term)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'term': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(sig, forKey: .sig)
            try container.encodeIfPresent(msgId, forKey: .msgId)
            try container.encodeIfPresent(convoId, forKey: .convoId)
            try container.encodeIfPresent(epoch, forKey: .epoch)
            try container.encodeIfPresent(term, forKey: .term)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(sig)
            if let value = msgId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = convoId {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = epoch {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = term {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if sig != other.sig {
                return false
            }
            if msgId != other.msgId {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if term != other.term {
                return false
            }
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let sigValue = try sig.toCBORValue()
            map = map.adding(key: "sig", value: sigValue)
            if let value = msgId {
                let msgIdValue = try value.toCBORValue()
                map = map.adding(key: "msgId", value: msgIdValue)
            }
            if let value = convoId {
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            if let value = epoch {
                let epochValue = try value.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
            }
            if let value = term {
                let termValue = try value.toCBORValue()
                map = map.adding(key: "term", value: termValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case sig
            case msgId
            case convoId
            case epoch
            case term
        }
    }
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let msgId: String
        public let epoch: Int
        public let senderDsDid: String
        public let ciphertext: Bytes
        public let paddedSize: Int
        public let messageType: String?
        public let deliveryId: String
        public let sequencerTerm: Int

        /// Standard public initializer
        public init(convoId: String, msgId: String, epoch: Int, senderDsDid: String, ciphertext: Bytes, paddedSize: Int, messageType: String? = nil, deliveryId: String, sequencerTerm: Int) {
            self.convoId = convoId
            self.msgId = msgId
            self.epoch = epoch
            self.senderDsDid = senderDsDid
            self.ciphertext = ciphertext
            self.paddedSize = paddedSize
            self.messageType = messageType
            self.deliveryId = deliveryId
            self.sequencerTerm = sequencerTerm
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.msgId = try container.decode(String.self, forKey: .msgId)
            self.epoch = try container.decode(Int.self, forKey: .epoch)
            self.senderDsDid = try container.decode(String.self, forKey: .senderDsDid)
            self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
            self.paddedSize = try container.decode(Int.self, forKey: .paddedSize)
            self.messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
            self.deliveryId = try container.decode(String.self, forKey: .deliveryId)
            self.sequencerTerm = try container.decode(Int.self, forKey: .sequencerTerm)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(msgId, forKey: .msgId)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(senderDsDid, forKey: .senderDsDid)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(paddedSize, forKey: .paddedSize)
            try container.encodeIfPresent(messageType, forKey: .messageType)
            try container.encode(deliveryId, forKey: .deliveryId)
            try container.encode(sequencerTerm, forKey: .sequencerTerm)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let msgIdValue = try msgId.toCBORValue()
            map = map.adding(key: "msgId", value: msgIdValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let senderDsDidValue = try senderDsDid.toCBORValue()
            map = map.adding(key: "senderDsDid", value: senderDsDidValue)
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            let paddedSizeValue = try paddedSize.toCBORValue()
            map = map.adding(key: "paddedSize", value: paddedSizeValue)
            if let value = messageType {
                let messageTypeValue = try value.toCBORValue()
                map = map.adding(key: "messageType", value: messageTypeValue)
            }
            let deliveryIdValue = try deliveryId.toCBORValue()
            map = map.adding(key: "deliveryId", value: deliveryIdValue)
            let sequencerTermValue = try sequencerTerm.toCBORValue()
            map = map.adding(key: "sequencerTerm", value: sequencerTermValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case msgId
            case epoch
            case senderDsDid
            case ciphertext
            case paddedSize
            case messageType
            case deliveryId
            case sequencerTerm
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let accepted: Bool
        
        public let seq: Int
        
        public let deliveryId: String
        
        public let ack: DeliveryAck?
        
        
        
        // Standard public initializer
        public init(
            
            
            accepted: Bool,
            
            seq: Int,
            
            deliveryId: String,
            
            ack: DeliveryAck? = nil
            
            
        ) {
            
            
            self.accepted = accepted
            
            self.seq = seq
            
            self.deliveryId = deliveryId
            
            self.ack = ack
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.accepted = try container.decode(Bool.self, forKey: .accepted)
            
            
            self.seq = try container.decode(Int.self, forKey: .seq)
            
            
            self.deliveryId = try container.decode(String.self, forKey: .deliveryId)
            
            
            self.ack = try container.decodeIfPresent(DeliveryAck.self, forKey: .ack)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(accepted, forKey: .accepted)
            
            
            try container.encode(seq, forKey: .seq)
            
            
            try container.encode(deliveryId, forKey: .deliveryId)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(ack, forKey: .ack)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let acceptedValue = try accepted.toCBORValue()
            map = map.adding(key: "accepted", value: acceptedValue)
            
            
            
            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)
            
            
            
            let deliveryIdValue = try deliveryId.toCBORValue()
            map = map.adding(key: "deliveryId", value: deliveryIdValue)
            
            
            
            if let value = ack {
                // Encode optional property even if it's an empty array for CBOR
                let ackValue = try value.toCBORValue()
                map = map.adding(key: "ack", value: ackValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case accepted
            case seq
            case deliveryId
            case ack
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case conversationNotFound = "ConversationNotFound."
                case notSequencer = "NotSequencer."
                case termStale = "TermStale."
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
    // MARK: - deliverMessage

    /// Accept an inbound MLS message from a remote DS and store it for local subscribers. Deliver a federated MLS message to a local DS for storage and SSE fanout.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func deliverMessage(
        
        input: BlueCatbirdMlsDSDeliverMessage.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSDeliverMessage.Output?) {
        let endpoint = "blue.catbird.mlsDS.deliverMessage"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.deliverMessage")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSDeliverMessage.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.deliverMessage: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

