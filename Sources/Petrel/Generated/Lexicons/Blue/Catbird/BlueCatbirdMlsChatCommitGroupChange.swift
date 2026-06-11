import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.commitGroupChange

public enum BlueCatbirdMlsChatCommitGroupChange {
    public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange"

    public struct RateLimitedBody: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange#rateLimitedBody"
        public let error: String
        public let message: String
        public let retryAfterSeconds: Int
        public let scope: String

        public init(
            error: String, message: String, retryAfterSeconds: Int, scope: String
        ) {
            self.error = error
            self.message = message
            self.retryAfterSeconds = retryAfterSeconds
            self.scope = scope
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                error = try container.decode(String.self, forKey: .error)
            } catch {
                LogManager.logError("Decoding error for required property 'error': \(error)")
                throw error
            }
            do {
                message = try container.decode(String.self, forKey: .message)
            } catch {
                LogManager.logError("Decoding error for required property 'message': \(error)")
                throw error
            }
            do {
                retryAfterSeconds = try container.decode(Int.self, forKey: .retryAfterSeconds)
            } catch {
                LogManager.logError("Decoding error for required property 'retryAfterSeconds': \(error)")
                throw error
            }
            do {
                scope = try container.decode(String.self, forKey: .scope)
            } catch {
                LogManager.logError("Decoding error for required property 'scope': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(error, forKey: .error)
            try container.encode(message, forKey: .message)
            try container.encode(retryAfterSeconds, forKey: .retryAfterSeconds)
            try container.encode(scope, forKey: .scope)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(error)
            hasher.combine(message)
            hasher.combine(retryAfterSeconds)
            hasher.combine(scope)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if error != other.error {
                return false
            }
            if message != other.message {
                return false
            }
            if retryAfterSeconds != other.retryAfterSeconds {
                return false
            }
            if scope != other.scope {
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
            let errorValue = try error.toCBORValue()
            map = map.adding(key: "error", value: errorValue)
            let messageValue = try message.toCBORValue()
            map = map.adding(key: "message", value: messageValue)
            let retryAfterSecondsValue = try retryAfterSeconds.toCBORValue()
            map = map.adding(key: "retryAfterSeconds", value: retryAfterSecondsValue)
            let scopeValue = try scope.toCBORValue()
            map = map.adding(key: "scope", value: scopeValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case error
            case message
            case retryAfterSeconds
            case scope
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
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                hash = try container.decode(String.self, forKey: .hash)
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

    public struct PendingDeviceAddition: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.commitGroupChange#pendingDeviceAddition"
        public let id: String
        public let convoId: String
        public let userDid: DID
        public let deviceId: String
        public let deviceName: String?
        public let deviceCredentialDid: String
        public let status: String
        public let claimedBy: DID?
        public let createdAt: ATProtocolDate

        public init(
            id: String, convoId: String, userDid: DID, deviceId: String, deviceName: String?, deviceCredentialDid: String, status: String, claimedBy: DID?, createdAt: ATProtocolDate
        ) {
            self.id = id
            self.convoId = convoId
            self.userDid = userDid
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceCredentialDid = deviceCredentialDid
            self.status = status
            self.claimedBy = claimedBy
            self.createdAt = createdAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                id = try container.decode(String.self, forKey: .id)
            } catch {
                LogManager.logError("Decoding error for required property 'id': \(error)")
                throw error
            }
            do {
                convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                userDid = try container.decode(DID.self, forKey: .userDid)
            } catch {
                LogManager.logError("Decoding error for required property 'userDid': \(error)")
                throw error
            }
            do {
                deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'deviceName' — degrading to nil: \(error)")
                deviceName = nil
            }
            do {
                deviceCredentialDid = try container.decode(String.self, forKey: .deviceCredentialDid)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceCredentialDid': \(error)")
                throw error
            }
            do {
                status = try container.decode(String.self, forKey: .status)
            } catch {
                LogManager.logError("Decoding error for required property 'status': \(error)")
                throw error
            }
            do {
                claimedBy = try container.decodeIfPresent(DID.self, forKey: .claimedBy)
            } catch {
                // Forward compatibility: a malformed or unknown-shaped optional field
                // must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'claimedBy' — degrading to nil: \(error)")
                claimedBy = nil
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
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
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(deviceCredentialDid, forKey: .deviceCredentialDid)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(claimedBy, forKey: .claimedBy)
            try container.encode(createdAt, forKey: .createdAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(convoId)
            hasher.combine(userDid)
            hasher.combine(deviceId)
            if let value = deviceName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(deviceCredentialDid)
            hasher.combine(status)
            if let value = claimedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(createdAt)
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
            if deviceName != other.deviceName {
                return false
            }
            if deviceCredentialDid != other.deviceCredentialDid {
                return false
            }
            if status != other.status {
                return false
            }
            if claimedBy != other.claimedBy {
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
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let userDidValue = try userDid.toCBORValue()
            map = map.adding(key: "userDid", value: userDidValue)
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            if let value = deviceName {
                let deviceNameValue = try value.toCBORValue()
                map = map.adding(key: "deviceName", value: deviceNameValue)
            }
            let deviceCredentialDidValue = try deviceCredentialDid.toCBORValue()
            map = map.adding(key: "deviceCredentialDid", value: deviceCredentialDidValue)
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            if let value = claimedBy {
                let claimedByValue = try value.toCBORValue()
                map = map.adding(key: "claimedBy", value: claimedByValue)
            }
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case convoId
            case userDid
            case deviceId
            case deviceName
            case deviceCredentialDid
            case status
            case claimedBy
            case createdAt
        }
    }

    public struct Input: ATProtocolCodable {
        public let convoId: String
        public let action: String
        public let memberDids: [DID]?
        public let commit: Bytes?
        public let welcome: Bytes?
        public let groupInfo: Bytes?
        public let keyPackageHashes: [KeyPackageHashEntry]?
        public let deviceId: String?
        public let pendingAdditionId: String?
        public let idempotencyKey: String?
        public let confirmationTag: Bytes?
        public let epochAuthenticator: String?

        /// Standard public initializer
        public init(convoId: String, action: String, memberDids: [DID]? = nil, commit: Bytes? = nil, welcome: Bytes? = nil, groupInfo: Bytes? = nil, keyPackageHashes: [KeyPackageHashEntry]? = nil, deviceId: String? = nil, pendingAdditionId: String? = nil, idempotencyKey: String? = nil, confirmationTag: Bytes? = nil, epochAuthenticator: String? = nil) {
            self.convoId = convoId
            self.action = action
            self.memberDids = memberDids
            self.commit = commit
            self.welcome = welcome
            self.groupInfo = groupInfo
            self.keyPackageHashes = keyPackageHashes
            self.deviceId = deviceId
            self.pendingAdditionId = pendingAdditionId
            self.idempotencyKey = idempotencyKey
            self.confirmationTag = confirmationTag
            self.epochAuthenticator = epochAuthenticator
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            convoId = try container.decode(String.self, forKey: .convoId)
            action = try container.decode(String.self, forKey: .action)
            memberDids = try container.decodeIfPresent([DID].self, forKey: .memberDids)
            commit = try container.decodeIfPresent(Bytes.self, forKey: .commit)
            welcome = try container.decodeIfPresent(Bytes.self, forKey: .welcome)
            groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            keyPackageHashes = try container.decodeIfPresent([KeyPackageHashEntry].self, forKey: .keyPackageHashes)
            deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            pendingAdditionId = try container.decodeIfPresent(String.self, forKey: .pendingAdditionId)
            idempotencyKey = try container.decodeIfPresent(String.self, forKey: .idempotencyKey)
            confirmationTag = try container.decodeIfPresent(Bytes.self, forKey: .confirmationTag)
            epochAuthenticator = try container.decodeIfPresent(String.self, forKey: .epochAuthenticator)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(memberDids, forKey: .memberDids)
            try container.encodeIfPresent(commit, forKey: .commit)
            try container.encodeIfPresent(welcome, forKey: .welcome)
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
            try container.encodeIfPresent(keyPackageHashes, forKey: .keyPackageHashes)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(pendingAdditionId, forKey: .pendingAdditionId)
            try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
            try container.encodeIfPresent(epochAuthenticator, forKey: .epochAuthenticator)
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
            if let value = keyPackageHashes {
                let keyPackageHashesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackageHashes", value: keyPackageHashesValue)
            }
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            if let value = pendingAdditionId {
                let pendingAdditionIdValue = try value.toCBORValue()
                map = map.adding(key: "pendingAdditionId", value: pendingAdditionIdValue)
            }
            if let value = idempotencyKey {
                let idempotencyKeyValue = try value.toCBORValue()
                map = map.adding(key: "idempotencyKey", value: idempotencyKeyValue)
            }
            if let value = confirmationTag {
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }
            if let value = epochAuthenticator {
                let epochAuthenticatorValue = try value.toCBORValue()
                map = map.adding(key: "epochAuthenticator", value: epochAuthenticatorValue)
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
            case keyPackageHashes
            case deviceId
            case pendingAdditionId
            case idempotencyKey
            case confirmationTag
            case epochAuthenticator
        }
    }

    public struct Output: ATProtocolCodable {
        public let success: Bool

        public let newEpoch: Int?

        public let rejoinedAt: ATProtocolDate?

        public let pendingAdditions: [PendingDeviceAddition]?

        public let claimedAddition: PendingDeviceAddition?

        public let confirmationTag: Bytes?

        /// Standard public initializer
        public init(
            success: Bool,

            newEpoch: Int? = nil,

            rejoinedAt: ATProtocolDate? = nil,

            pendingAdditions: [PendingDeviceAddition]? = nil,

            claimedAddition: PendingDeviceAddition? = nil,

            confirmationTag: Bytes? = nil

        ) {
            self.success = success

            self.newEpoch = newEpoch

            self.rejoinedAt = rejoinedAt

            self.pendingAdditions = pendingAdditions

            self.claimedAddition = claimedAddition

            self.confirmationTag = confirmationTag
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            success = try container.decode(Bool.self, forKey: .success)

            do {
                newEpoch = try container.decodeIfPresent(Int.self, forKey: .newEpoch)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'newEpoch' — degrading to nil: \(error)")
                newEpoch = nil
            }

            do {
                rejoinedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .rejoinedAt)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'rejoinedAt' — degrading to nil: \(error)")
                rejoinedAt = nil
            }

            do {
                pendingAdditions = try container.decodeIfPresent([PendingDeviceAddition].self, forKey: .pendingAdditions)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'pendingAdditions' — degrading to nil: \(error)")
                pendingAdditions = nil
            }

            do {
                claimedAddition = try container.decodeIfPresent(PendingDeviceAddition.self, forKey: .claimedAddition)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'claimedAddition' — degrading to nil: \(error)")
                claimedAddition = nil
            }

            do {
                confirmationTag = try container.decodeIfPresent(Bytes.self, forKey: .confirmationTag)
            } catch {
                // Forward compatibility: a malformed optional field must not fail the whole response.
                LogManager.logWarning("Decoding error for optional property 'confirmationTag' — degrading to nil: \(error)")
                confirmationTag = nil
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(success, forKey: .success)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(newEpoch, forKey: .newEpoch)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rejoinedAt, forKey: .rejoinedAt)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pendingAdditions, forKey: .pendingAdditions)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(claimedAddition, forKey: .claimedAddition)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(confirmationTag, forKey: .confirmationTag)
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

            if let value = rejoinedAt {
                // Encode optional property even if it's an empty array for CBOR
                let rejoinedAtValue = try value.toCBORValue()
                map = map.adding(key: "rejoinedAt", value: rejoinedAtValue)
            }

            if let value = pendingAdditions {
                // Encode optional property even if it's an empty array for CBOR
                let pendingAdditionsValue = try value.toCBORValue()
                map = map.adding(key: "pendingAdditions", value: pendingAdditionsValue)
            }

            if let value = claimedAddition {
                // Encode optional property even if it's an empty array for CBOR
                let claimedAdditionValue = try value.toCBORValue()
                map = map.adding(key: "claimedAddition", value: claimedAdditionValue)
            }

            if let value = confirmationTag {
                // Encode optional property even if it's an empty array for CBOR
                let confirmationTagValue = try value.toCBORValue()
                map = map.adding(key: "confirmationTag", value: confirmationTagValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case success
            case newEpoch
            case rejoinedAt
            case pendingAdditions
            case claimedAddition
            case confirmationTag
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case convoNotFound = "ConvoNotFound.Conversation not found"
        case notMember = "NotMember.Caller is not a member of the conversation"
        case invalidAction = "InvalidAction.Unknown action value"
        case keyPackageNotFound = "KeyPackageNotFound.Key package not found for one or more members"
        case alreadyMember = "AlreadyMember.One or more DIDs are already members"
        case tooManyMembers = "TooManyMembers.Would exceed maximum member count"
        case blockedByMember = "BlockedByMember.Cannot add user who has blocked or been blocked by an existing member"
        case invalidCommit = "InvalidCommit.The provided MLS Commit message is invalid"
        case invalidGroupInfo = "InvalidGroupInfo.The provided GroupInfo is invalid"
        case pendingAdditionNotFound = "PendingAdditionNotFound.The specified pending addition does not exist"
        case pendingAdditionAlreadyClaimed = "PendingAdditionAlreadyClaimed.The pending addition was already claimed by another member"
        case unauthorized = "Unauthorized.Insufficient privileges for this operation"
        case noKeyPackagesPublished = "NoKeyPackagesPublished.Layer 1 robustness gate: the calling device has zero published key packages and is therefore not eligible to issue an External Commit. The device must call publishKeyPackages and successfully publish at least one available, non-expired key package before retrying. Returned as HTTP 412 Precondition Failed."
        case groupFrozen = "GroupFrozen.Layer 1 robustness circuit breaker: the conversation has been temporarily frozen because the server detected an epoch-storm pattern (too many epoch advances within a short window). All epoch-advancing commits are rejected until the freeze auto-thaws. Returned as HTTP 423 Locked."
        case rateLimited = "RateLimited.Rate limit exceeded. Two cases: (a) per-conversation 30s External-Commit limit (existing). (b) per-(device, group) 60s External-Commit cooldown (Layer 1 §1.2). Both return HTTP 429 with body shaped per #rateLimitedBody (retryAfterSeconds + scope discriminator)."
        public var description: String {
            return rawValue
        }

        public var errorName: String {
            // Extract just the error name from the raw value
            let parts = rawValue.split(separator: ".")
            return String(parts.first ?? "")
        }
    }
}

public extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - commitGroupChange

    // Commit MLS group membership changes (consolidates addMembers + processExternalCommit + rejoin + readdition + getPendingDeviceAdditions + claimPendingDeviceAddition + completePendingDeviceAddition) Perform MLS group membership operations. The 'action' field determines the operation type. This consolidates all membership-changing operations into a single endpoint.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func commitGroupChange(
        input: BlueCatbirdMlsChatCommitGroupChange.Input

    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatCommitGroupChange.Output?) {
        let endpoint = "blue.catbird.mlsChat.commitGroupChange"

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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.commitGroupChange")
        let proxyHeaders = serviceDID.map { ["atproto-proxy": $0] }
        let (responseData, response) = try await networkService.performRequest(urlRequest, skipTokenRefresh: false, additionalHeaders: proxyHeaders)
        let responseCode = response.statusCode

        // Only validate Content-Type and decode on success. Error responses
        // (4xx/5xx) may have missing or different Content-Type headers and
        // are handled by the caller via the status code.
        if (200 ... 299).contains(responseCode) {
            guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
                throw NetworkError.invalidContentType(expected: "application/json", actual: "nil")
            }

            if !contentType.lowercased().contains("application/json") {
                throw NetworkError.invalidContentType(expected: "application/json", actual: contentType)
            }

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
