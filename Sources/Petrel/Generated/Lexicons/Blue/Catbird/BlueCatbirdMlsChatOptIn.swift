import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.optIn


public struct BlueCatbirdMlsChatOptIn { 

    public static let typeIdentifier = "blue.catbird.mlsChat.optIn"
        
public struct OptInStatus: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.optIn#optInStatus"
            public let did: DID
            public let optedIn: Bool
            public let optedInAt: ATProtocolDate?

        public init(
            did: DID, optedIn: Bool, optedInAt: ATProtocolDate?
        ) {
            self.did = did
            self.optedIn = optedIn
            self.optedInAt = optedInAt
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
                self.optedIn = try container.decode(Bool.self, forKey: .optedIn)
            } catch {
                LogManager.logError("Decoding error for required property 'optedIn': \(error)")
                throw error
            }
            do {
                self.optedInAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .optedInAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'optedInAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(optedIn, forKey: .optedIn)
            try container.encodeIfPresent(optedInAt, forKey: .optedInAt)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(optedIn)
            if let value = optedInAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if did != other.did {
                return false
            }
            if optedIn != other.optedIn {
                return false
            }
            if optedInAt != other.optedInAt {
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
            let optedInValue = try optedIn.toCBORValue()
            map = map.adding(key: "optedIn", value: optedInValue)
            if let value = optedInAt {
                let optedInAtValue = try value.toCBORValue()
                map = map.adding(key: "optedInAt", value: optedInAtValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case optedIn
            case optedInAt
        }
    }
public struct Input: ATProtocolCodable {
        public let action: String
        public let dids: [DID]?
        public let deviceId: String?
        public let allowFollowersBypass: Bool?
        public let allowFollowingBypass: Bool?
        public let autoExpireDays: Int?

        /// Standard public initializer
        public init(action: String, dids: [DID]? = nil, deviceId: String? = nil, allowFollowersBypass: Bool? = nil, allowFollowingBypass: Bool? = nil, autoExpireDays: Int? = nil) {
            self.action = action
            self.dids = dids
            self.deviceId = deviceId
            self.allowFollowersBypass = allowFollowersBypass
            self.allowFollowingBypass = allowFollowingBypass
            self.autoExpireDays = autoExpireDays
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.action = try container.decode(String.self, forKey: .action)
            self.dids = try container.decodeIfPresent([DID].self, forKey: .dids)
            self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            self.allowFollowersBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowersBypass)
            self.allowFollowingBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowingBypass)
            self.autoExpireDays = try container.decodeIfPresent(Int.self, forKey: .autoExpireDays)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(dids, forKey: .dids)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(allowFollowersBypass, forKey: .allowFollowersBypass)
            try container.encodeIfPresent(allowFollowingBypass, forKey: .allowFollowingBypass)
            try container.encodeIfPresent(autoExpireDays, forKey: .autoExpireDays)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = dids {
                let didsValue = try value.toCBORValue()
                map = map.adding(key: "dids", value: didsValue)
            }
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            if let value = allowFollowersBypass {
                let allowFollowersBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)
            }
            if let value = allowFollowingBypass {
                let allowFollowingBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)
            }
            if let value = autoExpireDays {
                let autoExpireDaysValue = try value.toCBORValue()
                map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case action
            case dids
            case deviceId
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let success: Bool?
        
        public let optedIn: Bool?
        
        public let optedInAt: ATProtocolDate?
        
        public let statuses: [OptInStatus]?
        
        public let allowFollowersBypass: Bool?
        
        public let allowFollowingBypass: Bool?
        
        public let autoExpireDays: Int?
        
        
        
        // Standard public initializer
        public init(
            
            
            success: Bool? = nil,
            
            optedIn: Bool? = nil,
            
            optedInAt: ATProtocolDate? = nil,
            
            statuses: [OptInStatus]? = nil,
            
            allowFollowersBypass: Bool? = nil,
            
            allowFollowingBypass: Bool? = nil,
            
            autoExpireDays: Int? = nil
            
            
        ) {
            
            
            self.success = success
            
            self.optedIn = optedIn
            
            self.optedInAt = optedInAt
            
            self.statuses = statuses
            
            self.allowFollowersBypass = allowFollowersBypass
            
            self.allowFollowingBypass = allowFollowingBypass
            
            self.autoExpireDays = autoExpireDays
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.success = try container.decodeIfPresent(Bool.self, forKey: .success)
            
            
            self.optedIn = try container.decodeIfPresent(Bool.self, forKey: .optedIn)
            
            
            self.optedInAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .optedInAt)
            
            
            self.statuses = try container.decodeIfPresent([OptInStatus].self, forKey: .statuses)
            
            
            self.allowFollowersBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowersBypass)
            
            
            self.allowFollowingBypass = try container.decodeIfPresent(Bool.self, forKey: .allowFollowingBypass)
            
            
            self.autoExpireDays = try container.decodeIfPresent(Int.self, forKey: .autoExpireDays)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(success, forKey: .success)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(optedIn, forKey: .optedIn)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(optedInAt, forKey: .optedInAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(statuses, forKey: .statuses)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowFollowersBypass, forKey: .allowFollowersBypass)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(allowFollowingBypass, forKey: .allowFollowingBypass)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(autoExpireDays, forKey: .autoExpireDays)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = success {
                // Encode optional property even if it's an empty array for CBOR
                let successValue = try value.toCBORValue()
                map = map.adding(key: "success", value: successValue)
            }
            
            
            
