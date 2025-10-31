import Foundation



// lexicon: 1, id: blue.catbird.mls.streamConvoEvents


public struct BlueCatbirdMlsStreamConvoEvents { 

    public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents"
        
public struct MessageEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#messageEvent"
            public let cursor: String
            public let message: BlueCatbirdMlsDefs.MessageView

        // Standard initializer
        public init(
            cursor: String, message: BlueCatbirdMlsDefs.MessageView
        ) {
            
            self.cursor = cursor
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.message = try container.decode(BlueCatbirdMlsDefs.MessageView.self, forKey: .message)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'message': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(message, forKey: .message)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(message)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.message != other.message {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case message
        }
    }
        
public struct ReactionEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#reactionEvent"
            public let cursor: String
            public let convoId: String
            public let messageId: String
            public let did: DID
            public let reaction: String
            public let action: String

        // Standard initializer
        public init(
            cursor: String, convoId: String, messageId: String, did: DID, reaction: String, action: String
        ) {
            
            self.cursor = cursor
            self.convoId = convoId
            self.messageId = messageId
            self.did = did
            self.reaction = reaction
            self.action = action
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.messageId = try container.decode(String.self, forKey: .messageId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'messageId': \(error)")
                
                throw error
            }
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.reaction = try container.decode(String.self, forKey: .reaction)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'reaction': \(error)")
                
                throw error
            }
            do {
                
                
                self.action = try container.decode(String.self, forKey: .action)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'action': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(messageId, forKey: .messageId)
            
            
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(reaction, forKey: .reaction)
            
            
            
            
            try container.encode(action, forKey: .action)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(messageId)
            hasher.combine(did)
            hasher.combine(reaction)
            hasher.combine(action)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.messageId != other.messageId {
                return false
            }
            
            
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.reaction != other.reaction {
                return false
            }
            
            
            
            
            if self.action != other.action {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let messageIdValue = try messageId.toCBORValue()
            map = map.adding(key: "messageId", value: messageIdValue)
            
            
            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let reactionValue = try reaction.toCBORValue()
            map = map.adding(key: "reaction", value: reactionValue)
            
            
            
            
            
            
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case messageId
            case did
            case reaction
            case action
        }
    }
        
public struct TypingEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#typingEvent"
            public let cursor: String
            public let convoId: String
            public let did: DID
            public let isTyping: Bool

        // Standard initializer
        public init(
            cursor: String, convoId: String, did: DID, isTyping: Bool
        ) {
            
            self.cursor = cursor
            self.convoId = convoId
            self.did = did
            self.isTyping = isTyping
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.convoId = try container.decode(String.self, forKey: .convoId)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                
                throw error
            }
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            do {
                
                
                self.isTyping = try container.decode(Bool.self, forKey: .isTyping)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'isTyping': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(convoId, forKey: .convoId)
            
            
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(isTyping, forKey: .isTyping)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(convoId)
            hasher.combine(did)
            hasher.combine(isTyping)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.convoId != other.convoId {
                return false
            }
            
            
            
            
            if self.did != other.did {
                return false
            }
            
            
            
            
            if self.isTyping != other.isTyping {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            
            
            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let isTypingValue = try isTyping.toCBORValue()
            map = map.adding(key: "isTyping", value: isTypingValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case convoId
            case did
            case isTyping
        }
    }
        
public struct InfoEvent: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.streamConvoEvents#infoEvent"
            public let cursor: String
            public let info: String

        // Standard initializer
        public init(
            cursor: String, info: String
        ) {
            
            self.cursor = cursor
            self.info = info
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.cursor = try container.decode(String.self, forKey: .cursor)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'cursor': \(error)")
                
                throw error
            }
            do {
                
                
                self.info = try container.decode(String.self, forKey: .info)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'info': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(cursor, forKey: .cursor)
            
            
            
            
            try container.encode(info, forKey: .info)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(cursor)
            hasher.combine(info)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.cursor != other.cursor {
                return false
            }
            
            
            
            
            if self.info != other.info {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let cursorValue = try cursor.toCBORValue()
            map = map.adding(key: "cursor", value: cursorValue)
            
            
            
            
            
            
            let infoValue = try info.toCBORValue()
            map = map.adding(key: "info", value: infoValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case cursor
            case info
        }
    }    
public struct Parameters: Parametrizable {
        public let cursor: String?
        public let convoId: String?
        
        public init(
            cursor: String? = nil, 
            convoId: String? = nil
            ) {
            self.cursor = cursor
            self.convoId = convoId
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let data: Data
        
        
        
        // Standard public initializer
        public init(
            
            
            data: Data
            
            
        ) {
            
            
            self.data = data
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.data = try container.decode(Data.self, forKey: .data)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let dataValue = try data.toCBORValue()
            map = map.adding(key: "data", value: dataValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case data
        }
        
    }




}


extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - streamConvoEvents

    /// Server-Sent Events stream for conversation updates (messages, reactions, typing indicators) Subscribe to live events (new messages, reactions, etc.) via Server-Sent Events in conversations involving the authenticated user
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func streamConvoEvents(input: BlueCatbirdMlsStreamConvoEvents.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsStreamConvoEvents.Output?) {
        let endpoint = "blue.catbird.mls.streamConvoEvents"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "text/event-stream"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.streamConvoEvents")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw NetworkError.invalidContentType(expected: "text/event-stream", actual: "nil")
        }

        if !contentType.lowercased().contains("text/event-stream") {
            throw NetworkError.invalidContentType(expected: "text/event-stream", actual: contentType)
        }

        // Only decode response data if request was successful
        if (200...299).contains(responseCode) {
            do {
                
                let decodedData = BlueCatbirdMlsStreamConvoEvents.Output(data: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.streamConvoEvents: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
    }
}                           

