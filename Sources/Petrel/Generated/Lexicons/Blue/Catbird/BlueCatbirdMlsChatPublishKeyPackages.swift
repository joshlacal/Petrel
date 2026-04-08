import Foundation



// lexicon: 1, id: blue.catbird.mlsChat.publishKeyPackages


public struct BlueCatbirdMlsChatPublishKeyPackages { 

    public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages"
        
public struct KeyPackageItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#keyPackageItem"
            public let keyPackage: Bytes
            public let cipherSuite: String
            public let expires: ATProtocolDate

        public init(
            keyPackage: Bytes, cipherSuite: String, expires: ATProtocolDate
        ) {
            self.keyPackage = keyPackage
            self.cipherSuite = cipherSuite
            self.expires = expires
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.keyPackage = try container.decode(Bytes.self, forKey: .keyPackage)
            } catch {
                LogManager.logError("Decoding error for required property 'keyPackage': \(error)")
                throw error
            }
            do {
                self.cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
            do {
                self.expires = try container.decode(ATProtocolDate.self, forKey: .expires)
            } catch {
                LogManager.logError("Decoding error for required property 'expires': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(keyPackage, forKey: .keyPackage)
            try container.encode(cipherSuite, forKey: .cipherSuite)
            try container.encode(expires, forKey: .expires)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(keyPackage)
            hasher.combine(cipherSuite)
            hasher.combine(expires)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if keyPackage != other.keyPackage {
                return false
            }
            if cipherSuite != other.cipherSuite {
                return false
            }
            if expires != other.expires {
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
            let keyPackageValue = try keyPackage.toCBORValue()
            map = map.adding(key: "keyPackage", value: keyPackageValue)
            let cipherSuiteValue = try cipherSuite.toCBORValue()
            map = map.adding(key: "cipherSuite", value: cipherSuiteValue)
            let expiresValue = try expires.toCBORValue()
            map = map.adding(key: "expires", value: expiresValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case keyPackage
            case cipherSuite
            case expires
        }
    }
        
public struct KeyPackageStats: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#keyPackageStats"
            public let published: Int
            public let available: Int
            public let expired: Int

        public init(
            published: Int, available: Int, expired: Int
        ) {
            self.published = published
            self.available = available
            self.expired = expired
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.published = try container.decode(Int.self, forKey: .published)
            } catch {
                LogManager.logError("Decoding error for required property 'published': \(error)")
                throw error
            }
            do {
                self.available = try container.decode(Int.self, forKey: .available)
            } catch {
                LogManager.logError("Decoding error for required property 'available': \(error)")
                throw error
            }
            do {
                self.expired = try container.decode(Int.self, forKey: .expired)
            } catch {
                LogManager.logError("Decoding error for required property 'expired': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(published, forKey: .published)
            try container.encode(available, forKey: .available)
            try container.encode(expired, forKey: .expired)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(published)
            hasher.combine(available)
            hasher.combine(expired)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if published != other.published {
                return false
            }
            if available != other.available {
                return false
            }
            if expired != other.expired {
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
            let publishedValue = try published.toCBORValue()
            map = map.adding(key: "published", value: publishedValue)
            let availableValue = try available.toCBORValue()
            map = map.adding(key: "available", value: availableValue)
            let expiredValue = try expired.toCBORValue()
            map = map.adding(key: "expired", value: expiredValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case published
            case available
            case expired
        }
    }
        
public struct SyncResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#syncResult"
            public let serverHashes: [String]
            public let orphanedCount: Int
            public let orphanedHashes: [String]?
            public let deletedCount: Int
            public let remainingAvailable: Int?
            public let deviceId: String

        public init(
            serverHashes: [String], orphanedCount: Int, orphanedHashes: [String]?, deletedCount: Int, remainingAvailable: Int?, deviceId: String
        ) {
            self.serverHashes = serverHashes
            self.orphanedCount = orphanedCount
            self.orphanedHashes = orphanedHashes
            self.deletedCount = deletedCount
            self.remainingAvailable = remainingAvailable
            self.deviceId = deviceId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.serverHashes = try container.decode([String].self, forKey: .serverHashes)
            } catch {
                LogManager.logError("Decoding error for required property 'serverHashes': \(error)")
                throw error
            }
            do {
                self.orphanedCount = try container.decode(Int.self, forKey: .orphanedCount)
            } catch {
                LogManager.logError("Decoding error for required property 'orphanedCount': \(error)")
                throw error
            }
            do {
                self.orphanedHashes = try container.decodeIfPresent([String].self, forKey: .orphanedHashes)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'orphanedHashes': \(error)")
                throw error
            }
            do {
                self.deletedCount = try container.decode(Int.self, forKey: .deletedCount)
            } catch {
                LogManager.logError("Decoding error for required property 'deletedCount': \(error)")
                throw error
            }
            do {
                self.remainingAvailable = try container.decodeIfPresent(Int.self, forKey: .remainingAvailable)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'remainingAvailable': \(error)")
                throw error
            }
            do {
                self.deviceId = try container.decode(String.self, forKey: .deviceId)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceId': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(serverHashes, forKey: .serverHashes)
            try container.encode(orphanedCount, forKey: .orphanedCount)
            try container.encodeIfPresent(orphanedHashes, forKey: .orphanedHashes)
            try container.encode(deletedCount, forKey: .deletedCount)
            try container.encodeIfPresent(remainingAvailable, forKey: .remainingAvailable)
            try container.encode(deviceId, forKey: .deviceId)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(serverHashes)
            hasher.combine(orphanedCount)
            if let value = orphanedHashes {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(deletedCount)
            if let value = remainingAvailable {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(deviceId)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if serverHashes != other.serverHashes {
                return false
            }
            if orphanedCount != other.orphanedCount {
                return false
            }
            if orphanedHashes != other.orphanedHashes {
                return false
            }
            if deletedCount != other.deletedCount {
                return false
            }
            if remainingAvailable != other.remainingAvailable {
                return false
            }
            if deviceId != other.deviceId {
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
            let serverHashesValue = try serverHashes.toCBORValue()
            map = map.adding(key: "serverHashes", value: serverHashesValue)
            let orphanedCountValue = try orphanedCount.toCBORValue()
            map = map.adding(key: "orphanedCount", value: orphanedCountValue)
            if let value = orphanedHashes {
                let orphanedHashesValue = try value.toCBORValue()
                map = map.adding(key: "orphanedHashes", value: orphanedHashesValue)
            }
            let deletedCountValue = try deletedCount.toCBORValue()
            map = map.adding(key: "deletedCount", value: deletedCountValue)
            if let value = remainingAvailable {
                let remainingAvailableValue = try value.toCBORValue()
                map = map.adding(key: "remainingAvailable", value: remainingAvailableValue)
            }
            let deviceIdValue = try deviceId.toCBORValue()
            map = map.adding(key: "deviceId", value: deviceIdValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case serverHashes
            case orphanedCount
            case orphanedHashes
            case deletedCount
            case remainingAvailable
            case deviceId
        }
    }
        
public struct PublishResult: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#publishResult"
            public let succeeded: Int
            public let failed: Int
            public let errors: [BatchError]?

        public init(
            succeeded: Int, failed: Int, errors: [BatchError]?
        ) {
            self.succeeded = succeeded
            self.failed = failed
            self.errors = errors
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.succeeded = try container.decode(Int.self, forKey: .succeeded)
            } catch {
                LogManager.logError("Decoding error for required property 'succeeded': \(error)")
                throw error
            }
            do {
                self.failed = try container.decode(Int.self, forKey: .failed)
            } catch {
                LogManager.logError("Decoding error for required property 'failed': \(error)")
                throw error
            }
            do {
                self.errors = try container.decodeIfPresent([BatchError].self, forKey: .errors)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'errors': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(succeeded, forKey: .succeeded)
            try container.encode(failed, forKey: .failed)
            try container.encodeIfPresent(errors, forKey: .errors)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(succeeded)
            hasher.combine(failed)
            if let value = errors {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if succeeded != other.succeeded {
                return false
            }
            if failed != other.failed {
                return false
            }
            if errors != other.errors {
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
            let succeededValue = try succeeded.toCBORValue()
            map = map.adding(key: "succeeded", value: succeededValue)
            let failedValue = try failed.toCBORValue()
            map = map.adding(key: "failed", value: failedValue)
            if let value = errors {
                let errorsValue = try value.toCBORValue()
                map = map.adding(key: "errors", value: errorsValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case succeeded
            case failed
            case errors
        }
    }
        
public struct BatchError: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#batchError"
            public let index: Int
            public let error: String

        public init(
            index: Int, error: String
        ) {
            self.index = index
            self.error = error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.index = try container.decode(Int.self, forKey: .index)
            } catch {
                LogManager.logError("Decoding error for required property 'index': \(error)")
                throw error
            }
            do {
                self.error = try container.decode(String.self, forKey: .error)
            } catch {
                LogManager.logError("Decoding error for required property 'error': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(index, forKey: .index)
            try container.encode(error, forKey: .error)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(index)
            hasher.combine(error)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if index != other.index {
                return false
            }
            if error != other.error {
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
            let indexValue = try index.toCBORValue()
            map = map.adding(key: "index", value: indexValue)
            let errorValue = try error.toCBORValue()
            map = map.adding(key: "error", value: errorValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case index
            case error
        }
    }
public struct Input: ATProtocolCodable {
        public let action: String
        public let keyPackages: [KeyPackageItem]?
        public let localHashes: [String]?
        public let deviceId: String?

        /// Standard public initializer
        public init(action: String, keyPackages: [KeyPackageItem]? = nil, localHashes: [String]? = nil, deviceId: String? = nil) {
            self.action = action
            self.keyPackages = keyPackages
            self.localHashes = localHashes
            self.deviceId = deviceId
        }
        

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.action = try container.decode(String.self, forKey: .action)
            self.keyPackages = try container.decodeIfPresent([KeyPackageItem].self, forKey: .keyPackages)
            self.localHashes = try container.decodeIfPresent([String].self, forKey: .localHashes)
            self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(keyPackages, forKey: .keyPackages)
            try container.encodeIfPresent(localHashes, forKey: .localHashes)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            let actionValue = try action.toCBORValue()
            map = map.adding(key: "action", value: actionValue)
            if let value = keyPackages {
                let keyPackagesValue = try value.toCBORValue()
                map = map.adding(key: "keyPackages", value: keyPackagesValue)
            }
            if let value = localHashes {
                let localHashesValue = try value.toCBORValue()
                map = map.adding(key: "localHashes", value: localHashesValue)
            }
            if let value = deviceId {
                let deviceIdValue = try value.toCBORValue()
                map = map.adding(key: "deviceId", value: deviceIdValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case action
            case keyPackages
            case localHashes
            case deviceId
        }
    }
    
public struct Output: ATProtocolCodable {
        
        
        public let stats: KeyPackageStats
        
        public let syncResult: SyncResult?
        
        public let publishResult: PublishResult?
        
        
        
        // Standard public initializer
        public init(
            
            
            stats: KeyPackageStats,
            
            syncResult: SyncResult? = nil,
            
            publishResult: PublishResult? = nil
            
            
        ) {
            
            
            self.stats = stats
            
            self.syncResult = syncResult
            
            self.publishResult = publishResult
            
            
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.stats = try container.decode(KeyPackageStats.self, forKey: .stats)
            
            
            self.syncResult = try container.decodeIfPresent(SyncResult.self, forKey: .syncResult)
            
            
            self.publishResult = try container.decodeIfPresent(PublishResult.self, forKey: .publishResult)
            
            
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(stats, forKey: .stats)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(syncResult, forKey: .syncResult)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(publishResult, forKey: .publishResult)
            
            
        }

        public func toCBORValue() throws -> Any {
            
            var map = OrderedCBORMap()

            
            
            let statsValue = try stats.toCBORValue()
            map = map.adding(key: "stats", value: statsValue)
            
            
            
            if let value = syncResult {
                // Encode optional property even if it's an empty array for CBOR
                let syncResultValue = try value.toCBORValue()
                map = map.adding(key: "syncResult", value: syncResultValue)
            }
            
            
            
            if let value = publishResult {
                // Encode optional property even if it's an empty array for CBOR
                let publishResultValue = try value.toCBORValue()
                map = map.adding(key: "publishResult", value: publishResultValue)
            }
            
            

            return map
            
        }
        
        
        private enum CodingKeys: String, CodingKey {
            case stats
            case syncResult
            case publishResult
        }
        
    }
        
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
                case invalidAction = "InvalidAction.Action must be 'publish' or 'sync'"
                case missingKeyPackages = "MissingKeyPackages.keyPackages required for 'publish' action"
                case missingLocalHashes = "MissingLocalHashes.localHashes required for 'sync' action"
                case missingDeviceId = "MissingDeviceId.deviceId required for 'sync' action"
                case batchTooLarge = "BatchTooLarge.Batch size exceeds maximum of 100 key packages"
                case invalidBatch = "InvalidBatch.Batch validation failed"
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
    // MARK: - publishKeyPackages

    /// Unified key package management: publish new packages or sync with server (consolidates publishKeyPackages + syncKeyPackages + getKeyPackageStats) Manage key packages for the authenticated user's device. Supports two actions: 'publish' uploads new key packages, 'sync' compares local hashes against server to clean up orphaned packages. Both actions return current stats.
    /// 
    /// - Parameter input: The input parameters for the request
    
    /// 
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    public func publishKeyPackages(
        
        input: BlueCatbirdMlsChatPublishKeyPackages.Input
        
    ) async throws -> (responseCode: Int, data: BlueCatbirdMlsChatPublishKeyPackages.Output?) {
        let endpoint = "blue.catbird.mlsChat.publishKeyPackages"
        
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
        let serviceDID = await networkService.getServiceDID(for: "blue.catbird.mlsChat.publishKeyPackages")
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
                let decodedData = try decoder.decode(BlueCatbirdMlsChatPublishKeyPackages.Output.self, from: responseData)
                
                return (responseCode, decodedData)
            } catch {
                // Log the decoding error for debugging but still return the response code
                LogManager.logError("Failed to decode successful response for blue.catbird.mlsChat.publishKeyPackages: \(error)")
                return (responseCode, nil)
            }
        } else {
            // Don't try to decode error responses as success types
            return (responseCode, nil)
        }
        
    }
    
}
                           

