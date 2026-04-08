import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.updateConvo


public struct BlueCatbirdMlsChatUpdateConvo { 

    public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo"
        
public struct PolicyInput: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo#policyInput"
            public let allowInvites: Bool?
            public let adminOnlyInvites: Bool?
            public let allowMemberAdd: Bool?
            public let allowMemberRemove: Bool?
            public let requireAdminApproval: Bool?
            public let maxMembers: Int?

        public init(
            allowInvites: Bool?, adminOnlyInvites: Bool?, allowMemberAdd: Bool?, allowMemberRemove: Bool?, requireAdminApproval: Bool?, maxMembers: Int?
        ) {
            self.allowInvites = allowInvites
            self.adminOnlyInvites = adminOnlyInvites
            self.allowMemberAdd = allowMemberAdd
            self.allowMemberRemove = allowMemberRemove
            self.requireAdminApproval = requireAdminApproval
            self.maxMembers = maxMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.allowInvites = try container.decodeIfPresent(Bool.self, forKey: .allowInvites)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowInvites': \(error)")
                throw error
            }
            do {
                self.adminOnlyInvites = try container.decodeIfPresent(Bool.self, forKey: .adminOnlyInvites)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'adminOnlyInvites': \(error)")
                throw error
            }
            do {
                self.allowMemberAdd = try container.decodeIfPresent(Bool.self, forKey: .allowMemberAdd)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowMemberAdd': \(error)")
                throw error
            }
            do {
                self.allowMemberRemove = try container.decodeIfPresent(Bool.self, forKey: .allowMemberRemove)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowMemberRemove': \(error)")
                throw error
            }
            do {
                self.requireAdminApproval = try container.decodeIfPresent(Bool.self, forKey: .requireAdminApproval)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requireAdminApproval': \(error)")
                throw error
            }
            do {
                self.maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'maxMembers': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(allowInvites, forKey: .allowInvites)
            try container.encodeIfPresent(adminOnlyInvites, forKey: .adminOnlyInvites)
            try container.encodeIfPresent(allowMemberAdd, forKey: .allowMemberAdd)
            try container.encodeIfPresent(allowMemberRemove, forKey: .allowMemberRemove)
            try container.encodeIfPresent(requireAdminApproval, forKey: .requireAdminApproval)
            try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = allowInvites {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = adminOnlyInvites {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowMemberAdd {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowMemberRemove {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = requireAdminApproval {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = maxMembers {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if allowInvites != other.allowInvites {
                return false
            }
            if adminOnlyInvites != other.adminOnlyInvites {
                return false
            }
            if allowMemberAdd != other.allowMemberAdd {
                return false
            }
            if allowMemberRemove != other.allowMemberRemove {
                return false
            }
            if requireAdminApproval != other.requireAdminApproval {
                return false
            }
            if maxMembers != other.maxMembers {
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
            if let value = allowInvites {
                let allowInvitesValue = try value.toCBORValue()
                map = map.adding(key: "allowInvites", value: allowInvitesValue)
            }
            if let value = adminOnlyInvites {
                let adminOnlyInvitesValue = try value.toCBORValue()
                map = map.adding(key: "adminOnlyInvites", value: adminOnlyInvitesValue)
            }
            if let value = allowMemberAdd {
                let allowMemberAddValue = try value.toCBORValue()
                map = map.adding(key: "allowMemberAdd", value: allowMemberAddValue)
            }
            if let value = allowMemberRemove {
                let allowMemberRemoveValue = try value.toCBORValue()
                map = map.adding(key: "allowMemberRemove", value: allowMemberRemoveValue)
            }
            if let value = requireAdminApproval {
                let requireAdminApprovalValue = try value.toCBORValue()
                map = map.adding(key: "requireAdminApproval", value: requireAdminApprovalValue)
            }
            if let value = maxMembers {
                let maxMembersValue = try value.toCBORValue()
                map = map.adding(key: "maxMembers", value: maxMembersValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowInvites
            case adminOnlyInvites
            case allowMemberAdd
            case allowMemberRemove
            case requireAdminApproval
            case maxMembers
        }
    }
        
public struct PolicyView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo#policyView"
            public let convoId: String
            public let allowInvites: Bool
            public let adminOnlyInvites: Bool
            public let allowMemberAdd: Bool
            public let allowMemberRemove: Bool
            public let requireAdminApproval: Bool
            public let maxMembers: Int
            public let updatedAt: ATProtocolDate
            public let updatedBy: DID?

        public init(
            convoId: String, allowInvites: Bool, adminOnlyInvites: Bool, allowMemberAdd: Bool, allowMemberRemove: Bool, requireAdminApproval: Bool, maxMembers: Int, updatedAt: ATProtocolDate, updatedBy: DID?
        ) {
            self.convoId = convoId
            self.allowInvites = allowInvites
            self.adminOnlyInvites = adminOnlyInvites
            self.allowMemberAdd = allowMemberAdd
            self.allowMemberRemove = allowMemberRemove
            self.requireAdminApproval = requireAdminApproval
            self.maxMembers = maxMembers
            self.updatedAt = updatedAt
            self.updatedBy = updatedBy
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
                self.allowInvites = try container.decode(Bool.self, forKey: .allowInvites)
            } catch {
                LogManager.logError("Decoding error for required property 'allowInvites': \(error)")
                throw error
            }
            do {
                self.adminOnlyInvites = try container.decode(Bool.self, forKey: .adminOnlyInvites)
            } catch {
                LogManager.logError("Decoding error for required property 'adminOnlyInvites': \(error)")
                throw error
            }
            do {
                self.allowMemberAdd = try container.decode(Bool.self, forKey: .allowMemberAdd)
            } catch {
                LogManager.logError("Decoding error for required property 'allowMemberAdd': \(error)")
                throw error
            }
            do {
                self.allowMemberRemove = try container.decode(Bool.self, forKey: .allowMemberRemove)
            } catch {
                LogManager.logError("Decoding error for required property 'allowMemberRemove': \(error)")
                throw error
            }
            do {
                self.requireAdminApproval = try container.decode(Bool.self, forKey: .requireAdminApproval)
            } catch {
                LogManager.logError("Decoding error for required property 'requireAdminApproval': \(error)")
                throw error
            }
            do {
                self.maxMembers = try container.decode(Int.self, forKey: .maxMembers)
            } catch {
                LogManager.logError("Decoding error for required property 'maxMembers': \(error)")
                throw error
            }
            do {
                self.updatedAt = try container.decode(ATProtocolDate.self, forKey: .updatedAt)
            } catch {
                LogManager.logError("Decoding error for required property 'updatedAt': \(error)")
                throw error
            }
            do {
                self.updatedBy = try container.decodeIfPresent(DID.self, forKey: .updatedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'updatedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(allowInvites, forKey: .allowInvites)
            try container.encode(adminOnlyInvites, forKey: .adminOnlyInvites)
            try container.encode(allowMemberAdd, forKey: .allowMemberAdd)
            try container.encode(allowMemberRemove, forKey: .allowMemberRemove)
            try container.encode(requireAdminApproval, forKey: .requireAdminApproval)
            try container.encode(maxMembers, forKey: .maxMembers)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(updatedBy, forKey: .updatedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(allowInvites)
            hasher.combine(adminOnlyInvites)
            hasher.combine(allowMemberAdd)
            hasher.combine(allowMemberRemove)
            hasher.combine(requireAdminApproval)
            hasher.combine(maxMembers)
            hasher.combine(updatedAt)
            if let value = updatedBy {
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
            if allowInvites != other.allowInvites {
                return false
            }
            if adminOnlyInvites != other.adminOnlyInvites {
                return false
            }
            if allowMemberAdd != other.allowMemberAdd {
                return false
            }
            if allowMemberRemove != other.allowMemberRemove {
                return false
            }
            if requireAdminApproval != other.requireAdminApproval {
                return false
            }
            if maxMembers != other.maxMembers {
                return false
            }
            if updatedAt != other.updatedAt {
                return false
            }
            if updatedBy != other.updatedBy {
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
            let allowInvitesValue = try allowInvites.toCBORValue()
            map = map.adding(key: "allowInvites", value: allowInvitesValue)
            let adminOnlyInvitesValue = try adminOnlyInvites.toCBORValue()
            map = map.adding(key: "adminOnlyInvites", value: adminOnlyInvitesValue)
            let allowMemberAddValue = try allowMemberAdd.toCBORValue()
            map = map.adding(key: "allowMemberAdd", value: allowMemberAddValue)
            let allowMemberRemoveValue = try allowMemberRemove.toCBORValue()
            map = map.adding(key: "allowMemberRemove", value: allowMemberRemoveValue)
            let requireAdminApprovalValue = try requireAdminApproval.toCBORValue()
            map = map.adding(key: "requireAdminApproval", value: requireAdminApprovalValue)
            let maxMembersValue = try maxMembers.toCBORValue()
            map = map.adding(key: "maxMembers", value: maxMembersValue)
            let updatedAtValue = try updatedAt.toCBORValue()
            map = map.adding(key: "updatedAt", value: updatedAtValue)
            if let value = updatedBy {
                let updatedByValue = try value.toCBORValue()
                map = map.adding(key: "updatedBy", value: updatedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case allowInvites
            case adminOnlyInvites
            case allowMemberAdd
            case allowMemberRemove
            case requireAdminApproval
            case maxMembers
            case updatedAt
            case updatedBy
        }
    }
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let action: String
        public let targetDid: DID?
        public let policy: PolicyInput?
        public let groupInfo: Bytes?
        public let epoch: Int?

        /// Standard public initializer
        public init(convoId: String, action: String, targetDid: DID? = nil, policy: PolicyInput? = nil, groupInfo: Bytes? = nil, epoch: Int? = nil) {
            self.convoId = convoId
            self.action = action
            self.targetDid = targetDid
            self.policy = policy
            self.groupInfo = groupInfo
            self.epoch = epoch
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.action = try container.decode(String.self, forKey: .action)
            self.targetDid = try container.decodeIfPresent(DID.self, forKey: .targetDid)
            self.policy = try container.decodeIfPresent(PolicyInput.self, forKey: .policy)
            self.groupInfo = try container.decodeIfPresent(Bytes.self, forKey: .groupInfo)
            self.epoch = try container.decodeIfPresent(Int.self, forKey: .epoch)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(targetDid, forKey: .targetDid)
            try container.encodeIfPresent(policy, forKey: .policy)
            try container.encodeIfPresent(groupInfo, forKey: .groupInfo)
            try container.encodeIfPresent(epoch, forKey: .epoch)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = targetDid {
                let targetDidValue = try value.toCBORValue()
                map = map.adding(key: "targetDid", value: targetDidValue)
            }
            if let value = policy {
                let policyValue = try value.toCBORValue()
                map = map.adding(key: "policy", value: policyValue)
            }
            if let value = groupInfo {
                let groupInfoValue = try value.toCBORValue()
                map = map.adding(key: "groupInfo", value: groupInfoValue)
            }
            if let value = epoch {
                let epochValue = try value.toCBORValue()
                map = map.adding(key: "epoch", value: epochValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case action
            case targetDid
            case policy
            case groupInfo
            case epoch
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool
        
        public let newEpoch: Int?
        
        public let policy: PolicyView?
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool,
            
            newEpoch: Int? = nil,
            
            policy: PolicyView? = nil
            
            
        ) {
            
            
            self.success = success
            
            self.newEpoch = newEpoch
            
            self.policy = policy
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decode(Bool.self, forKey: .success)
            
            
            self.newEpoch = try container.decodeIfPresent(Int.self, forKey: .newEpoch)
            
            
            self.policy = try container.decodeIfPresent(PolicyView.self, forKey: .policy)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(success, forKey: .success)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(newEpoch, forKey: .newEpoch)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(policy, forKey: .policy)
            
            
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
            
            
            
            if let value = policy {
                // Encode optional property even if it's an empty array for CBOR
                let policyValue = try value.toCBORValue()
                map = map.adding(key: "policy", value: policyValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case newEpoch
            case policy
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of this conversation"
                case unauthorized = "Unauthorized.Caller does not have required admin/moderator privileges"
                case invalidAction = "InvalidAction.Unknown action value"
                case missingTargetDid = "MissingTargetDid.targetDid is required for promote/demote actions"
                case targetNotMember = "TargetNotMember.Target DID is not a member of the conversation"
                case noFieldsProvided = "NoFieldsProvided.At least one policy field must be provided for updatePolicy"
                case invalidGroupInfo = "InvalidGroupInfo.Provided GroupInfo is invalid or malformed"
                case invalidMaxMembers = "InvalidMaxMembers.maxMembers is less than current member count"
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
    // MARK: - updateConvo

    /// Update conversation settings (consolidates updatePolicy + promoteAdmin + demoteAdmin + promoteModerator + demoteModerator + updateGroupInfo + groupInfoRefresh) Perform administrative actions on a conversation. The 'action' field determines the operation. Most actions require admin privileges.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func updateConvo(
        
        input: BlueCatbirdMlsChatUpdateConvo.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatUpdateConvo.Output?) {
        let endpoint = "blue.catbird.mlsChat.updateConvo"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.updateConvo")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatUpdateConvo.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.updateConvo: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

