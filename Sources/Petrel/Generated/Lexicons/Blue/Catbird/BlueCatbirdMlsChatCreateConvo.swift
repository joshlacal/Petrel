import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.createConvo


public struct BlueCatbirdMlsChatCreateConvo { 

    public static let typeIdentifier = "blue.catbird.mlsChat.createConvo"
        
public struct MetadataInput: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.createConvo#metadataInput"
            public let name: String?
            public let description: String?

        public init(
            name: String?, description: String?
        ) {
            self.name = name
            self.description = description
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'name': \(error)")
                throw error
            }
            do {
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = name {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if name != other.name {
                return false
            }
            if description != other.description {
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
            if let value = name {
                let nameValue = try value.toCBORValue()
                map = map.adding(key: "name", value: nameValue)
            }
            if let value = description {
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case name
            case description
        }
    }
        
public struct KeyPackageHashEntry: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.createConvo#keyPackageHashEntry"
            public let did: DID
            public let hash: String

        public init(
            did: DID, hash: String
        ) {
            self.did = did
            self.hash = hash
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                self.hash = try container.decode(String.self, forKey: .hash)
            } catch {
                LogManager.logError("Decoding error for required property 'hash': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(hash, forKey: .hash)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(hash)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if hash != other.hash {
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
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let hashValue = try hash.toCBORValue()
            map = map.adding(key: "hash", value: hashValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case hash
        }
    }
        
public struct InviteAction: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.createConvo#inviteAction"
            public let action: String
            public let code: String?

        public init(
            action: String, code: String?
        ) {
            self.action = action
            self.code = code
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
            do {
                self.code = try container.decodeIfPresent(String.self, forKey: .code)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'code': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(code, forKey: .code)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(action)
            if let value = code {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if action != other.action {
                return false
            }
            if code != other.code {
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
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = code {
                let codeValue = try value.toCBORValue()
                map = map.adding(key: "code", value: codeValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case action
            case code
        }
    }
public struct Input: ATProtocolCodable {
        public let groupId: String
        public let cipherSuite: String
        public let initialMembers: [DID]?
        public let welcomeMessage: Bytes?
        public let keyPackageHashes: [KeyPackageHashEntry]?
        public let metadata: MetadataInput?
        public let invite: InviteAction?
        public let currentEpoch: Int?

        /// Standard public initializer
        public init(groupId: String, cipherSuite: String, initialMembers: [DID]? = nil, welcomeMessage: Bytes? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil, metadata: MetadataInput? = nil, invite: InviteAction? = nil, currentEpoch: Int? = nil) {
            self.groupId = groupId
            self.cipherSuite = cipherSuite
            self.initialMembers = initialMembers
            self.welcomeMessage = welcomeMessage
            self.keyPackageHashes = keyPackageHashes
            self.metadata = metadata
            self.invite = invite
            self.currentEpoch = currentEpoch
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.groupId = try container.decode(String.self, forKey: .groupId)
            self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            self.initialMembers = try container.decodeIfPresent([DID].self, forKey: .initialMembers)
            self.welcomeMessage = try container.decodeIfPresent(Bytes.self, forKey: .welcomeMessage)
            self.keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
            self.metadata = try container.decodeIfPresent(MetadataInput.self, forKey: .metadata)
            self.invite = try container.decodeIfPresent(InviteAction.self, forKey: .invite)
            self.currentEpoch = try container.decodeIfPresent(Int.self, forKey: .currentEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(groupId, forKey: .groupId)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encodeIfPresent(initialMembers, forKey: .initialMembers)
            try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
            try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
            try container.encodeIfPresent(metadata, forKey: .metadata)
            try container.encodeIfPresent(invite, forKey: .invite)
            try container.encodeIfPresent(currentEpoch, forKey: .currentEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let groupIdValue = try groupId.toCBORValue()
            map = map.adding(key: "groupId", value: groupIdValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            if let value = initialMembers {
                let initialMembersValue = try value.toCBORValue()
                map = map.adding(key: "initialMembers", value: initialMembersValue)
            }
            if let value = welcomeMessage {
                let welcomeMessageValue = try value.toCBORValue()
                map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
            }
            if let value = keyPackageHashes {
                let keyPackageHashesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
            }
            if let value = metadata {
                let metadataValue = try value.toCBORValue()
                map = map.adding(key: "metadata", value: metadataValue)
            }
            if let value = invite {
                let inviteValue = try value.toCBORValue()
                map = map.adding(key: "invite", value: inviteValue)
            }
            if let value = currentEpoch {
                let currentEpochValue = try value.toCBORValue()
                map = map.adding(key: "currentEpoch", value: currentEpochValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case groupId
            case cipherSuite
            case initialMembers
            case welcomeMessage
            case keyPackageHashes
            case metadata
            case invite
            case currentEpoch
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convo: BlueCatbirdMlsChatDefs.ConvoView
        
        public let inviteCode: String?
        
        public let sequencerDs: DID?
        
        
        
        // Standard public initializer
        public init(
            
            
            convo: BlueCatbirdMlsChatDefs.ConvoView,
            
            inviteCode: String? = nil,
            
            sequencerDs: DID? = nil
            
            
        ) {
            
            
            self.convo = convo
            
            self.inviteCode = inviteCode
            
            self.sequencerDs = sequencerDs
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convo = try container.decode(BlueCatbirdMlsChatDefs.ConvoView.self, forKey: .convo)
            
            
            self.inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
            
            
            self.sequencerDs = try container.decodeIfPresent(DID.self, forKey: .sequencerDs)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convo, forKey: .convo)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(inviteCode, forKey: .inviteCode)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(sequencerDs, forKey: .sequencerDs)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)
            
            
            
            if let value = inviteCode {
                // Encode optional property even if it's an empty array for CBOR
                let inviteCodeValue = try value.toCBORValue()
                map = map.adding(key: "inviteCode", value: inviteCodeValue)
            }
            
            
            
            if let value = sequencerDs {
                // Encode optional property even if it's an empty array for CBOR
                let sequencerDsValue = try value.toCBORValue()
                map = map.adding(key: "sequencerDs", value: sequencerDsValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convo
            case inviteCode
            case sequencerDs
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidCipherSuite = "InvalidCipherSuite.The specified cipher suite is not supported"
                case keyPackageNotFound = "KeyPackageNotFound.Key package not found for one or more initial members"
                case tooManyMembers = "TooManyMembers.Too many initial members specified"
                case mutualBlockDetected = "MutualBlockDetected.Cannot create conversation with users who have blocked each other"
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
    // MARK: - createConvo

    /// Create a new MLS conversation with optional initial members, metadata, and invite link (consolidates createConvo + createInvite + revokeInvite) Create a new MLS conversation. Optionally adds initial members with a Welcome message and creates an invite link in one atomic operation.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createConvo(
        
        input: BlueCatbirdMlsChatCreateConvo.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatCreateConvo.Output?) {
        let endpoint = "blue.catbird.mlsChat.createConvo"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.createConvo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatCreateConvo.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.createConvo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

