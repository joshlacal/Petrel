import Foundation



// lexicon: 1, id: blue.catbird.mlsDS.getConvoEvents


public struct BlueCatbirdMlsDSGetConvoEvents { 

    public static let typeIdentifier = "blue.catbird.mlsDS.getConvoEvents"
        
public struct ConvoEventEntry: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsDS.getConvoEvents#convoEventEntry"
            public let seq: Int
            public let epoch: Int
            public let msgId: String
            public let messageType: String
            public let ciphertext: Bytes
            public let paddedSize: Int
            public let createdAt: ATProtocolDate

        public init(
            seq: Int, epoch: Int, msgId: String, messageType: String, ciphertext: Bytes, paddedSize: Int, createdAt: ATProtocolDate
        ) {
            self.seq = seq
            self.epoch = epoch
            self.msgId = msgId
            self.messageType = messageType
            self.ciphertext = ciphertext
            self.paddedSize = paddedSize
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.seq = try container.decode(Int.self, forKey: .seq)
            } catch {
                LogManager.logError("Decoding error for required property 'seq': \(error)")
                throw error
            }
            do {
                self.epoch = try container.decode(Int.self, forKey: .epoch)
            } catch {
                LogManager.logError("Decoding error for required property 'epoch': \(error)")
                throw error
            }
            do {
                self.msgId = try container.decode(String.self, forKey: .msgId)
            } catch {
                LogManager.logError("Decoding error for required property 'msgId': \(error)")
                throw error
            }
            do {
                self.messageType = try container.decode(String.self, forKey: .messageType)
            } catch {
                LogManager.logError("Decoding error for required property 'messageType': \(error)")
                throw error
            }
            do {
                self.ciphertext = try container.decode(Bytes.self, forKey: .ciphertext)
            } catch {
                LogManager.logError("Decoding error for required property 'ciphertext': \(error)")
                throw error
            }
            do {
                self.paddedSize = try container.decode(Int.self, forKey: .paddedSize)
            } catch {
                LogManager.logError("Decoding error for required property 'paddedSize': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(seq, forKey: .seq)
            try container.encode(epoch, forKey: .epoch)
            try container.encode(msgId, forKey: .msgId)
            try container.encode(messageType, forKey: .messageType)
            try container.encode(ciphertext, forKey: .ciphertext)
            try container.encode(paddedSize, forKey: .paddedSize)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(seq)
            hasher.combine(epoch)
            hasher.combine(msgId)
            hasher.combine(messageType)
            hasher.combine(ciphertext)
            hasher.combine(paddedSize)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if seq != other.seq {
                return false
            }
            if epoch != other.epoch {
                return false
            }
            if msgId != other.msgId {
                return false
            }
            if messageType != other.messageType {
                return false
            }
            if ciphertext != other.ciphertext {
                return false
            }
            if paddedSize != other.paddedSize {
                return false
            }
            if createdAt != other.createdAt {
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
            let seqValue = try seq.toCBORValue()
            map = map.adding(key: "seq", value: seqValue)
            let epochValue = try epoch.toCBORValue()
            map = map.adding(key: "epoch", value: epochValue)
            let msgIdValue = try msgId.toCBORValue()
            map = map.adding(key: "msgId", value: msgIdValue)
            let messageTypeValue = try messageType.toCBORValue()
            map = map.adding(key: "messageType", value: messageTypeValue)
            let ciphertextValue = try ciphertext.toCBORValue()
            map = map.adding(key: "ciphertext", value: ciphertextValue)
            let paddedSizeValue = try paddedSize.toCBORValue()
            map = map.adding(key: "paddedSize", value: paddedSizeValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case seq
            case epoch
            case msgId
            case messageType
            case ciphertext
            case paddedSize
            case createdAt
        }
    }    
public struct Parameters: Parametrizable {
        public let convoId: String
        public let afterSeq: Int?
        public let limit: Int?
        
        public init(
            convoId: String, 
            afterSeq: Int? = nil, 
            limit: Int? = nil
            ) {
            self.convoId = convoId
            self.afterSeq = afterSeq
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convoId: String
        
        public let fromSeqExclusive: Int
        
        public let toSeqInclusive: Int
        
        public let events: [ConvoEventEntry]
        
        
        
        // Standard public initializer
        public init(
            
            
            convoId: String,
            
            fromSeqExclusive: Int,
            
            toSeqInclusive: Int,
            
            events: [ConvoEventEntry]
            
            
        ) {
            
            
            self.convoId = convoId
            
            self.fromSeqExclusive = fromSeqExclusive
            
            self.toSeqInclusive = toSeqInclusive
            
            self.events = events
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convoId = try container.decode(String.self, forKey: .convoId)
            
            
            self.fromSeqExclusive = try container.decode(Int.self, forKey: .fromSeqExclusive)
            
            
            self.toSeqInclusive = try container.decode(Int.self, forKey: .toSeqInclusive)
            
            
            self.events = try container.decode([ConvoEventEntry].self, forKey: .events)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convoId, forKey: .convoId)
            
            
            try container.encode(fromSeqExclusive, forKey: .fromSeqExclusive)
            
            
            try container.encode(toSeqInclusive, forKey: .toSeqInclusive)
            
            
            try container.encode(events, forKey: .events)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            let fromSeqExclusiveValue = try fromSeqExclusive.toCBORValue()
            map = map.adding(key: "fromSeqExclusive", value: fromSeqExclusiveValue)
            
            
            
            let toSeqInclusiveValue = try toSeqInclusive.toCBORValue()
            map = map.adding(key: "toSeqInclusive", value: toSeqInclusiveValue)
            
            
            
            let eventsValue = try events.toCBORValue()
            map = map.adding(key: "events", value: eventsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convoId
            case fromSeqExclusive
            case toSeqInclusive
            case events
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
    // MARK: - getConvoEvents

    /// Paginated retrieval of conversation events for federation reconciliation. Fetch a page of conversation events (messages) after a given sequence number.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getConvoEvents(input: BlueCatbirdMlsDSGetConvoEvents.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsDSGetConvoEvents.Output?) {
        let endpoint = "blue.catbird.mlsDS.getConvoEvents"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsDS.getConvoEvents")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsDSGetConvoEvents.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsDS.getConvoEvents: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

