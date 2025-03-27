import Foundation



// lexicon: 1, id: chat.bsky.actor.defs


public struct ChatBskyActorDefs { 

    public static let typeIdentifier = "chat.bsky.actor.defs"
        
public struct ProfileViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.actor.defs#profileViewBasic"
            public let did: String
            public let handle: String
            public let displayName: String?
            public let avatar: URI?
            public let associated: AppBskyActorDefs.ProfileAssociated?
            public let viewer: AppBskyActorDefs.ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let chatDisabled: Bool?

        // Standard initializer
        public init(
            did: String, handle: String, displayName: String?, avatar: URI?, associated: AppBskyActorDefs.ProfileAssociated?, viewer: AppBskyActorDefs.ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, chatDisabled: Bool?
        ) {
            
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.avatar = avatar
            self.associated = associated
            self.viewer = viewer
            self.labels = labels
            self.chatDisabled = chatDisabled
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                
                self.handle = try container.decode(String.self, forKey: .handle)
                
            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                
                self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
                
            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                
                self.associated = try container.decodeIfPresent(AppBskyActorDefs.ProfileAssociated.self, forKey: .associated)
                
            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                
                self.viewer = try container.decodeIfPresent(AppBskyActorDefs.ViewerState.self, forKey: .viewer)
                
            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                
                self.chatDisabled = try container.decodeIfPresent(Bool.self, forKey: .chatDisabled)
                
            } catch {
                LogManager.logError("Decoding error for property 'chatDisabled': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            if let value = displayName {
                
                try container.encode(value, forKey: .displayName)
                
            }
            
            
            if let value = avatar {
                
                try container.encode(value, forKey: .avatar)
                
            }
            
            
            if let value = associated {
                
                try container.encode(value, forKey: .associated)
                
            }
            
            
            if let value = viewer {
                
                try container.encode(value, forKey: .viewer)
                
            }
            
            
            if let value = labels {
                
                if !value.isEmpty {
                    try container.encode(value, forKey: .labels)
                }
                
            }
            
            
            if let value = chatDisabled {
                
                try container.encode(value, forKey: .chatDisabled)
                
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = associated {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = viewer {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = chatDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.did != other.did {
                return false
            }
            
            
            if self.handle != other.handle {
                return false
            }
            
            
            if displayName != other.displayName {
                return false
            }
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            if associated != other.associated {
                return false
            }
            
            
            if viewer != other.viewer {
                return false
            }
            
            
            if labels != other.labels {
                return false
            }
            
            
            if chatDisabled != other.chatDisabled {
                return false
            }
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case displayName
            case avatar
            case associated
            case viewer
            case labels
            case chatDisabled
        }
    }



}


                           
