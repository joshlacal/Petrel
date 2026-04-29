import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.bootstrapResetGroup


public struct BlueCatbirdMlsChatBootstrapResetGroup { 

    public static let typeIdentifier = "blue.catbird.mlsChat.bootstrapResetGroup"
        
public struct KeyPackageHashEntry: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.bootstrapResetGroup#keyPackageHashEntry"
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
public struct Input: ATProtocolCodable {
        public let originalConvoId: String
        public let newGroupId: String
        public let cipherSuite: String
        public let groupInfo: Bytes
        public let members: [DID]
        public let welcomeMessage: Bytes?
        public let keyPackageHashes: [KeyPackageHashEntry]?
        public let currentEpoch: Int?

        /// Standard public initializer
        public init(originalConvoId: String, newGroupId: String, cipherSuite: String, groupInfo: Bytes, members: [DID], welcomeMessage: Bytes? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil, currentEpoch: Int? = nil) {
            self.originalConvoId = originalConvoId
            self.newGroupId = newGroupId
            self.cipherSuite = cipherSuite
            self.groupInfo = groupInfo
            self.members = members
            self.welcomeMessage = welcomeMessage
            self.keyPackageHashes = keyPackageHashes
            self.currentEpoch = currentEpoch
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.originalConvoId = try container.decode(String.self, forKey: .originalConvoId)
            self.newGroupId = try container.decode(String.self, forKey: .newGroupId)
            self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            self.groupInfo = try container.decode(Bytes.self, forKey: .groupInfo)
            self.members = try container.decode([DID].self, forKey: .members)
            self.welcomeMessage = try container.decodeIfPresent(Bytes.self, forKey: .welcomeMessage)
            self.keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
            self.currentEpoch = try container.decodeIfPresent(Int.self, forKey: .currentEpoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(originalConvoId, forKey: .originalConvoId)
            try container.encode(newGroupId, forKey: .newGroupId)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(groupInfo, forKey: .groupInfo)
            try container.encode(members, forKey: .members)
            try container.encodeIfPresent(welcomeMessage, forKey: .welcomeMessage)
            try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
            try container.encodeIfPresent(currentEpoch, forKey: .currentEpoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let originalConvoIdValue = try originalConvoId.toCBORValue()
            map = map.adding(key: "originalConvoId", value: originalConvoIdValue)
            let newGroupIdValue = try newGroupId.toCBORValue()
            map = map.adding(key: "newGroupId", value: newGroupIdValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            let groupInfoValue = try groupInfo.toCBORValue()
            map = map.adding(key: "groupInfo", value: groupInfoValue)
            let membersValue = try members.toCBORValue()
            map = map.adding(key: "members", value: membersValue)
            if let value = welcomeMessage {
                let welcomeMessageValue = try value.toCBORValue()
                map = map.adding(key: "welcomeMessage", value: welcomeMessageValue)
            }
            if let value = keyPackageHashes {
                let keyPackageHashesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
            }
            if let value = currentEpoch {
                let currentEpochValue = try value.toCBORValue()
                map = map.adding(key: "currentEpoch", value: currentEpochValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case originalConvoId
            case newGroupId
            case cipherSuite
            case groupInfo
            case members
            case welcomeMessage
            case keyPackageHashes
            case currentEpoch
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let convo: BlueCatbirdMlsChatDefs.ConvoView
        
        public let generation: Int?
        
        
        
        // Standard public initializer
        public init(
            
            
            convo: BlueCatbirdMlsChatDefs.ConvoView,
            
            generation: Int? = nil
            
            
        ) {
            
            
            self.convo = convo
            
            self.generation = generation
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.convo = try container.decode(BlueCatbirdMlsChatDefs.ConvoView.self, forKey: .convo)
            
            
            self.generation = try container.decodeIfPresent(Int.self, forKey: .generation)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(convo, forKey: .convo)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(generation, forKey: .generation)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let convoValue = try convo.toCBORValue()
            map = map.adding(key: "convo", value: convoValue)
            
            
            
            if let value = generation {
                // Encode optional property even if it's an empty array for CBOR
                let generationValue = try value.toCBORValue()
                map = map.adding(key: "generation", value: generationValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case convo
            case generation
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case bootstrapTargetNotFound = "BootstrapTargetNotFound.No conversation row matches (originalConvoId, newGroupId). Either the convo doesn't exist, or the post-reset group_id has already been overwritten by a subsequent reset."
                case alreadyBootstrapped = "AlreadyBootstrapped.The post-reset row has already been bootstrapped by another caller (group_info IS NOT NULL). Caller lost the first-responder race; fall back to receiving the Welcome from the winner."
                case notMember = "NotMember.Caller is not in the existing member roster for this convo and so is not allowed to bootstrap it."
                case invalidCipherSuite = "InvalidCipherSuite.The specified cipher suite is not supported."
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
    // MARK: - bootstrapResetGroup

    /// Complete a post-auto-reset conversation by populating its emptied MLS state (group_info, welcome messages). The post-reset row exists with id=originalConvoId, group_id=newGroupId, and group_info=NULL — this endpoint UPDATEs that row in place rather than INSERTing a new conversation. First caller (in the existing member roster) for a given (originalConvoId, newGroupId) wins; later callers receive AlreadyBootstrapped 409 and fall back to receiving the Welcome from the winner. Bootstrap a post-auto-reset conversation in place. Member roster is preserved across reset, so this endpoint does not re-insert members.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func bootstrapResetGroup(
        
        input: BlueCatbirdMlsChatBootstrapResetGroup.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatBootstrapResetGroup.Output?) {
        let endpoint = "blue.catbird.mlsChat.bootstrapResetGroup"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.bootstrapResetGroup")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        
        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200...299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

            do {
                
                let decoder = JSONDecoder()
                let decodedData = try decoder.decode(BlueCatbirdMlsChatBootstrapResetGroup.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.bootstrapResetGroup: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

