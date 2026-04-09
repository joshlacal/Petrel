import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.getKeyPackageStatus


public struct BlueCatbirdMlsChatGetKeyPackageStatus { 

    public static let typeIdentifier = "blue.catbird.mlsChat.getKeyPackageStatus"
        
public struct KeyPackageStats: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.getKeyPackageStatus#keyPackageStats"
            public let totalAvailable: Int
            public let totalConsumed: Int
            public let byDevice: [DeviceKeyPackageCount]?

        public init(
            totalAvailable: Int, totalConsumed: Int, byDevice: [DeviceKeyPackageCount]?
        ) {
            self.totalAvailable = totalAvailable
            self.totalConsumed = totalConsumed
            self.byDevice = byDevice
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.totalAvailable = try container.decode(Int.self, forKey: .totalAvailable)
            } catch {
                LogManager.logError("Decoding error for required property 'totalAvailable': \(error)")
                throw error
            }
            do {
                self.totalConsumed = try container.decode(Int.self, forKey: .totalConsumed)
            } catch {
                LogManager.logError("Decoding error for required property 'totalConsumed': \(error)")
                throw error
            }
            do {
                self.byDevice = try container.decodeIfPresent([DeviceKeyPackageCount].self, forKey: .byDevice)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'byDevice': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(totalAvailable, forKey: .totalAvailable)
            try container.encode(totalConsumed, forKey: .totalConsumed)
            try container.encodeIfPresent(byDevice, forKey: .byDevice)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(totalAvailable)
            hasher.combine(totalConsumed)
            if let value = byDevice {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if totalAvailable != other.totalAvailable {
                return false
            }
            if totalConsumed != other.totalConsumed {
                return false
            }
            if byDevice != other.byDevice {
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
            let totalAvailableValue = try totalAvailable.toCBORValue()
            map = map.adding(key: "totalAvailable", value: totalAvailableValue)
            let totalConsumedValue = try totalConsumed.toCBORValue()
            map = map.adding(key: "totalConsumed", value: totalConsumedValue)
            if let value = byDevice {
                let byDeviceValue = try value.toCBORValue()
                map = map.adding(key: "byDevice", value: byDeviceValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case totalAvailable
            case totalConsumed
            case byDevice
        }
    }
        
public struct DeviceKeyPackageCount: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.getKeyPackageStatus#deviceKeyPackageCount"
            public let deviceId: String
            public let available: Int

        public init(
            deviceId: String, available: Int
        ) {
            self.deviceId = deviceId
            self.available = available
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                self.available = try container.decode(Int.self, forKey: .available)
            } catch {
                LogManager.logError("Decoding error for required property 'available': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(available, forKey: .available)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(deviceId)
            hasher.combine(available)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if deviceId != other.deviceId {
                return false
            }
            if available != other.available {
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
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case deviceId
            case available
        }
    }
        
public struct KeyPackageStatusItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.getKeyPackageStatus#keyPackageStatusItem"
            public let id: String
            public let deviceId: String
            public let cipherSuite: String
            public let createdAt: ATProtocolDate
            public let expiresAt: ATProtocolDate?
            public let consumed: Bool

        public init(
            id: String, deviceId: String, cipherSuite: String, createdAt: ATProtocolDate, expiresAt: ATProtocolDate?, consumed: Bool
        ) {
            self.id = id
            self.deviceId = deviceId
            self.cipherSuite = cipherSuite
            self.createdAt = createdAt
            self.expiresAt = expiresAt
            self.consumed = consumed
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
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
            do {
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'expiresAt': \(error)")
                throw error
            }
            do {
                self.consumed = try container.decode(Bool.self, forKey: .consumed)
            } catch {
                LogManager.logError("Decoding error for required property 'consumed': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(deviceId, forKey: .deviceId)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            try container.encode(consumed, forKey: .consumed)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(deviceId)
            hasher.combine(cipherSuite)
            hasher.combine(createdAt)
            if let value = expiresAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(consumed)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if id != other.id {
                return false
            }
            if deviceId != other.deviceId {
                return false
            }
            if cipherSuite != other.cipherSuite {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if expiresAt != other.expiresAt {
                return false
            }
            if consumed != other.consumed {
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
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = expiresAt {
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            let consumedValue = try consumed.toCBORValue()
            map = map.adding(key: "consumed", value: consumedValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case deviceId
            case cipherSuite
            case createdAt
            case expiresAt
            case consumed
        }
    }
        
public struct KeyPackageHistoryItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.getKeyPackageStatus#keyPackageHistoryItem"
            public let id: String
            public let action: String
            public let createdAt: ATProtocolDate
            public let consumedByDid: DID?

        public init(
            id: String, action: String, createdAt: ATProtocolDate, consumedByDid: DID?
        ) {
            self.id = id
            self.action = action
            self.createdAt = createdAt
            self.consumedByDid = consumedByDid
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
                self.action = try container.decode(String.self, forKey: .action)
            } catch {
                LogManager.logError("Decoding error for required property 'action': \(error)")
                throw error
            }
            do {
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                throw error
            }
            do {
                self.consumedByDid = try container.decodeIfPresent(DID.self, forKey: .consumedByDid)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'consumedByDid': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(id, forKey: .id)
            try container.encode(action, forKey: .action)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(consumedByDid, forKey: .consumedByDid)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(action)
            hasher.combine(createdAt)
            if let value = consumedByDid {
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
            if action != other.action {
                return false
            }
            if createdAt != other.createdAt {
                return false
            }
            if consumedByDid != other.consumedByDid {
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
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            if let value = consumedByDid {
                let consumedByDidValue = try value.toCBORValue()
                map = map.adding(key: "consumedByDid", value: consumedByDidValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case action
            case createdAt
            case consumedByDid
        }
    }    
public struct Parameters: Parametrizable {
        public let did: DID?
        public let cipherSuite: String?
        public let include: String?
        public let limit: Int?
        public let cursor: String?
        
        public init(
            did: DID? = nil, 
            cipherSuite: String? = nil, 
            include: String? = nil, 
            limit: Int? = nil, 
            cursor: String? = nil
            ) {
            self.did = did
            self.cipherSuite = cipherSuite
            self.include = include
            self.limit = limit
            self.cursor = cursor
            
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let stats: KeyPackageStats?
        
        public let status: [KeyPackageStatusItem]?
        
        public let history: [KeyPackageHistoryItem]?
        
        public let cursor: String?
        
        
        
        // Standard public initializer
        public init(
            
            
            stats: KeyPackageStats? = nil,
            
            status: [KeyPackageStatusItem]? = nil,
            
            history: [KeyPackageHistoryItem]? = nil,
            
            cursor: String? = nil
            
            
        ) {
            
            
            self.stats = stats
            
            self.status = status
            
            self.history = history
            
            self.cursor = cursor
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.stats = try container.decodeIfPresent(KeyPackageStats.self, forKey: .stats)
            
            
            self.status = try container.decodeIfPresent([KeyPackageStatusItem].self, forKey: .status)
            
            
            self.history = try container.decodeIfPresent([KeyPackageHistoryItem].self, forKey: .history)
            
            
            self.cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(stats, forKey: .stats)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(history, forKey: .history)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cursor, forKey: .cursor)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            if let value = stats {
                // Encode optional property even if it's an empty array for CBOR
                let statsValue = try value.toCBORValue()
                map = map.adding(key: "stats", value: statsValue)
            }
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            
            if let value = history {
                // Encode optional property even if it's an empty array for CBOR
                let historyValue = try value.toCBORValue()
                map = map.adding(key: "history", value: historyValue)
            }
            
            
            
            if let value = cursor {
                // Encode optional property even if it's an empty array for CBOR
                let cursorValue = try value.toCBORValue()
                map = map.adding(key: "cursor", value: cursorValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case stats
            case status
            case history
            case cursor
        }
        
    }




}



extension ATProtoClient.Blue.Catbird.MlsChat {
    // MARK: - getKeyPackageStatus

    /// Get key package statistics and status for the authenticated user's devices Retrieve key package counts, status, and history for the authenticated user. Useful for clients to know when to replenish key packages.
    /// 
    /// - Parameter input: The input parameters for the request
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func getKeyPackageStatus(input: BlueCatbirdMlsChatGetKeyPackageStatus.Parameters) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatGetKeyPackageStatus.Output?) {
        let endpoint = "blue.catbird.mlsChat.getKeyPackageStatus"

        
        let queryItems = input.asQueryItems()
        
        let urlRequest = try await networkService.createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: ["Accept": "application/json"],
            body: nil,
            queryItems: queryItems
        )

        // Determine service DID for this endpoint
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.getKeyPackageStatus")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatGetKeyPackageStatus.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.getKeyPackageStatus: \(error)")
                return (responseCode, nil)
            }
        } else {
            
            // If we can't parse a structured error, return the response code
            // (maintains backward compatibility for endpoints without defined errors)
            return (responseCode, nil)
        }
    }
}
                           

