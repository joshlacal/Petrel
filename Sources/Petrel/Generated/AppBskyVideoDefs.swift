import Foundation



// lexicon: 1, id: app.bsky.video.defs


public struct AppBskyVideoDefs { 

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
                
                self.jobId = try container.decode(String.self, forKey: .jobId)
                
            } catch {
                LogManager.logError("Decoding error for property 'jobId': \(error)")
                throw error
            }
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                
                self.state = try container.decode(String.self, forKey: .state)
                
            } catch {
                LogManager.logError("Decoding error for property 'state': \(error)")
                throw error
            }
            do {
                
                self.progress = try container.decodeIfPresent(Int.self, forKey: .progress)
                
            } catch {
                LogManager.logError("Decoding error for property 'progress': \(error)")
                throw error
            }
            do {
                
                self.blob = try container.decodeIfPresent(Blob.self, forKey: .blob)
                
            } catch {
                LogManager.logError("Decoding error for property 'blob': \(error)")
                throw error
            }
            do {
                
                self.error = try container.decodeIfPresent(String.self, forKey: .error)
                
            } catch {
                LogManager.logError("Decoding error for property 'error': \(error)")
                throw error
            }
            do {
                
                self.message = try container.decodeIfPresent(String.self, forKey: .message)
                
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
            
            if self.jobId != other.jobId {
                return false
            }
            
            
            if self.did != other.did {
                return false
            }
            
            
            if self.state != other.state {
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
    }



}


                           
