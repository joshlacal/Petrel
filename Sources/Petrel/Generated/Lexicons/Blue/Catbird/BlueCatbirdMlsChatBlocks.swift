import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.blocks


public struct BlueCatbirdMlsChatBlocks { 

    public static let typeIdentifier = "blue.catbird.mlsChat.blocks"
        
public struct BlockRecord: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.blocks#blockRecord"
            public let blockerDid: DID
            public let blockedDid: DID
            public let action: String

        public init(
            blockerDid: DID, blockedDid: DID, action: String
        ) {
            self.blockerDid = blockerDid
            self.blockedDid = blockedDid
            self.action = action
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.blockerDid = try container.decode(DID.self, forKey: .blockerDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockerDid': \(error)")
                throw error
            }
            do {
                self.blockedDid = try container.decode(DID.self, forKey: .blockedDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockedDid': \(error)")
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
            try container.encode(blockerDid, forKey: .blockerDid)
            try container.encode(blockedDid, forKey: .blockedDid)
            try container.encode(action, forKey: .action)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(blockerDid)
            hasher.combine(blockedDid)
            hasher.combine(action)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if blockerDid != other.blockerDid {
                return false
            }
            if blockedDid != other.blockedDid {
                return false
            }
            if action != other.action {
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
            let blockerDidValue = try blockerDid.toCBORValue()
            map = map.adding(key: "blockerDid", value: blockerDidValue)
            let blockedDidValue = try blockedDid.toCBORValue()
            map = map.adding(key: "blockedDid", value: blockedDidValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case blockerDid
            case blockedDid
            case action
        }
    }
        
public struct BlockRelationship: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.blocks#blockRelationship"
            public let blockerDid: DID
            public let blockedDid: DID
            public let createdAt: ATProtocolDate
            public let blockUri: String?

        public init(
            blockerDid: DID, blockedDid: DID, createdAt: ATProtocolDate, blockUri: String?
        ) {
            self.blockerDid = blockerDid
            self.blockedDid = blockedDid
            self.createdAt = createdAt
            self.blockUri = blockUri
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.blockerDid = try container.decode(DID.self, forKey: .blockerDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockerDid': \(error)")
                throw error
            }
            do {
                self.blockedDid = try container.decode(DID.self, forKey: .blockedDid)
            } catch {
                LogManager.logError("Decoding error for required property 'blockedDid': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.blockUri = try container.decodeIfPresent(String.self, forKey: .blockUri)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'blockUri': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(blockerDid, forKey: .blockerDid)
            try container.encode(blockedDid, forKey: .blockedDid)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(blockUri, forKey: .blockUri)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(blockerDid)
            hasher.combine(blockedDid)
            hasher.combine(createdAt)
            if let value = blockUri {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if blockerDid != other.blockerDid {
                return false
            }
            if blockedDid != other.blockedDid {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if blockUri != other.blockUri {
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
            let blockerDidValue = try blockerDid.toCBORValue()
            map = map.adding(key: "blockerDid", value: blockerDidValue)
            let blockedDidValue = try blockedDid.toCBORValue()
            map = map.adding(key: "blockedDid", value: blockedDidValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = blockUri {
                let blockUriValue = try value.toCBORValue()
                map = map.adding(key: "blockUri", value: blockUriValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case blockerDid
            case blockedDid
            case createdAt
            case blockUri
        }
    }
        
public struct ConversationBlockStatus: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.blocks#conversationBlockStatus"
            public let convoId: String
            public let hasConflicts: Bool
            public let memberCount: Int
            public let checkedAt: ATProtocolDate?

        public init(
            convoId: String, hasConflicts: Bool, memberCount: Int, checkedAt: ATProtocolDate?
        ) {
            self.convoId = convoId
            self.hasConflicts = hasConflicts
            self.memberCount = memberCount
            self.checkedAt = checkedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.hasConflicts = try container.decode(Bool.self, forKey: .hasConflicts)
            } catch {
                LogManager.logError("Decoding error for required property 'hasConflicts': \(error)")
                throw error
            }
            do {
                self.memberCount = try container.decode(Int.self, forKey: .memberCount)
            } catch {
                LogManager.logError("Decoding error for required property 'memberCount': \(error)")
                throw error
            }
            do {
                self.checkedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .checkedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'checkedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(hasConflicts, forKey: .hasConflicts)
            try container.encode(memberCount, forKey: .memberCount)
            try container.encodeIfPresent(checkedAt, forKey: .checkedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(hasConflicts)
            hasher.combine(memberCount)
            if let value = checkedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if hasConflicts != other.hasConflicts {
                return false
            }
            if memberCount != other.memberCount {
                return false
            }
            if checkedAt != other.checkedAt {
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
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let hasConflictsValue = try hasConflicts.toCBORValue()
            map = map.adding(key: "hasConflicts", value: hasConflictsValue)
            let memberCountValue = try memberCount.toCBORValue()
            map = map.adding(key: "memberCount", value: memberCountValue)
            if let value = checkedAt {
                let checkedAtValue = try value.toCBORValue()
                map = map.adding(key: "checkedAt", value: checkedAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case hasConflicts
            case memberCount
            case checkedAt
        }
    }
        
public struct BlockChangeResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.blocks#blockChangeResult"
            public let convoId: String
            public let action: String
            public let removedDid: DID?

        public init(
            convoId: String, action: String, removedDid: DID?
        ) {
            self.convoId = convoId
            self.action = action
            self.removedDid = removedDid
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
            do {
                self.removedDid = try container.decodeIfPresent(DID.self, forKey: .removedDid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'removedDid': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(removedDid, forKey: .removedDid)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(action)
            if let value = removedDid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if convoId != other.convoId {
                return false
            }
            if action != other.action {
                return false
            }
            if removedDid != other.removedDid {
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
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = removedDid {
                let removedDidValue = try value.toCBORValue()
                map = map.adding(key: "removedDid", value: removedDidValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case action
            case removedDid
        }
    }
public struct Input: ATProtocolCodable {
        public let action: String
        public let convoId: String?
        public let dids: [String]?
        public let blockRecord: BlockRecord?

        /// Standard public initializer
        public init(action: String, convoId: String? = nil, dids: [String]? = nil, blockRecord: BlockRecord? = nil) {
            self.action = action
            self.convoId = convoId
            self.dids = dids
            self.blockRecord = blockRecord
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.action = try container.decode(String.self, forKey: .action)
            self.convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
            self.dids = try container.decodeIfPresent([String].self, forKey: .dids)
            self.blockRecord = try container.decodeIfPresent(BlockRecord.self, forKey: .blockRecord)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(convoId, forKey: .convoId)
            try container.encodeIfPresent(dids, forKey: .dids)
            try container.encodeIfPresent(blockRecord, forKey: .blockRecord)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = convoId {
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            if let value = dids {
                let didsValue = try value.toCBORValue()
                map = map.adding(key: "dids", value: didsValue)
            }
            if let value = blockRecord {
                let blockRecordValue = try value.toCBORValue()
                map = map.adding(key: "blockRecord", value: blockRecordValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case action
            case convoId
            case dids
            case blockRecord
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let hasConflicts: Bool?
        
        public let blocks: [BlockRelationship]?
        
        public let checkedAt: ATProtocolDate?
        
        public let status: ConversationBlockStatus?
        
        public let changes: [BlockChangeResult]?
        
        
        
        // Standard public initializer
        public init(
            
            
            hasConflicts: Bool? = nil,
            
            blocks: [BlockRelationship]? = nil,
            
            checkedAt: ATProtocolDate? = nil,
            
            status: ConversationBlockStatus? = nil,
            
            changes: [BlockChangeResult]? = nil
            
            
        ) {
            
            
            self.hasConflicts = hasConflicts
            
            self.blocks = blocks
            
            self.checkedAt = checkedAt
            
            self.status = status
            
            self.changes = changes
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.hasConflicts = try container.decodeIfPresent(Bool.self, forKey: .hasConflicts)
            
            
            self.blocks = try container.decodeIfPresent([BlockRelationship].self, forKey: .blocks)
            
            
            self.checkedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .checkedAt)
            
            
            self.status = try container.decodeIfPresent(ConversationBlockStatus.self, forKey: .status)
            
            
            self.changes = try container.decodeIfPresent([BlockChangeResult].self, forKey: .changes)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hasConflicts, forKey: .hasConflicts)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blocks, forKey: .blocks)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(checkedAt, forKey: .checkedAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(changes, forKey: .changes)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = hasConflicts {
                // Encode optional property even if it's an empty array for CBOR
                let hasConflictsValue = try value.toCBORValue()
                map = map.adding(key: "hasConflicts", value: hasConflictsValue)
            }
            
            
            
            if let value = blocks {
                // Encode optional property even if it's an empty array for CBOR
                let blocksValue = try value.toCBORValue()
                map = map.adding(key: "blocks", value: blocksValue)
            }
            
            
            
            if let value = checkedAt {
                // Encode optional property even if it's an empty array for CBOR
                let checkedAtValue = try value.toCBORValue()
                map = map.adding(key: "checkedAt", value: checkedAtValue)
            }
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            
            if let value = changes {
                // Encode optional property even if it's an empty array for CBOR
                let changesValue = try value.toCBORValue()
                map = map.adding(key: "changes", value: changesValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case hasConflicts
            case blocks
            case checkedAt
            case status
            case changes
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidRequest = "InvalidRequest.Invalid request parameters"
                case unauthorized = "Unauthorized.Authentication required"
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
    // MARK: - blocks

    /// Manage block relationships for MLS conversations. Supports checking block status, querying blocks between DIDs, and handling block changes.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func blocks(
        
        input: BlueCatbirdMlsChatBlocks.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatBlocks.Output?) {
        let endpoint = "blue.catbird.mlsChat.blocks"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.blocks")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatBlocks.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.blocks: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

