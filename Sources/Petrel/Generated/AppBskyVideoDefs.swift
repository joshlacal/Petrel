import Foundation

// lexicon: 1, id: app.bsky.video.defs

public enum AppBskyVideoDefs {
    public static let typeIdentifier = "app.bsky.video.defs"

    public struct JobStatus: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.video.defs#jobStatus"
        public let jobId: String
        public let did: String
        public let state: String
        public let progress: Int?
        public let blob: Blob?
        public let error: String?
        public let message: String?

        // Standard initializer
        public init(
            jobId: String, did: String, state: String, progress: Int?, blob: Blob?, error: String?, message: String?
        ) {
            self.jobId = jobId
            self.did = did
            self.state = state
            self.progress = progress
            self.blob = blob
            self.error = error
            self.message = message
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                jobId = try container.decode(String.self, forKey: .jobId)

            } catch {
                LogManager.logError("Decoding error for property 'jobId': \(error)")
                throw error
            }
            do {
                did = try container.decode(String.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                state = try container.decode(String.self, forKey: .state)

            } catch {
                LogManager.logError("Decoding error for property 'state': \(error)")
                throw error
            }
            do {
                progress = try container.decodeIfPresent(Int.self, forKey: .progress)

            } catch {
                LogManager.logError("Decoding error for property 'progress': \(error)")
                throw error
            }
            do {
                blob = try container.decodeIfPresent(Blob.self, forKey: .blob)

            } catch {
                LogManager.logError("Decoding error for property 'blob': \(error)")
                throw error
            }
            do {
                error = try container.decodeIfPresent(String.self, forKey: .error)

            } catch {
                LogManager.logError("Decoding error for property 'error': \(error)")
                throw error
            }
            do {
                message = try container.decodeIfPresent(String.self, forKey: .message)

            } catch {
                LogManager.logError("Decoding error for property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(jobId, forKey: .jobId)

            try container.encode(did, forKey: .did)

            try container.encode(state, forKey: .state)

            if let value = progress {
                try container.encode(value, forKey: .progress)
            }

            if let value = blob {
                try container.encode(value, forKey: .blob)
            }

            if let value = error {
                try container.encode(value, forKey: .error)
            }

            if let value = message {
                try container.encode(value, forKey: .message)
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(jobId)
            hasher.combine(did)
            hasher.combine(state)
            if let value = progress {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = blob {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = error {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = message {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if jobId != other.jobId {
                return false
            }

            if did != other.did {
                return false
            }

            if state != other.state {
                return false
            }

            if progress != other.progress {
                return false
            }

            if blob != other.blob {
                return false
            }

            if error != other.error {
                return false
            }

            if message != other.message {
                return false
            }

            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case jobId
            case did
            case state
            case progress
            case blob
            case error
            case message
        }

        // MARK: - PendingDataLoadable

        /// Check if any properties contain pending data that needs loading
        public var hasPendingData: Bool {
            var hasPending = false

            if !hasPending, let loadable = jobId as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = did as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let loadable = state as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = progress, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = blob, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = error, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            if !hasPending, let value = message, let loadable = value as? PendingDataLoadable {
                hasPending = loadable.hasPendingData
            }

            return hasPending
        }

        /// Load any pending data in properties
        public mutating func loadPendingData() async {
            if let loadable = jobId as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    jobId = updatedValue
                }
            }

            if let loadable = did as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    did = updatedValue
                }
            }

            if let loadable = state as? PendingDataLoadable, loadable.hasPendingData {
                var mutableValue = loadable
                await mutableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = mutableValue as? String {
                    state = updatedValue
                }
            }

            if let value = progress, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? Int {
                    progress = updatedValue
                }
            }

            if let value = blob, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? Blob {
                    blob = updatedValue
                }
            }

            if let value = error, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? String {
                    error = updatedValue
                }
            }

            if let value = message, var loadableValue = value as? PendingDataLoadable, loadableValue.hasPendingData {
                await loadableValue.loadPendingData()
                // Only update if we can safely cast back to the expected type
                if let updatedValue = loadableValue as? String {
                    message = updatedValue
                }
            }
        }
    }
}
