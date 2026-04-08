import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getPendingDevices


public struct BlueCatbirdMlsChatGetPendingDevices { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getPendingDevices"
        
public struct PendingDeviceAddition: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.getPendingDevices#pendingDeviceAddition"
            public let convoId: String
            public let deviceId: String
            public let createdAt: ATProtocolDate
            public let welcome: Bytes?

        public init(
            convoId: String, deviceId: String, createdAt: ATProtocolDate, welcome: Bytes?
        ) {
            self.convoId = convoId
            self.deviceId = deviceId
            self.createdAt = createdAt
            self.welcome = welcome
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
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.welcome = try container.decodeIfPresent(Bytes.self, forKey: .welcome)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'welcome': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(convoId, forKey: .convoId)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(welcome, forKey: .welcome)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(convoId)
            hasher.combine(deviceId)
            hasher.combine(createdAt)
            if let value = welcome {
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
            if deviceId != other.deviceId {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if welcome != other.welcome {
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
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = welcome {
                let welcomeValue = try value.toCBORValue()
                map = map.adding(key: "welcome", value: welcomeValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case convoId
            case deviceId
            case createdAt
            case welcome
        }
    }    
public struct Parameters: Parametrizable {
        public let convoIds: [String]?
        public let limit: Int?
        
        public init(
            convoIds: [String]? = nil, 
            limit: Int? = nil
            ) {
            self.convoIds = convoIds
            self.limit = limit
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let pendingAdditions: [PendingDeviceAddition]
        
        
        
        // Standard public initializer
        public init(
            
            
            pendingAdditions: [PendingDeviceAddition]
            
            
        ) {
            
            
            self.pendingAdditions = pendingAdditions
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.pendingAdditions = try container.decode([PendingDeviceAddition].self, forKey: .pendingAdditions)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(pendingAdditions, forKey: .pendingAdditions)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let pendingAdditionsValue = try pendingAdditions.toCBORValue()
            map = map.adding(key: "pendingAdditions", value: pendingAdditionsValue)
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case pendingAdditions
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getPendingDevices

    /// Get pending device additions for the authenticated user List pending device additions — conversations that a newly registered device should join via Welcome messages.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getPendingDevices(input: BlueCatbirdMlsChatGetPendingDevices.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetPendingDevices.Output?) {
        let endpoint = "blue.catbird.mlsChat.getPendingDevices"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getPendingDevices")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetPendingDevices.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getPendingDevices: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

