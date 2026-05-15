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
            public let createdAt: ATProtocolDate?
            public let chatDisabled: Bool?
            public let verification: AppBskyActorDefs.VerificationState?
            public let kind: ProfileViewBasicKindUnion?

        public init(
            did: DID, handle: Handle, displayName: String?, avatar: URI?, associated: AppBskyActorDefs.ProfileAssociated?, viewer: AppBskyActorDefs.ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, createdAt: ATProtocolDate?, chatDisabled: Bool?, verification: AppBskyActorDefs.VerificationState?, kind: ProfileViewBasicKindUnion?
        ) {
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.avatar = avatar
            self.associated = associated
            self.viewer = viewer
            self.labels = labels
            self.createdAt = createdAt
            self.chatDisabled = chatDisabled
            self.verification = verification
            self.kind = kind
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
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
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
            do {
                self.kind = try container.decodeIfPresent(ProfileViewBasicKindUnion.self, forKey: .kind)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'kind': \(error)")
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
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            try container.encodeIfPresent(chatDisabled, forKey: .chatDisabled)
            try container.encodeIfPresent(verification, forKey: .verification)
            try container.encodeIfPresent(kind, forKey: .kind)
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
            if let value = createdAt {
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
            if let value = kind {
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
            if createdAt != other.createdAt {
                return false
            }
            if chatDisabled != other.chatDisabled {
                return false
            }
            if verification != other.verification {
                return false
            }
            if kind != other.kind {
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
            if let value = createdAt {
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            if let value = chatDisabled {
                let chatDisabledValue = try value.toCBORValue()
                map = map.adding(key: "chatDisabled", value: chatDisabledValue)
            }
            if let value = verification {
                let verificationValue = try value.toCBORValue()
                map = map.adding(key: "verification", value: verificationValue)
            }
            if let value = kind {
                let kindValue = try value.toCBORValue()
                map = map.adding(key: "kind", value: kindValue)
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
            case createdAt
            case chatDisabled
            case verification
            case kind
        }
    }
        
public struct DirectConvoMember: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.actor.defs#directConvoMember"

        public init(
            
        ) {
        }

        public init(from decoder: Decoder) throws {
            
            let _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct GroupConvoMember: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.actor.defs#groupConvoMember"
            public let addedBy: ProfileViewBasic?
            public let role: MemberRole

        public init(
            addedBy: ProfileViewBasic?, role: MemberRole
        ) {
            self.addedBy = addedBy
            self.role = role
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                self.addedBy = try container.decodeIfPresent(ProfileViewBasic.self, forKey: .addedBy)
            } catch {
                LogManager.logDebug("Decoding error for optional property 'addedBy': \(error)")
                throw error
            }
            do {
                self.role = try container.decode(MemberRole.self, forKey: .role)
            } catch {
                LogManager.logError("Decoding error for required property 'role': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            try container.encodeIfPresent(addedBy, forKey: .addedBy)
            try container.encode(role, forKey: .role)
        }

        public func hash(into hasher: inout Hasher) {
            if let value = addedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(role)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            if addedBy != other.addedBy {
                return false
            }
            if role != other.role {
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
            if let value = addedBy {
                let addedByValue = try value.toCBORValue()
                map = map.adding(key: "addedBy", value: addedByValue)
            }
            let roleValue = try role.toCBORValue()
            map = map.adding(key: "role", value: roleValue)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case addedBy
            case role
        }
    }
        
public struct PastGroupConvoMember: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "chat.bsky.actor.defs#pastGroupConvoMember"

        public init(
            
        ) {
        }

        public init(from decoder: Decoder) throws {
            
            let _ = decoder
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()
            map = map.adding(key: "$type", value: Self.typeIdentifier)
            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }



public struct MemberRole: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let owner = MemberRole(rawValue: "owner")
            // 
            public static let standard = MemberRole(rawValue: "standard")
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                rawValue = try container.decode(String.self)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
            
            public func isEqual(to other: any ATProtocolValue) -> Bool {
                guard let otherValue = other as? MemberRole else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [MemberRole] {
                return [
                    .owner,
                    .standard,
                ]
            }
        }



public indirect enum ProfileViewBasicKindUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case chatBskyActorDefsDirectConvoMember(ChatBskyActorDefs.DirectConvoMember)
    case chatBskyActorDefsGroupConvoMember(ChatBskyActorDefs.GroupConvoMember)
    case chatBskyActorDefsPastGroupConvoMember(ChatBskyActorDefs.PastGroupConvoMember)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: ChatBskyActorDefs.DirectConvoMember) {
        self = .chatBskyActorDefsDirectConvoMember(value)
    }
    public init(_ value: ChatBskyActorDefs.GroupConvoMember) {
        self = .chatBskyActorDefsGroupConvoMember(value)
    }
    public init(_ value: ChatBskyActorDefs.PastGroupConvoMember) {
        self = .chatBskyActorDefsPastGroupConvoMember(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "chat.bsky.actor.defs#directConvoMember":
            let value = try ChatBskyActorDefs.DirectConvoMember(from: decoder)
            self = .chatBskyActorDefsDirectConvoMember(value)
        case "chat.bsky.actor.defs#groupConvoMember":
            let value = try ChatBskyActorDefs.GroupConvoMember(from: decoder)
            self = .chatBskyActorDefsGroupConvoMember(value)
        case "chat.bsky.actor.defs#pastGroupConvoMember":
            let value = try ChatBskyActorDefs.PastGroupConvoMember(from: decoder)
            self = .chatBskyActorDefsPastGroupConvoMember(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .chatBskyActorDefsDirectConvoMember(let value):
            try container.encode("chat.bsky.actor.defs#directConvoMember", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyActorDefsGroupConvoMember(let value):
            try container.encode("chat.bsky.actor.defs#groupConvoMember", forKey: .type)
            try value.encode(to: encoder)
        case .chatBskyActorDefsPastGroupConvoMember(let value):
            try container.encode("chat.bsky.actor.defs#pastGroupConvoMember", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .chatBskyActorDefsDirectConvoMember(let value):
            hasher.combine("chat.bsky.actor.defs#directConvoMember")
            hasher.combine(value)
        case .chatBskyActorDefsGroupConvoMember(let value):
            hasher.combine("chat.bsky.actor.defs#groupConvoMember")
            hasher.combine(value)
        case .chatBskyActorDefsPastGroupConvoMember(let value):
            hasher.combine("chat.bsky.actor.defs#pastGroupConvoMember")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ProfileViewBasicKindUnion, rhs: ProfileViewBasicKindUnion) -> Bool {
        switch (lhs, rhs) {
        case (.chatBskyActorDefsDirectConvoMember(let lhsValue),
              .chatBskyActorDefsDirectConvoMember(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyActorDefsGroupConvoMember(let lhsValue),
              .chatBskyActorDefsGroupConvoMember(let rhsValue)):
            return lhsValue == rhsValue
        case (.chatBskyActorDefsPastGroupConvoMember(let lhsValue),
              .chatBskyActorDefsPastGroupConvoMember(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ProfileViewBasicKindUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .chatBskyActorDefsDirectConvoMember(let value):
            map = map.adding(key: "$type", value: "chat.bsky.actor.defs#directConvoMember")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .chatBskyActorDefsGroupConvoMember(let value):
            map = map.adding(key: "$type", value: "chat.bsky.actor.defs#groupConvoMember")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .chatBskyActorDefsPastGroupConvoMember(let value):
            map = map.adding(key: "$type", value: "chat.bsky.actor.defs#pastGroupConvoMember")
            
            let valueDict = try value.toCBORValue()

            // If the value is already an OrderedCBORMap, merge its entries
            if let orderedMap = valueDict as? OrderedCBORMap {
                for (key, value) in orderedMap.entries where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            } else if let dict = valueDict as? [String: Any] {
                // Otherwise add each key-value pair from the dictionary
                for (key, value) in dict where key != "$type" {
                    map = map.adding(key: key, value: value)
                }
            }
            return map
        case .unexpected(let container):
            return try container.toCBORValue()
        }
    }
}


}


                           

