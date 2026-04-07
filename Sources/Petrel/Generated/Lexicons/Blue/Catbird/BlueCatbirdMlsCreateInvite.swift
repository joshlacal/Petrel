import Foundation



// lexicon: 1, id: blue.catbird.mls.createInvite


public struct BlueCatbirdMlsCreateInvite { 

    public static let typeIdentifier = "blue.catbird.mls.createInvite"
        
public struct InviteView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.createInvite#inviteView"
            public let inviteId: String
            public let convoId: String
            public let createdBy: DID
            public let createdAt: ATProtocolDate
            public let pskHash: String
            public let targetDid: DID?
            public let expiresAt: ATProtocolDate?
            public let maxUses: Int?
            public let useCount: Int
            public let isRevoked: Bool
            public let revokedAt: ATProtocolDate?
            public let revokedBy: DID?

        public init(
            inviteId: String, convoId: String, createdBy: DID, createdAt: ATProtocolDate, pskHash: String, targetDid: DID?, expiresAt: ATProtocolDate?, maxUses: Int?, useCount: Int, isRevoked: Bool, revokedAt: ATProtocolDate?, revokedBy: DID?
        ) {
            self.inviteId = inviteId
            self.convoId = convoId
            self.createdBy = createdBy
            self.createdAt = createdAt
            self.pskHash = pskHash
            self.targetDid = targetDid
            self.expiresAt = expiresAt
            self.maxUses = maxUses
            self.useCount = useCount
            self.isRevoked = isRevoked
            self.revokedAt = revokedAt
            self.revokedBy = revokedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.inviteId = try container.decode(String.self, forKey: .inviteId)
            } catch {
                LogManager.logError("Decoding error for required property 'inviteId': \(error)")
                throw error
            }
            do {
                self.convoId = try container.decode(String.self, forKey: .convoId)
            } catch {
                LogManager.logError("Decoding error for required property 'convoId': \(error)")
                throw error
            }
            do {
                self.createdBy = try container.decode(DID.self, forKey: .createdBy)
            } catch {
                LogManager.logError("Decoding error for required property 'createdBy': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.pskHash = try container.decode(String.self, forKey: .pskHash)
            } catch {
                LogManager.logError("Decoding error for required property 'pskHash': \(error)")
                throw error
            }
            do {
                self.targetDid = try container.decodeIfPresent(DID.self, forKey: .targetDid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'targetDid': \(error)")
                throw error
            }
            do {
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'expiresAt': \(error)")
                throw error
            }
            do {
                self.maxUses = try container.decodeIfPresent(Int.self, forKey: .maxUses)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'maxUses': \(error)")
                throw error
            }
            do {
                self.useCount = try container.decode(Int.self, forKey: .useCount)
            } catch {
                LogManager.logError("Decoding error for required property 'useCount': \(error)")
                throw error
            }
            do {
                self.isRevoked = try container.decode(Bool.self, forKey: .isRevoked)
            } catch {
                LogManager.logError("Decoding error for required property 'isRevoked': \(error)")
                throw error
            }
            do {
                self.revokedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .revokedAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'revokedAt': \(error)")
                throw error
            }
            do {
                self.revokedBy = try container.decodeIfPresent(DID.self, forKey: .revokedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'revokedBy': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(inviteId, forKey: .inviteId)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(createdBy, forKey: .createdBy)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(pskHash, forKey: .pskHash)
            try container.encodeIfPresent(targetDid, forKey: .targetDid)
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            try container.encodeIfPresent(maxUses, forKey: .maxUses)
            try container.encode(useCount, forKey: .useCount)
            try container.encode(isRevoked, forKey: .isRevoked)
            try container.encodeIfPresent(revokedAt, forKey: .revokedAt)
            try container.encodeIfPresent(revokedBy, forKey: .revokedBy)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(inviteId)
            hasher.combine(convoId)
            hasher.combine(createdBy)
            hasher.combine(createdAt)
            hasher.combine(pskHash)
            if let value = targetDid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = expiresAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = maxUses {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(useCount)
            hasher.combine(isRevoked)
            if let value = revokedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = revokedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if inviteId != other.inviteId {
                return false
            }
            if convoId != other.convoId {
                return false
            }
            if createdBy != other.createdBy {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if pskHash != other.pskHash {
                return false
            }
            if targetDid != other.targetDid {
                return false
            }
            if expiresAt != other.expiresAt {
                return false
            }
            if maxUses != other.maxUses {
                return false
            }
            if useCount != other.useCount {
                return false
            }
            if isRevoked != other.isRevoked {
                return false
            }
            if revokedAt != other.revokedAt {
                return false
            }
            if revokedBy != other.revokedBy {
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
            let inviteIdValue = try inviteId.toCBORValue()
            map = map.adding(key: "inviteId", value: inviteIdValue)
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let createdByValue = try createdBy.toCBORValue()
            map = map.adding(key: "createdBy", value: createdByValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            let pskHashValue = try pskHash.toCBORValue()
            map = map.adding(key: "pskHash", value: pskHashValue)
            if let value = targetDid {
                let targetDidValue = try value.toCBORValue()
                map = map.adding(key: "targetDid", value: targetDidValue)
            }
            if let value = expiresAt {
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            if let value = maxUses {
                let maxUsesValue = try value.toCBORValue()
                map = map.adding(key: "maxUses", value: maxUsesValue)
            }
            let useCountValue = try useCount.toCBORValue()
            map = map.adding(key: "useCount", value: useCountValue)
            let isRevokedValue = try isRevoked.toCBORValue()
            map = map.adding(key: "isRevoked", value: isRevokedValue)
            if let value = revokedAt {
                let revokedAtValue = try value.toCBORValue()
                map = map.adding(key: "revokedAt", value: revokedAtValue)
            }
            if let value = revokedBy {
                let revokedByValue = try value.toCBORValue()
                map = map.adding(key: "revokedBy", value: revokedByValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case inviteId
            case convoId
            case createdBy
            case createdAt
            case pskHash
            case targetDid
            case expiresAt
            case maxUses
            case useCount
            case isRevoked
            case revokedAt
            case revokedBy
        }
    }
public struct Input: ATProtocolCodable {
        public let convoId: String
        public let pskHash: String
        public let targetDid: DID?
        public let expiresAt: ATProtocolDate?
        public let maxUses: Int?

        /// Standard public initializer
        public init(convoId: String, pskHash: String, targetDid: DID? = nil, expiresAt: ATProtocolDate? = nil, maxUses: Int? = nil) {
            self.convoId = convoId
            self.pskHash = pskHash
            self.targetDid = targetDid
            self.expiresAt = expiresAt
            self.maxUses = maxUses
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.convoId = try container.decode(String.self, forKey: .convoId)
            self.pskHash = try container.decode(String.self, forKey: .pskHash)
            self.targetDid = try container.decodeIfPresent(DID.self, forKey: .targetDid)
            self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
            self.maxUses = try container.decodeIfPresent(Int.self, forKey: .maxUses)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(pskHash, forKey: .pskHash)
            try container.encodeIfPresent(targetDid, forKey: .targetDid)
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            try container.encodeIfPresent(maxUses, forKey: .maxUses)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let convoIdValue = try convoId.toCBORValue()
            map = map.adding(key: "convoId", value: convoIdValue)
            let pskHashValue = try pskHash.toCBORValue()
            map = map.adding(key: "pskHash", value: pskHashValue)
            if let value = targetDid {
                let targetDidValue = try value.toCBORValue()
                map = map.adding(key: "targetDid", value: targetDidValue)
            }
            if let value = expiresAt {
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            if let value = maxUses {
                let maxUsesValue = try value.toCBORValue()
                map = map.adding(key: "maxUses", value: maxUsesValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case convoId
            case pskHash
            case targetDid
            case expiresAt
            case maxUses
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let inviteId: String
        
        public let invite: InviteView
        
        
        
        // Standard public initializer
        public init(
            
            
            inviteId: String,
            
            invite: InviteView
            
            
        ) {
            
            
            self.inviteId = inviteId
            
            self.invite = invite
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.inviteId = try container.decode(String.self, forKey: .inviteId)
            
            
            self.invite = try container.decode(InviteView.self, forKey: .invite)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(inviteId, forKey: .inviteId)
            
            
            try container.encode(invite, forKey: .invite)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let inviteIdValue = try inviteId.toCBORValue()
            map = map.adding(key: "inviteId", value: inviteIdValue)
            
            
            
            let inviteValue = try invite.toCBORValue()
            map = map.adding(key: "invite", value: inviteValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case inviteId
            case invite
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case unauthorized = "Unauthorized.Caller is not an admin of this conversation"
                case invalidPSKHash = "InvalidPSKHash.PSK hash is invalid or malformed"
                case convoNotFound = "ConvoNotFound.Conversation not found"
                case notMember = "NotMember.Caller is not a member of this conversation"
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

extension ATProtoClient.Blue.Catbird.Mls {
    // MARK: - createInvite

    /// Create a new invite link for a conversation Create an invite link with optional PSK hash, expiration, and usage limits. Only admins can create invites.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func createInvite(
        
        input: BlueCatbirdMlsCreateInvite.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsCreateInvite.Output?) {
        let endpoint = "blue.catbird.mls.createInvite"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.createInvite")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsCreateInvite.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.createInvite: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