            if let value = optedIn {
                // Encode optional property even if it's an empty array for CBOR
                let optedInValue = try value.toCBORValue()
                map = map.adding(key: "optedIn", value: optedInValue)
            }
            
            
            
            if let value = optedInAt {
                // Encode optional property even if it's an empty array for CBOR
                let optedInAtValue = try value.toCBORValue()
                map = map.adding(key: "optedInAt", value: optedInAtValue)
            }
            
            
            
            if let value = statuses {
                // Encode optional property even if it's an empty array for CBOR
                let statusesValue = try value.toCBORValue()
                map = map.adding(key: "statuses", value: statusesValue)
            }
            
            
            
            if let value = allowFollowersBypass {
                // Encode optional property even if it's an empty array for CBOR
                let allowFollowersBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowersBypass", value: allowFollowersBypassValue)
            }
            
            
            
            if let value = allowFollowingBypass {
                // Encode optional property even if it's an empty array for CBOR
                let allowFollowingBypassValue = try value.toCBORValue()
                map = map.adding(key: "allowFollowingBypass", value: allowFollowingBypassValue)
            }
            
            
            
            if let value = autoExpireDays {
                // Encode optional property even if it's an empty array for CBOR
                let autoExpireDaysValue = try value.toCBORValue()
                map = map.adding(key: "autoExpireDays", value: autoExpireDaysValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case success
            case optedIn
            case optedInAt
            case statuses
            case allowFollowersBypass
            case allowFollowingBypass
            case autoExpireDays
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidAction = "InvalidAction.Unknown action value"
                case alreadyOptedIn = "AlreadyOptedIn.User is already opted in"
                case alreadyOptedOut = "AlreadyOptedOut.User is already opted out"
                case tooManyDids = "TooManyDids.Too many DIDs requested (max 100)"
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
    // MARK: - optIn

    /// Manage MLS chat opt-in status (consolidates optIn + optOut + getOptInStatus + getChatRequestSettings + updateChatRequestSettings + acceptChatRequest + declineChatRequest + sendChatRequest) Manage MLS chat participation. Supports opting in/out, checking status for multiple DIDs, and managing chat request settings.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func optIn(
        
        input: BlueCatbirdMlsChatOptIn.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatOptIn.Output?) {
        let endpoint = "blue.catbird.mlsChat.optIn"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.optIn")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatOptIn.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.optIn: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

