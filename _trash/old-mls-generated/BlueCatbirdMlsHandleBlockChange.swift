import Foundation



// lexicon: 1, id: blue.catbird.mls.handleBlockChange


public struct BlueCatbirdMlsHandleBlockChange { 

    public static let typeIdentifier = "blue.catbird.mls.handleBlockChange"
        
public struct AffectedConvo: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mls.handleBlockChange#affectedConvo"
            public let convoId: String
            public let action: String
            public let adminNotified: Bool
            public let notificationSentAt: ATProtocolDate?

        public init(
            convoId: String, action: String, adminNotified: Bool, notificationSentAt: ATProtocolDate?
        ) {
            self.convoId = convoId
            self.action = action
            self.adminNotified = adminNotified
            self.notificationSentAt = notificationSentAt
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
                self.adminNotified = try container.decode(Bool.self, forKey: .adminNotified)
            } catch {
                LogManager.logError("Decoding error for required property 'adminNotified': \(error)")
                throw error
            }
            do {
                self.notificationSentAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .notificationSentAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'notificationSentAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(action, forKey: .action)
            try container.encode(adminNotified, forKey: .adminNotified)
            try container.encodeIfPresent(notificationSentAt, forKey: .notificationSentAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(action)
            hasher.combine(adminNotified)
            if let value = notificationSentAt {
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
            if adminNotified != other.adminNotified {
                return false
            }
            if notificationSentAt != other.notificationSentAt {
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
            let adminNotifiedValue = try adminNotified.toCBORValue()
            map = map.adding(key: "adminNotified", value: adminNotifiedValue)
            if let value = notificationSentAt {
                let notificationSentAtValue = try value.toCBORValue()
                map = map.adding(key: "notificationSentAt", value: notificationSentAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case action
            case adminNotified
            case notificationSentAt
        }
    }
public struct Input: ATProtocolCodable {
        public let blockerDid: DID
        public let blockedDid: DID
        public let action: String
        public let blockUri: ATProtocolURI?

        /// Standard public initializer
        public init(blockerDid: DID, blockedDid: DID, action: String, blockUri: ATProtocolURI? = nil) {
            self.blockerDid = blockerDid
            self.blockedDid = blockedDid
            self.action = action
            self.blockUri = blockUri
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.blockerDid = try container.decode(DID.self, forKey: .blockerDid)
            self.blockedDid = try container.decode(DID.self, forKey: .blockedDid)
            self.action = try container.decode(String.self, forKey: .action)
            self.blockUri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blockUri)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(blockerDid, forKey: .blockerDid)
            try container.encode(blockedDid, forKey: .blockedDid)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(blockUri, forKey: .blockUri)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let blockerDidValue = try blockerDid.toCBORValue()
            map = map.adding(key: "blockerDid", value: blockerDidValue)
            let blockedDidValue = try blockedDid.toCBORValue()
            map = map.adding(key: "blockedDid", value: blockedDidValue)
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = blockUri {
                let blockUriValue = try value.toCBORValue()
                map = map.adding(key: "blockUri", value: blockUriValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case blockerDid
            case blockedDid
            case action
            case blockUri
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let affectedConvos: [AffectedConvo]
        
        
        
        // Standard public initializer
        public init(
            
            
            affectedConvos: [AffectedConvo]
            
            
        ) {
            
            
            self.affectedConvos = affectedConvos
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.affectedConvos = try container.decode([AffectedConvo].self, forKey: .affectedConvos)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(affectedConvos, forKey: .affectedConvos)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let affectedConvosValue = try affectedConvos.toCBORValue()
            map = map.adding(key: "affectedConvos", value: affectedConvosValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case affectedConvos
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case blockNotVerified = "BlockNotVerified.Could not verify block status with Bluesky"
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
    // MARK: - handleBlockChange

    /// Notify server of Bluesky block change affecting conversation membership Client notifies server when a Bluesky block is created or removed that affects MLS conversations. Server checks if both users are in any conversations together and notifies admins of conflicts. Enables reactive moderation when blocks occur after users have already joined conversations.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func handleBlockChange(
        
        input: BlueCatbirdMlsHandleBlockChange.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsHandleBlockChange.Output?) {
        let endpoint = "blue.catbird.mls.handleBlockChange"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mls.handleBlockChange")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsHandleBlockChange.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mls.handleBlockChange: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

