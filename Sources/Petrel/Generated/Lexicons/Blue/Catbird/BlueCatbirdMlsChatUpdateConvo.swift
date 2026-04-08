import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.updateConvo


public struct BlueCatbirdMlsChatUpdateConvo { 

    public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo"
        
public struct PolicyInput: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo#policyInput"
            public let allowExternalCommits: Bool?
            public let requireInviteForJoin: Bool?
            public let allowRejoin: Bool?
            public let rejoinWindowDays: Int?
            public let preventRemovingLastAdmin: Bool?
            public let maxMembers: Int?

        public init(
            allowExternalCommits: Bool?, requireInviteForJoin: Bool?, allowRejoin: Bool?, rejoinWindowDays: Int?, preventRemovingLastAdmin: Bool?, maxMembers: Int?
        ) {
            self.allowExternalCommits = allowExternalCommits
            self.requireInviteForJoin = requireInviteForJoin
            self.allowRejoin = allowRejoin
            self.rejoinWindowDays = rejoinWindowDays
            self.preventRemovingLastAdmin = preventRemovingLastAdmin
            self.maxMembers = maxMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.allowExternalCommits = try container.decodeIfPresent(Bool.self, forKey: .allowExternalCommits)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowExternalCommits': \(error)")
                throw error
            }
            do {
                self.requireInviteForJoin = try container.decodeIfPresent(Bool.self, forKey: .requireInviteForJoin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requireInviteForJoin': \(error)")
                throw error
            }
            do {
                self.allowRejoin = try container.decodeIfPresent(Bool.self, forKey: .allowRejoin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowRejoin': \(error)")
                throw error
            }
            do {
                self.rejoinWindowDays = try container.decodeIfPresent(Int.self, forKey: .rejoinWindowDays)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'rejoinWindowDays': \(error)")
                throw error
            }
            do {
                self.preventRemovingLastAdmin = try container.decodeIfPresent(Bool.self, forKey: .preventRemovingLastAdmin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'preventRemovingLastAdmin': \(error)")
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
            try container.encodeIfPresent(allowExternalCommits, forKey: .allowExternalCommits)
            try container.encodeIfPresent(requireInviteForJoin, forKey: .requireInviteForJoin)
            try container.encodeIfPresent(allowRejoin, forKey: .allowRejoin)
            try container.encodeIfPresent(rejoinWindowDays, forKey: .rejoinWindowDays)
            try container.encodeIfPresent(preventRemovingLastAdmin, forKey: .preventRemovingLastAdmin)
            try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = allowExternalCommits {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = requireInviteForJoin {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowRejoin {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = rejoinWindowDays {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = preventRemovingLastAdmin {
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
            if allowExternalCommits != other.allowExternalCommits {
                return false
            }
            if requireInviteForJoin != other.requireInviteForJoin {
                return false
            }
            if allowRejoin != other.allowRejoin {
                return false
            }
            if rejoinWindowDays != other.rejoinWindowDays {
                return false
            }
            if preventRemovingLastAdmin != other.preventRemovingLastAdmin {
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
            if let value = allowExternalCommits {
                let allowExternalCommitsValue = try value.toCBORValue()
                map = map.adding(key: "allowExternalCommits", value: allowExternalCommitsValue)
            }
            if let value = requireInviteForJoin {
                let requireInviteForJoinValue = try value.toCBORValue()
                map = map.adding(key: "requireInviteForJoin", value: requireInviteForJoinValue)
            }
            if let value = allowRejoin {
                let allowRejoinValue = try value.toCBORValue()
                map = map.adding(key: "allowRejoin", value: allowRejoinValue)
            }
            if let value = rejoinWindowDays {
                let rejoinWindowDaysValue = try value.toCBORValue()
                map = map.adding(key: "rejoinWindowDays", value: rejoinWindowDaysValue)
            }
            if let value = preventRemovingLastAdmin {
                let preventRemovingLastAdminValue = try value.toCBORValue()
                map = map.adding(key: "preventRemovingLastAdmin", value: preventRemovingLastAdminValue)
            }
            if let value = maxMembers {
                let maxMembersValue = try value.toCBORValue()
                map = map.adding(key: "maxMembers", value: maxMembersValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowExternalCommits
            case requireInviteForJoin
            case allowRejoin
            case rejoinWindowDays
            case preventRemovingLastAdmin
            case maxMembers
        }
    }
        
public struct PolicyView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.updateConvo#policyView"
            public let allowExternalCommits: Bool?
            public let requireInviteForJoin: Bool?
            public let allowRejoin: Bool?
            public let rejoinWindowDays: Int?
            public let preventRemovingLastAdmin: Bool?
            public let maxMembers: Int?

        public init(
            allowExternalCommits: Bool?, requireInviteForJoin: Bool?, allowRejoin: Bool?, rejoinWindowDays: Int?, preventRemovingLastAdmin: Bool?, maxMembers: Int?
        ) {
            self.allowExternalCommits = allowExternalCommits
            self.requireInviteForJoin = requireInviteForJoin
            self.allowRejoin = allowRejoin
            self.rejoinWindowDays = rejoinWindowDays
            self.preventRemovingLastAdmin = preventRemovingLastAdmin
            self.maxMembers = maxMembers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.allowExternalCommits = try container.decodeIfPresent(Bool.self, forKey: .allowExternalCommits)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowExternalCommits': \(error)")
                throw error
            }
            do {
                self.requireInviteForJoin = try container.decodeIfPresent(Bool.self, forKey: .requireInviteForJoin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'requireInviteForJoin': \(error)")
                throw error
            }
            do {
                self.allowRejoin = try container.decodeIfPresent(Bool.self, forKey: .allowRejoin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'allowRejoin': \(error)")
                throw error
            }
            do {
                self.rejoinWindowDays = try container.decodeIfPresent(Int.self, forKey: .rejoinWindowDays)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'rejoinWindowDays': \(error)")
                throw error
            }
            do {
                self.preventRemovingLastAdmin = try container.decodeIfPresent(Bool.self, forKey: .preventRemovingLastAdmin)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'preventRemovingLastAdmin': \(error)")
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
            try container.encodeIfPresent(allowExternalCommits, forKey: .allowExternalCommits)
            try container.encodeIfPresent(requireInviteForJoin, forKey: .requireInviteForJoin)
            try container.encodeIfPresent(allowRejoin, forKey: .allowRejoin)
            try container.encodeIfPresent(rejoinWindowDays, forKey: .rejoinWindowDays)
            try container.encodeIfPresent(preventRemovingLastAdmin, forKey: .preventRemovingLastAdmin)
            try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = allowExternalCommits {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = requireInviteForJoin {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = allowRejoin {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = rejoinWindowDays {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = preventRemovingLastAdmin {
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
            if allowExternalCommits != other.allowExternalCommits {
                return false
            }
            if requireInviteForJoin != other.requireInviteForJoin {
                return false
            }
            if allowRejoin != other.allowRejoin {
                return false
            }
            if rejoinWindowDays != other.rejoinWindowDays {
                return false
            }
            if preventRemovingLastAdmin != other.preventRemovingLastAdmin {
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
            if let value = allowExternalCommits {
                let allowExternalCommitsValue = try value.toCBORValue()
                map = map.adding(key: "allowExternalCommits", value: allowExternalCommitsValue)
            }
            if let value = requireInviteForJoin {
                let requireInviteForJoinValue = try value.toCBORValue()
                map = map.adding(key: "requireInviteForJoin", value: requireInviteForJoinValue)
            }
            if let value = allowRejoin {
                let allowRejoinValue = try value.toCBORValue()
                map = map.adding(key: "allowRejoin", value: allowRejoinValue)
            }
            if let value = rejoinWindowDays {
                let rejoinWindowDaysValue = try value.toCBORValue()
                map = map.adding(key: "rejoinWindowDays", value: rejoinWindowDaysValue)
            }
            if let value = preventRemovingLastAdmin {
                let preventRemovingLastAdminValue = try value.toCBORValue()
                map = map.adding(key: "preventRemovingLastAdmin", value: preventRemovingLastAdminValue)
            }
            if let value = maxMembers {
                let maxMembersValue = try value.toCBORValue()
                map = map.adding(key: "maxMembers", value: maxMembersValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowExternalCommits
            case requireInviteForJoin
            case allowRejoin
            case rejoinWindowDays
            case preventRemovingLastAdmin
            case maxMembers
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
                case invalidRequest = "InvalidRequest.Invalid request parameters"
                case unauthorized = "Unauthorized.Authentication required"
                case forbidden = "Forbidden.User does not have permission for this action"
                case notFound = "NotFound.Conversation not found"
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

    /// Update conversation settings including admin/moderator management, policy, and group info
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
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: requestData,
            queryItems: nil
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
                           

