import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.commitGroupChange


public struct BlueCatbirdMlsChatCommitGroupChange { 

    public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange"
        
public struct PendingDeviceAddition: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange#pendingDeviceAddition"
            public let id: String
            public let convoId: String
            public let userDid: DID
            public let deviceId: String
            public let deviceCredentialDid: String?
            public let status: String?
            public let createdAt: ATProtocolDate?
            public let claimedBy: DID?
            public let claimedAt: ATProtocolDate?

        public init(
            id: String, convoId: String, userDid: DID, deviceId: String, deviceCredentialDid: String?, status: String?, createdAt: ATProtocolDate?, claimedBy: DID?, claimedAt: ATProtocolDate?
        ) {
            self.id = id
            self.convoId = convoId
            self.userDid = userDid
            self.deviceId = deviceId
            self.deviceCredentialDid = deviceCredentialDid
            self.status = status
            self.createdAt = createdAt
            self.claimedBy = claimedBy
            self.claimedAt = claimedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.userDid = try container.decode(DID.self, forKey: .userDid)
            } catch {
                LogManager.logError("Decoding error for required property 'userDid': \(error)")
                throw error
            }
            do {
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                self.deviceCredentialDid = try container.decodeIfPresent(String.self, forKey: .deviceCredentialDid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'deviceCredentialDid': \(error)")
                throw error
            }
            do {
                self.status = try container.decodeIfPresent(String.self, forKey: .status)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                throw error
            }
            do {
                self.claimedBy = try container.decodeIfPresent(DID.self, forKey: .claimedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'claimedBy': \(error)")
                throw error
            }
            do {
                self.claimedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .claimedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'claimedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(userDid, forKey: .userDid)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(deviceCredentialDid, forKey: .deviceCredentialDid)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(claimedBy, forKey: .claimedBy)
            try container.encodeIfPresent(claimedAt, forKey: .claimedAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(convoId)
            hasher.combine(userDid)
            hasher.combine(deviceId)
            if let value = deviceCredentialDid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = claimedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = claimedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if userDid != other.userDid {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if deviceCredentialDid != other.deviceCredentialDid {
                return false
            }
            if status != other.status {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if claimedBy != other.claimedBy {
                return false
            }
            if claimedAt != other.claimedAt {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            if let value = deviceCredentialDid {
                let deviceCredentialDidValue = try value.toCBORValue()
                map = map.adding(key: "deviceCredentialDid", value: deviceCredentialDidValue)
            }
            if let value = status {
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            if let value = createdAt {
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            if let value = claimedBy {
                let claimedByValue = try value.toCBORValue()
                map = map.adding(key: "claimedBy", value: claimedByValue)
            }
            if let value = claimedAt {
                let claimedAtValue = try value.toCBORValue()
                map = map.adding(key: "claimedAt", value: claimedAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case convoId
            case userDid
            case deviceId
            case deviceCredentialDid
            case status
            case createdAt
            case claimedBy
            case claimedAt
        }
    }
        
public struct KeyPackageHashEntry: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange#keyPackageHashEntry"
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
        public let convoId: String
        public let action: String
        public let memberDids: [String]?
        public let commit: Bytes?
        public let welcome: Bytes?
        public let groupInfo: Bytes?
        public let externalCommit: Bytes?
        public let confirmationTag: String?
        public let idempotencyKey: String?
        public let pendingAdditionId: String?
        public let keyPackageHashes: [KeyPackageHashEntry]?

        /// Standard public initializer
        public init(convoId: String, action: String, memberDids: [String]? = nil, commit: Bytes? = nil, welcome: Bytes? = nil, groupInfo: Bytes? = nil, externalCommit: Bytes? = nil, confirmationTag: String? = nil, idempotencyKey: String? = nil, pendingAdditionId: String? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil) {
            self.convoId = convoId
            self.action = action
            self.memberDids = memberDids
            self.commit = commit
            self.welcome = welcome
            self.groupInfo = groupInfo
            self.externalCommit = externalCommit
            self.confirmationTag = confirmationTag
            self.idempotencyKey = idempotencyKey
            self.pendingAdditionId = pendingAdditionId
            self.keyPackageHashes = keyPackageHashes
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.action = try container.decode(String.self, forKey: .action)
            self.memberDids = try container.decodeIfPresent([String].self, forKey: .memberDids)
            self.commit = try container.decodeIfPresent(Bytes.self, forKey: .commit)
            self.welcome = try container.decodeIfPresent(Bytes.self, forKey: .welcome)
            self.groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            self.externalCommit = try container.decodeIfPresent(Bytes.self, forKey: .externalCommit)
            self.confirmationTag = try container.decodeIfPresent(String.self, forKey: .confirmationTag)
            self.idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            self.pendingAdditionId = try container.decodeIfPresent(String.self, forKey: .pendingAdditionId)
            self.keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(memberDids, forKey: .memberDids)
            try container.encodeIfPresent(commit, forKey: .commit)
            try container.encodeIfPresent(welcome, forKey: .welcome)
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
            try container.encodeIfPresent(externalCommit, forKey: .externalCommit)
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encodeIfPresent(pendingAdditionId, forKey: .pendingAdditionId)
            try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = memberDids {
                let memberDidsValue = try value.toCBORValue()
                map = map.adding(key: "memberDids", value: memberDidsValue)
            }
            if let value = commit {
                let commitValue = try value.toCBORValue()
                map = map.adding(key: "commit", value: commitValue)
            }
            if let value = welcome {
                let welcomeValue = try value.toCBORValue()
                map = map.adding(key: "welcome", value: welcomeValue)
            }
            if let value = groupInfo {
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }
            if let value = externalCommit {
                let externalCommitValue = try value.toCBORValue()
                map = map.adding(key: "externalCommit", value: externalCommitValue)
            }
            if let value = confirmationTag {
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            if let value = pendingAdditionId {
                let pendingAdditionIdValue = try value.toCBORValue()
                map = map.adding(key: "pendingAdditionId", value: pendingAdditionIdValue)
            }
            if let value = keyPackageHashes {
                let keyPackageHashesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case action
            case memberDids
            case commit
            case welcome
            case groupInfo
            case externalCommit
            case confirmationTag
            case idempotencyKey
            case pendingAdditionId
            case keyPackageHashes
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let newEpoch: Int?
        
        public let confirmationTag: String?
        
        public let claimedAddition: PendingDeviceAddition?
        
        public let pendingAdditions: [PendingDeviceAddition]?
        
        public let rejoinedAt: ATProtocolDate?
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            newEpoch: Int? = nil,
            
            confirmationTag: String? = nil,
            
            claimedAddition: PendingDeviceAddition? = nil,
            
            pendingAdditions: [PendingDeviceAddition]? = nil,
            
            rejoinedAt: ATProtocolDate? = nil
            
            
        ) {
            
            
            self.success = success
            
            self.newEpoch = newEpoch
            
            self.confirmationTag = confirmationTag
            
            self.claimedAddition = claimedAddition
            
            self.pendingAdditions = pendingAdditions
            
            self.rejoinedAt = rejoinedAt
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.newEpoch = try container.decodeIfPresent(Int.self, forKey: .newEpoch)
            
            
            self.confirmationTag = try container.decodeIfPresent(String.self, forKey: .confirmationTag)
            
            
            self.claimedAddition = try container.decodeIfPresent(PendingDeviceAddition.self, forKey: .claimedAddition)
            
            
            self.pendingAdditions = try container.decodeIfPresent([PendingDeviceAddition].self, forKey: .pendingAdditions)
            
            
            self.rejoinedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .rejoinedAt)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(newEpoch, forKey: .newEpoch)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(claimedAddition, forKey: .claimedAddition)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pendingAdditions, forKey: .pendingAdditions)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rejoinedAt, forKey: .rejoinedAt)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let successValue = try success.toCBORValue()
            map = map.adding(key: "success", value: successValue)
            
            
            
            if let value = newEpoch {
                // Encode optional property even if it's an empty array for CBOR
                let newEpochValue = try value.toCBORValue()
                map = map.adding(key: "newEpoch", value: newEpochValue)
            }
            
            
            
            if let value = confirmationTag {
                // Encode optional property even if it's an empty array for CBOR
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }
            
            
            
            if let value = claimedAddition {
                // Encode optional property even if it's an empty array for CBOR
                let claimedAdditionValue = try value.toCBORValue()
                map = map.adding(key: "claimedAddition", value: claimedAdditionValue)
            }
            
            
            
            if let value = pendingAdditions {
                // Encode optional property even if it's an empty array for CBOR
                let pendingAdditionsValue = try value.toCBORValue()
                map = map.adding(key: "pendingAdditions", value: pendingAdditionsValue)
            }
            
            
            
            if let value = rejoinedAt {
                // Encode optional property even if it's an empty array for CBOR
                let rejoinedAtValue = try value.toCBORValue()
                map = map.adding(key: "rejoinedAt", value: rejoinedAtValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case newEpoch
            case confirmationTag
            case claimedAddition
            case pendingAdditions
            case rejoinedAt
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidRequest = "InvalidRequest.Invalid request parameters"
                case authRequired = "AuthRequired.Authentication required"
                case forbidden = "Forbidden.User does not have permission for this action"
                case conflict = "Conflict.Conflicting group state (e.g., epoch mismatch)"
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.User is not a member of this conversation"
                case alreadyMember = "AlreadyMember.User is already a member of this conversation"
                case keyPackageNotFound = "KeyPackageNotFound.Key package not found for one or more members"
                case tooManyMembers = "TooManyMembers.Adding these members would exceed the maximum group size"
                case blockedByMember = "BlockedByMember.Action blocked by a member's block list"
                case invalidAction = "InvalidAction.The specified action is not valid"
                case invalidCommit = "InvalidCommit.The MLS commit message is invalid"
                case invalidGroupInfo = "InvalidGroupInfo.The MLS group info is invalid"
                case pendingAdditionNotFound = "PendingAdditionNotFound.The specified pending addition was not found"
                case pendingAdditionAlreadyClaimed = "PendingAdditionAlreadyClaimed.The pending addition has already been claimed by another device"
                case unauthorized = "Unauthorized.User is not authorized for this action"
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
    // MARK: - commitGroupChange

    /// Commit an MLS group change (add members, process external commit, rejoin, readdition, or manage pending device additions)
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func commitGroupChange(
        
        input: BlueCatbirdMlsChatCommitGroupChange.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatCommitGroupChange.Output?) {
        let endpoint = "blue.catbird.mlsChat.commitGroupChange"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.commitGroupChange")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatCommitGroupChange.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.commitGroupChange: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

