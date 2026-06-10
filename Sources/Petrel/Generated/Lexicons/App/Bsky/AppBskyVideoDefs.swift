import Foundation

// lexicon: 1, id: app.bsky.video.defs

public enum AppBskyVideoDefs {
    public static let typeIdentifier = "app.bsky.video.defs"

    public struct JobStatus: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.video.defs#jobStatus"
        public let jobId: String
        public let did: DID
        public let state: String
        public let progress: Int?
        public let blob: Blob?
        public let error: String?
        public let message: String?

        public init(
            jobId: String, did: DID, state: String, progress: Int?, blob: Blob?, error: String?, message: String?
        ) {
            self.jobId = jobId
            self.did = did
            self.state = state
            self.progress = progress
            self.blob = blob
            self.error = error
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                jobId = try container.decode(String.self, forKey: .jobId)
            } catch {
                LogManager.logError("Decoding error for required property 'jobId': \(error)")
                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)
            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")
                throw error
            }
            do {
                state = try container.decode(String.self, forKey: .state)
            } catch {
                LogManager.logError("Decoding error for required property 'state': \(error)")
                throw error
            }
            do {
                progress = try container.decodeIfPresent(Int.self, forKey: .progress)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'progress': \(error)")
                throw error
            }
            do {
                blob = try container.decodeIfPresent(Blob.self, forKey: .blob)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'blob': \(error)")
                throw error
            }
            do {
                error = try container.decodeIfPresent(String.self, forKey: .error)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'error': \(error)")
                throw error
            }
            do {
                message = try container.decodeIfPresent(String.self, forKey: .message)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'message': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(jobId, forKey: .jobId)
            try container.encode(did, forKey: .did)
            try container.encode(state, forKey: .state)
            try container.encodeIfPresent(progress, forKey: .progress)
            try container.encodeIfPresent(blob, forKey: .blob)
            try container.encodeIfPresent(error, forKey: .error)
            try container.encodeIfPresent(message, forKey: .message)
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

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            let jobIdValue = try jobId.toCBORValue()
            map = map.adding(key: "jobId", value: jobIdValue)
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            let stateValue = try state.toCBORValue()
            map = map.adding(key: "state", value: stateValue)
            if let value = progress {
                let progressValue = try value.toCBORValue()
                map = map.adding(key: "progress", value: progressValue)
            }
            if let value = blob {
                let blobValue = try value.toCBORValue()
                map = map.adding(key: "blob", value: blobValue)
            }
            if let value = error {
                let errorValue = try value.toCBORValue()
                map = map.adding(key: "error", value: errorValue)
            }
            if let value = message {
                let messageValue = try value.toCBORValue()
                map = map.adding(key: "message", value: messageValue)
            }
            return map
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
    }
}
