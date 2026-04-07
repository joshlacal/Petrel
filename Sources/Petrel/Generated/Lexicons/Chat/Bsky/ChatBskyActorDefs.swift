import Foundation



// lexicon: 1, id: chat.bsky.actor.defs


public struct ChatBskyActorDefs { 

    public static let typeIdentifier = "chat.bsky.actor.defs"
        
public struct ProfileViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.actor.defs#profileViewBasic"
            public let did: DID
            public let handle: Handle
            public let displayName: String?
            public let avatar: URI?
            public let associated: AppBskyActorDefs.ProfileAssociated?
            public let viewer: AppBskyActorDefs.ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let chatDisabled: Bool?
            public let verification: AppBskyActorDefs.VerificationState?

        public init(
            did: DID, handle: Handle, displayName: String?, avatar: URI?, associated: AppBskyActorDefs.ProfileAssociated?, viewer: AppBskyActorDefs.ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, chatDisabled: Bool?, verification: AppBskyActorDefs.VerificationState?
        ) {
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.avatar = avatar
            self.associated = associated
            self.viewer = viewer
            self.labels = labels
            self.chatDisabled = chatDisabled
            self.verification = verification
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
                self.handle = try container.decode(Handle.self, forKey: .handle)
            } catch {
                LogManager.logError("Decoding error for required property 'handle': \(error)")
                throw error
            }
            do {
                self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'displayName': \(error)")
                throw error
            }
            do {
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                throw error
            }
            do {
                self.associated = try container.decodeIfPresent(AppBskyActorDefs.ProfileAssociated.self, forKey: .associated)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'associated': \(error)")
                throw error
            }
            do {
                self.viewer = try container.decodeIfPresent(AppBskyActorDefs.ViewerState.self, forKey: .viewer)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")
                throw error
            }
            do {
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")
                throw error
            }
            do {
                self.chatDisabled = try container.decodeIfPresent(Bool.self, forKey: .chatDisabled)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'chatDisabled': \(error)")
                throw error
            }
            do {
                self.verification = try container.decodeIfPresent(AppBskyActorDefs.VerificationState.self, forKey: .verification)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'verification': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encode(did, forKey: .did)
            try container.encode(handle, forKey: .handle)
            try container.encodeIfPresent(displayName, forKey: .displayName)
            try container.encodeIfPresent(avatar, forKey: .avatar)
            try container.encodeIfPresent(associated, forKey: .associated)
            try container.encodeIfPresent(viewer, forKey: .viewer)
            try container.encodeIfPresent(labels, forKey: .labels)
            try container.encodeIfPresent(chatDisabled, forKey: .chatDisabled)
            try container.encodeIfPresent(verification, forKey: .verification)
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
            if let value = verification {
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
            if handle != other.handle {
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
            if verification != other.verification {
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
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            if let value = displayName {
                let displayNameValue = try value.toCBORValue()
                map = map.adding(key: "displayName", value: displayNameValue)
            }
            if let value = avatar {
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            if let value = associated {
                let associatedValue = try value.toCBORValue()
                map = map.adding(key: "associated", value: associatedValue)
            }
            if let value = viewer {
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            if let value = labels {
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            if let value = chatDisabled {
                let chatDisabledValue = try value.toCBORValue()
                map = map.adding(key: "chatDisabled", value: chatDisabledValue)
            }
            if let value = verification {
                let verificationValue = try value.toCBORValue()
                map = map.adding(key: "verification", value: verificationValue)
            }
            return map
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
            case verification
        }
    }



}


                           

