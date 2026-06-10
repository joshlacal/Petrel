import Foundation

// lexicon: 1, id: blue.catbird.mlsChat.publishKeyPackages

public enum BlueCatbirdMlsChatPublishKeyPackages {
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
                keyPackage = try container.decode(Bytes.self, forKey: .keyPackage)
            } catch {
                LogManager.logError("Decoding error for required property 'keyPackage': \(error)")
                throw error
            }
            do {
                cipherSuite = try container.decode(String.self, forKey: .cipherSuite)
            } catch {
                LogManager.logError("Decoding error for required property 'cipherSuite': \(error)")
                throw error
            }
            do {
                expires = try container.decode(ATProtocolDate.self, forKey: .expires)
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
                published = try container.decode(Int.self, forKey: .published)
            } catch {
                LogManager.logError("Decoding error for required property 'published': \(error)")
                throw error
            }
            do {
                available = try container.decode(Int.self, forKey: .available)
            } catch {
                LogManager.logError("Decoding error for required property 'available': \(error)")
                throw error
            }
            do {
                expired = try container.decode(Int.self, forKey: .expired)
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
                serverHashes = try container.decode([String].self, forKey: .serverHashes)
            } catch {
                LogManager.logError("Decoding error for required property 'serverHashes': \(error)")
                throw error
            }
            do {
                orphanedCount = try container.decode(Int.self, forKey: .orphanedCount)
            } catch {
                LogManager.logError("Decoding error for required property 'orphanedCount': \(error)")
                throw error
            }
            do {
                orphanedHashes = try container.decodeIfPresent([String].self, forKey: .orphanedHashes)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'orphanedHashes': \(error)")
                throw error
            }
            do {
                deletedCount = try container.decode(Int.self, forKey: .deletedCount)
            } catch {
                LogManager.logError("Decoding error for required property 'deletedCount': \(error)")
                throw error
            }
            do {
                remainingAvailable = try container.decodeIfPresent(Int.self, forKey: .remainingAvailable)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'remainingAvailable': \(error)")
                throw error
            }
            do {
                deviceId = try container.decode(String.self, forKey: .deviceId)
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
                succeeded = try container.decode(Int.self, forKey: .succeeded)
            } catch {
                LogManager.logError("Decoding error for required property 'succeeded': \(error)")
                throw error
            }
            do {
                failed = try container.decode(Int.self, forKey: .failed)
            } catch {
                LogManager.logError("Decoding error for required property 'failed': \(error)")
                throw error
            }
            do {
                errors = try container.decodeIfPresent([BatchError].self, forKey: .errors)
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

    public struct ReplenishResult: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "blue.catbird.mlsChat.publishKeyPackages#replenishResult"
        public let requested: Bool
        public let targetCount: Int
        public let deviceCount: Int
        public let deliveredCount: Int

        public init(
            requested: Bool, targetCount: Int, deviceCount: Int, deliveredCount: Int
        ) {
            self.requested = requested
            self.targetCount = targetCount
            self.deviceCount = deviceCount
            self.deliveredCount = deliveredCount
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                requested = try container.decode(Bool.self, forKey: .requested)
            } catch {
                LogManager.logError("Decoding error for required property 'requested': \(error)")
                throw error
            }
            do {
                targetCount = try container.decode(Int.self, forKey: .targetCount)
            } catch {
                LogManager.logError("Decoding error for required property 'targetCount': \(error)")
                throw error
            }
            do {
                deviceCount = try container.decode(Int.self, forKey: .deviceCount)
            } catch {
                LogManager.logError("Decoding error for required property 'deviceCount': \(error)")
                throw error
            }
            do {
                deliveredCount = try container.decode(Int.self, forKey: .deliveredCount)
            } catch {
                LogManager.logError("Decoding error for required property 'deliveredCount': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(requested, forKey: .requested)
            try container.encode(targetCount, forKey: .targetCount)
            try container.encode(deviceCount, forKey: .deviceCount)
            try container.encode(deliveredCount, forKey: .deliveredCount)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(requested)
            hasher.combine(targetCount)
            hasher.combine(deviceCount)
            hasher.combine(deliveredCount)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if requested != other.requested {
                return false
            }
            if targetCount != other.targetCount {
                return false
            }
            if deviceCount != other.deviceCount {
                return false
            }
            if deliveredCount != other.deliveredCount {
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
            let requestedValue = try requested.toCBORValue()
            map = map.adding(key: "requested", value: requestedValue)
            let targetCountValue = try targetCount.toCBORValue()
            map = map.adding(key: "targetCount", value: targetCountValue)
            let deviceCountValue = try deviceCount.toCBORValue()
            map = map.adding(key: "deviceCount", value: deviceCountValue)
            let deliveredCountValue = try deliveredCount.toCBORValue()
            map = map.adding(key: "deliveredCount", value: deliveredCountValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case requested
            case targetCount
            case deviceCount
            case deliveredCount
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
                index = try container.decode(Int.self, forKey: .index)
            } catch {
                LogManager.logError("Decoding error for required property 'index': \(error)")
                throw error
            }
            do {
                error = try container.decode(String.self, forKey: .error)
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
        public let targetDids: [DID]?
        public let reason: String?
        public let convoId: String?

        /// Standard public initializer
        public init(action: String, keyPackages: [KeyPackageItem]? = nil, localHashes: [String]? = nil, deviceId: String? = nil, targetDids: [DID]? = nil, reason: String? = nil, convoId: String? = nil) {
            self.action = action
            self.keyPackages = keyPackages
            self.localHashes = localHashes
            self.deviceId = deviceId
            self.targetDids = targetDids
            self.reason = reason
            self.convoId = convoId
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            action = try container.decode(String.self, forKey: .action)
            keyPackages = try container.decodeIfPresent([KeyPackageItem].self, forKey: .keyPackages)
            localHashes = try container.decodeIfPresent([String].self, forKey: .localHashes)
            deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            targetDids = try container.decodeIfPresent([DID].self, forKey: .targetDids)
            reason = try container.decodeIfPresent(String.self, forKey: .reason)
            convoId = try container.decodeIfPresent(String.self, forKey: .convoId)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(action, forKey: .action)
            try container.encodeIfPresent(keyPackages, forKey: .keyPackages)
            try container.encodeIfPresent(localHashes, forKey: .localHashes)
            try container.encodeIfPresent(deviceId, forKey: .deviceId)
            try container.encodeIfPresent(targetDids, forKey: .targetDids)
            try container.encodeIfPresent(reason, forKey: .reason)
            try container.encodeIfPresent(convoId, forKey: .convoId)
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
            if let value = targetDids {
                let targetDidsValue = try value.toCBORValue()
                map = map.adding(key: "targetDids", value: targetDidsValue)
            }
            if let value = reason {
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            if let value = convoId {
                let convoIdValue = try value.toCBORValue()
                map = map.adding(key: "convoId", value: convoIdValue)
            }
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case action
            case keyPackages
            case localHashes
            case deviceId
            case targetDids
            case reason
            case convoId
        }
    }

    public struct Output: ATProtocolCodable {
        public let stats: KeyPackageStats

        public let syncResult: SyncResult?

        public let publishResult: PublishResult?

        public let replenishResult: ReplenishResult?

        /// Standard public initializer
        public init(
            stats: KeyPackageStats,

            syncResult: SyncResult? = nil,

            publishResult: PublishResult? = nil,

            replenishResult: ReplenishResult? = nil

        ) {
            self.stats = stats

            self.syncResult = syncResult

            self.publishResult = publishResult

            self.replenishResult = replenishResult
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            stats = try container.decode(KeyPackageStats.self, forKey: .stats)

            syncResult = try container.decodeIfPresent(SyncResult.self, forKey: .syncResult)

            publishResult = try container.decodeIfPresent(PublishResult.self, forKey: .publishResult)

            replenishResult = try container.decodeIfPresent(ReplenishResult.self, forKey: .replenishResult)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(stats, forKey: .stats)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(syncResult, forKey: .syncResult)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(publishResult, forKey: .publishResult)

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(replenishResult, forKey: .replenishResult)
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

            if let value = replenishResult {
                // Encode optional property even if it's an empty array for CBOR
                let replenishResultValue = try value.toCBORValue()
                map = map.adding(key: "replenishResult", value: replenishResultValue)
            }

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case stats
            case syncResult
            case publishResult
            case replenishResult
        }
    }

    public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
        case invalidAction = "InvalidAction.Action must be 'publish', 'publishBatch', 'sync', 'stats', or 'requestReplenish'"
        case missingKeyPackages = "MissingKeyPackages.keyPackages required for 'publish' action"
        case missingLocalHashes = "MissingLocalHashes.localHashes required for 'sync' action"
        case missingDeviceId = "MissingDeviceId.deviceId required for 'sync' action"
        case missingTargetDids = "MissingTargetDids.targetDids required for 'requestReplenish' action"
        case batchTooLarge = "BatchTooLarge.Batch size exceeds maximum of 100 key packages"
        case invalidBatch = "InvalidBatch.Batch validation failed"
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
    // MARK: - publishKeyPackages

    // Unified key package management: publish new packages or sync with server (consolidates publishKeyPackages + syncKeyPackages + getKeyPackageStats) Manage key packages for the authenticated user's device. Supports 'publish' to upload key packages, 'sync' to compare local hashes against server, 'stats' to fetch current counts, and 'requestReplenish' to ask peer devices to replenish missing key packages.
    //
    // - Parameter input: The input parameters for the request

    ///
    /// - Returns: A tuple containing the HTTP response code and the decoded response data
    /// - Throws: NetworkError if the request fails or the response cannot be processed
    func publishKeyPackages(
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
