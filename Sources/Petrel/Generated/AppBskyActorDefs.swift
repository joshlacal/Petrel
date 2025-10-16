import Foundation



// lexicon: 1, id: app.bsky.actor.defs


public struct AppBskyActorDefs { 

    public static let typeIdentifier = "app.bsky.actor.defs"
        
public struct ProfileViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileViewBasic"
            public let did: DID
            public let handle: Handle
            public let displayName: String?
            public let pronouns: String?
            public let avatar: URI?
            public let associated: ProfileAssociated?
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let createdAt: ATProtocolDate?
            public let verification: VerificationState?
            public let status: StatusView?

        // Standard initializer
        public init(
            did: DID, handle: Handle, displayName: String?, pronouns: String?, avatar: URI?, associated: ProfileAssociated?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, createdAt: ATProtocolDate?, verification: VerificationState?, status: StatusView?
        ) {
            
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.pronouns = pronouns
            self.avatar = avatar
            self.associated = associated
            self.viewer = viewer
            self.labels = labels
            self.createdAt = createdAt
            self.verification = verification
            self.status = status
        }

        // Codable initializer
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
                
                
                self.pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'pronouns': \(error)")
                
                throw error
            }
            do {
                
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                
                throw error
            }
            do {
                
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'associated': \(error)")
                
                throw error
            }
            do {
                
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
                
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
                
                
                self.verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'verification': \(error)")
                
                throw error
            }
            do {
                
                
                self.status = try container.decodeIfPresent(StatusView.self, forKey: .status)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(handle, forKey: .handle)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(displayName, forKey: .displayName)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pronouns, forKey: .pronouns)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(associated, forKey: .associated)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verification, forKey: .verification)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = pronouns {
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
            if let value = verification {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
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
            
            
            
            
            if pronouns != other.pronouns {
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
            
            
            
            
            if verification != other.verification {
                return false
            }
            
            
            
            
            if status != other.status {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            
            
            if let value = displayName {
                // Encode optional property even if it's an empty array for CBOR
                
                let displayNameValue = try value.toCBORValue()
                map = map.adding(key: "displayName", value: displayNameValue)
            }
            
            
            
            
            
            if let value = pronouns {
                // Encode optional property even if it's an empty array for CBOR
                
                let pronounsValue = try value.toCBORValue()
                map = map.adding(key: "pronouns", value: pronounsValue)
            }
            
            
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            
            
            if let value = associated {
                // Encode optional property even if it's an empty array for CBOR
                
                let associatedValue = try value.toCBORValue()
                map = map.adding(key: "associated", value: associatedValue)
            }
            
            
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            
            
            
            
            
            if let value = verification {
                // Encode optional property even if it's an empty array for CBOR
                
                let verificationValue = try value.toCBORValue()
                map = map.adding(key: "verification", value: verificationValue)
            }
            
            
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case displayName
            case pronouns
            case avatar
            case associated
            case viewer
            case labels
            case createdAt
            case verification
            case status
        }
    }
        
public struct ProfileView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileView"
            public let did: DID
            public let handle: Handle
            public let displayName: String?
            public let pronouns: String?
            public let description: String?
            public let avatar: URI?
            public let associated: ProfileAssociated?
            public let indexedAt: ATProtocolDate?
            public let createdAt: ATProtocolDate?
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let verification: VerificationState?
            public let status: StatusView?

        // Standard initializer
        public init(
            did: DID, handle: Handle, displayName: String?, pronouns: String?, description: String?, avatar: URI?, associated: ProfileAssociated?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, verification: VerificationState?, status: StatusView?
        ) {
            
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.pronouns = pronouns
            self.description = description
            self.avatar = avatar
            self.associated = associated
            self.indexedAt = indexedAt
            self.createdAt = createdAt
            self.viewer = viewer
            self.labels = labels
            self.verification = verification
            self.status = status
        }

        // Codable initializer
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
                
                
                self.pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'pronouns': \(error)")
                
                throw error
            }
            do {
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            do {
                
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                
                throw error
            }
            do {
                
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'associated': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'indexedAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
                
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
                
                
                self.verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'verification': \(error)")
                
                throw error
            }
            do {
                
                
                self.status = try container.decodeIfPresent(StatusView.self, forKey: .status)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(handle, forKey: .handle)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(displayName, forKey: .displayName)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pronouns, forKey: .pronouns)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(associated, forKey: .associated)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(indexedAt, forKey: .indexedAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verification, forKey: .verification)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = pronouns {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
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
            if let value = indexedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
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
            if let value = verification {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
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
            
            
            
            
            if pronouns != other.pronouns {
                return false
            }
            
            
            
            
            if description != other.description {
                return false
            }
            
            
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            
            
            if associated != other.associated {
                return false
            }
            
            
            
            
            if indexedAt != other.indexedAt {
                return false
            }
            
            
            
            
            if createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if viewer != other.viewer {
                return false
            }
            
            
            
            
            if labels != other.labels {
                return false
            }
            
            
            
            
            if verification != other.verification {
                return false
            }
            
            
            
            
            if status != other.status {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            
            
            if let value = displayName {
                // Encode optional property even if it's an empty array for CBOR
                
                let displayNameValue = try value.toCBORValue()
                map = map.adding(key: "displayName", value: displayNameValue)
            }
            
            
            
            
            
            if let value = pronouns {
                // Encode optional property even if it's an empty array for CBOR
                
                let pronounsValue = try value.toCBORValue()
                map = map.adding(key: "pronouns", value: pronounsValue)
            }
            
            
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            
            
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            
            
            if let value = associated {
                // Encode optional property even if it's an empty array for CBOR
                
                let associatedValue = try value.toCBORValue()
                map = map.adding(key: "associated", value: associatedValue)
            }
            
            
            
            
            
            if let value = indexedAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let indexedAtValue = try value.toCBORValue()
                map = map.adding(key: "indexedAt", value: indexedAtValue)
            }
            
            
            
            
            
            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            
            
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            if let value = verification {
                // Encode optional property even if it's an empty array for CBOR
                
                let verificationValue = try value.toCBORValue()
                map = map.adding(key: "verification", value: verificationValue)
            }
            
            
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case displayName
            case pronouns
            case description
            case avatar
            case associated
            case indexedAt
            case createdAt
            case viewer
            case labels
            case verification
            case status
        }
    }
        
public struct ProfileViewDetailed: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileViewDetailed"
            public let did: DID
            public let handle: Handle
            public let displayName: String?
            public let description: String?
            public let pronouns: String?
            public let website: URI?
            public let avatar: URI?
            public let banner: URI?
            public let followersCount: Int?
            public let followsCount: Int?
            public let postsCount: Int?
            public let associated: ProfileAssociated?
            public let joinedViaStarterPack: AppBskyGraphDefs.StarterPackViewBasic?
            public let indexedAt: ATProtocolDate?
            public let createdAt: ATProtocolDate?
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let pinnedPost: ComAtprotoRepoStrongRef?
            public let verification: VerificationState?
            public let status: StatusView?

        // Standard initializer
        public init(
            did: DID, handle: Handle, displayName: String?, description: String?, pronouns: String?, website: URI?, avatar: URI?, banner: URI?, followersCount: Int?, followsCount: Int?, postsCount: Int?, associated: ProfileAssociated?, joinedViaStarterPack: AppBskyGraphDefs.StarterPackViewBasic?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, pinnedPost: ComAtprotoRepoStrongRef?, verification: VerificationState?, status: StatusView?
        ) {
            
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.description = description
            self.pronouns = pronouns
            self.website = website
            self.avatar = avatar
            self.banner = banner
            self.followersCount = followersCount
            self.followsCount = followsCount
            self.postsCount = postsCount
            self.associated = associated
            self.joinedViaStarterPack = joinedViaStarterPack
            self.indexedAt = indexedAt
            self.createdAt = createdAt
            self.viewer = viewer
            self.labels = labels
            self.pinnedPost = pinnedPost
            self.verification = verification
            self.status = status
        }

        // Codable initializer
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
                
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")
                
                throw error
            }
            do {
                
                
                self.pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'pronouns': \(error)")
                
                throw error
            }
            do {
                
                
                self.website = try container.decodeIfPresent(URI.self, forKey: .website)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'website': \(error)")
                
                throw error
            }
            do {
                
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")
                
                throw error
            }
            do {
                
                
                self.banner = try container.decodeIfPresent(URI.self, forKey: .banner)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'banner': \(error)")
                
                throw error
            }
            do {
                
                
                self.followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'followersCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.followsCount = try container.decodeIfPresent(Int.self, forKey: .followsCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'followsCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'postsCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'associated': \(error)")
                
                throw error
            }
            do {
                
                
                self.joinedViaStarterPack = try container.decodeIfPresent(AppBskyGraphDefs.StarterPackViewBasic.self, forKey: .joinedViaStarterPack)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'joinedViaStarterPack': \(error)")
                
                throw error
            }
            do {
                
                
                self.indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'indexedAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'createdAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
                
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
                
                
                self.pinnedPost = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .pinnedPost)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'pinnedPost': \(error)")
                
                throw error
            }
            do {
                
                
                self.verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'verification': \(error)")
                
                throw error
            }
            do {
                
                
                self.status = try container.decodeIfPresent(StatusView.self, forKey: .status)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'status': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
            
            
            try container.encode(handle, forKey: .handle)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(displayName, forKey: .displayName)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pronouns, forKey: .pronouns)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(website, forKey: .website)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(banner, forKey: .banner)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(followersCount, forKey: .followersCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(followsCount, forKey: .followsCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(postsCount, forKey: .postsCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(associated, forKey: .associated)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(joinedViaStarterPack, forKey: .joinedViaStarterPack)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(indexedAt, forKey: .indexedAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(createdAt, forKey: .createdAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pinnedPost, forKey: .pinnedPost)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(verification, forKey: .verification)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(status, forKey: .status)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            hasher.combine(handle)
            if let value = displayName {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = pronouns {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = website {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = banner {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = followersCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = followsCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = postsCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = associated {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = joinedViaStarterPack {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = indexedAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = createdAt {
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
            if let value = pinnedPost {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = verification {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = status {
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
            
            
            
            
            if description != other.description {
                return false
            }
            
            
            
            
            if pronouns != other.pronouns {
                return false
            }
            
            
            
            
            if website != other.website {
                return false
            }
            
            
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            
            
            if banner != other.banner {
                return false
            }
            
            
            
            
            if followersCount != other.followersCount {
                return false
            }
            
            
            
            
            if followsCount != other.followsCount {
                return false
            }
            
            
            
            
            if postsCount != other.postsCount {
                return false
            }
            
            
            
            
            if associated != other.associated {
                return false
            }
            
            
            
            
            if joinedViaStarterPack != other.joinedViaStarterPack {
                return false
            }
            
            
            
            
            if indexedAt != other.indexedAt {
                return false
            }
            
            
            
            
            if createdAt != other.createdAt {
                return false
            }
            
            
            
            
            if viewer != other.viewer {
                return false
            }
            
            
            
            
            if labels != other.labels {
                return false
            }
            
            
            
            
            if pinnedPost != other.pinnedPost {
                return false
            }
            
            
            
            
            if verification != other.verification {
                return false
            }
            
            
            
            
            if status != other.status {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            
            
            let handleValue = try handle.toCBORValue()
            map = map.adding(key: "handle", value: handleValue)
            
            
            
            
            
            if let value = displayName {
                // Encode optional property even if it's an empty array for CBOR
                
                let displayNameValue = try value.toCBORValue()
                map = map.adding(key: "displayName", value: displayNameValue)
            }
            
            
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            
            
            
            
            
            if let value = pronouns {
                // Encode optional property even if it's an empty array for CBOR
                
                let pronounsValue = try value.toCBORValue()
                map = map.adding(key: "pronouns", value: pronounsValue)
            }
            
            
            
            
            
            if let value = website {
                // Encode optional property even if it's an empty array for CBOR
                
                let websiteValue = try value.toCBORValue()
                map = map.adding(key: "website", value: websiteValue)
            }
            
            
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            
            
            if let value = banner {
                // Encode optional property even if it's an empty array for CBOR
                
                let bannerValue = try value.toCBORValue()
                map = map.adding(key: "banner", value: bannerValue)
            }
            
            
            
            
            
            if let value = followersCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let followersCountValue = try value.toCBORValue()
                map = map.adding(key: "followersCount", value: followersCountValue)
            }
            
            
            
            
            
            if let value = followsCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let followsCountValue = try value.toCBORValue()
                map = map.adding(key: "followsCount", value: followsCountValue)
            }
            
            
            
            
            
            if let value = postsCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let postsCountValue = try value.toCBORValue()
                map = map.adding(key: "postsCount", value: postsCountValue)
            }
            
            
            
            
            
            if let value = associated {
                // Encode optional property even if it's an empty array for CBOR
                
                let associatedValue = try value.toCBORValue()
                map = map.adding(key: "associated", value: associatedValue)
            }
            
            
            
            
            
            if let value = joinedViaStarterPack {
                // Encode optional property even if it's an empty array for CBOR
                
                let joinedViaStarterPackValue = try value.toCBORValue()
                map = map.adding(key: "joinedViaStarterPack", value: joinedViaStarterPackValue)
            }
            
            
            
            
            
            if let value = indexedAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let indexedAtValue = try value.toCBORValue()
                map = map.adding(key: "indexedAt", value: indexedAtValue)
            }
            
            
            
            
            
            if let value = createdAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let createdAtValue = try value.toCBORValue()
                map = map.adding(key: "createdAt", value: createdAtValue)
            }
            
            
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            
            
            if let value = pinnedPost {
                // Encode optional property even if it's an empty array for CBOR
                
                let pinnedPostValue = try value.toCBORValue()
                map = map.adding(key: "pinnedPost", value: pinnedPostValue)
            }
            
            
            
            
            
            if let value = verification {
                // Encode optional property even if it's an empty array for CBOR
                
                let verificationValue = try value.toCBORValue()
                map = map.adding(key: "verification", value: verificationValue)
            }
            
            
            
            
            
            if let value = status {
                // Encode optional property even if it's an empty array for CBOR
                
                let statusValue = try value.toCBORValue()
                map = map.adding(key: "status", value: statusValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
            case handle
            case displayName
            case description
            case pronouns
            case website
            case avatar
            case banner
            case followersCount
            case followsCount
            case postsCount
            case associated
            case joinedViaStarterPack
            case indexedAt
            case createdAt
            case viewer
            case labels
            case pinnedPost
            case verification
            case status
        }
    }
        
public struct ProfileAssociated: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileAssociated"
            public let lists: Int?
            public let feedgens: Int?
            public let starterPacks: Int?
            public let labeler: Bool?
            public let chat: ProfileAssociatedChat?
            public let activitySubscription: ProfileAssociatedActivitySubscription?

        // Standard initializer
        public init(
            lists: Int?, feedgens: Int?, starterPacks: Int?, labeler: Bool?, chat: ProfileAssociatedChat?, activitySubscription: ProfileAssociatedActivitySubscription?
        ) {
            
            self.lists = lists
            self.feedgens = feedgens
            self.starterPacks = starterPacks
            self.labeler = labeler
            self.chat = chat
            self.activitySubscription = activitySubscription
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.lists = try container.decodeIfPresent(Int.self, forKey: .lists)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'lists': \(error)")
                
                throw error
            }
            do {
                
                
                self.feedgens = try container.decodeIfPresent(Int.self, forKey: .feedgens)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'feedgens': \(error)")
                
                throw error
            }
            do {
                
                
                self.starterPacks = try container.decodeIfPresent(Int.self, forKey: .starterPacks)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'starterPacks': \(error)")
                
                throw error
            }
            do {
                
                
                self.labeler = try container.decodeIfPresent(Bool.self, forKey: .labeler)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labeler': \(error)")
                
                throw error
            }
            do {
                
                
                self.chat = try container.decodeIfPresent(ProfileAssociatedChat.self, forKey: .chat)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'chat': \(error)")
                
                throw error
            }
            do {
                
                
                self.activitySubscription = try container.decodeIfPresent(ProfileAssociatedActivitySubscription.self, forKey: .activitySubscription)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'activitySubscription': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lists, forKey: .lists)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(feedgens, forKey: .feedgens)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(starterPacks, forKey: .starterPacks)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labeler, forKey: .labeler)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(chat, forKey: .chat)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(activitySubscription, forKey: .activitySubscription)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = lists {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = feedgens {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = starterPacks {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labeler {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = chat {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = activitySubscription {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if lists != other.lists {
                return false
            }
            
            
            
            
            if feedgens != other.feedgens {
                return false
            }
            
            
            
            
            if starterPacks != other.starterPacks {
                return false
            }
            
            
            
            
            if labeler != other.labeler {
                return false
            }
            
            
            
            
            if chat != other.chat {
                return false
            }
            
            
            
            
            if activitySubscription != other.activitySubscription {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = lists {
                // Encode optional property even if it's an empty array for CBOR
                
                let listsValue = try value.toCBORValue()
                map = map.adding(key: "lists", value: listsValue)
            }
            
            
            
            
            
            if let value = feedgens {
                // Encode optional property even if it's an empty array for CBOR
                
                let feedgensValue = try value.toCBORValue()
                map = map.adding(key: "feedgens", value: feedgensValue)
            }
            
            
            
            
            
            if let value = starterPacks {
                // Encode optional property even if it's an empty array for CBOR
                
                let starterPacksValue = try value.toCBORValue()
                map = map.adding(key: "starterPacks", value: starterPacksValue)
            }
            
            
            
            
            
            if let value = labeler {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelerValue = try value.toCBORValue()
                map = map.adding(key: "labeler", value: labelerValue)
            }
            
            
            
            
            
            if let value = chat {
                // Encode optional property even if it's an empty array for CBOR
                
                let chatValue = try value.toCBORValue()
                map = map.adding(key: "chat", value: chatValue)
            }
            
            
            
            
            
            if let value = activitySubscription {
                // Encode optional property even if it's an empty array for CBOR
                
                let activitySubscriptionValue = try value.toCBORValue()
                map = map.adding(key: "activitySubscription", value: activitySubscriptionValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lists
            case feedgens
            case starterPacks
            case labeler
            case chat
            case activitySubscription
        }
    }
        
public struct ProfileAssociatedChat: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileAssociatedChat"
            public let allowIncoming: String

        // Standard initializer
        public init(
            allowIncoming: String
        ) {
            
            self.allowIncoming = allowIncoming
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.allowIncoming = try container.decode(String.self, forKey: .allowIncoming)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'allowIncoming': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(allowIncoming, forKey: .allowIncoming)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(allowIncoming)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.allowIncoming != other.allowIncoming {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let allowIncomingValue = try allowIncoming.toCBORValue()
            map = map.adding(key: "allowIncoming", value: allowIncomingValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowIncoming
        }
    }
        
public struct ProfileAssociatedActivitySubscription: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileAssociatedActivitySubscription"
            public let allowSubscriptions: String

        // Standard initializer
        public init(
            allowSubscriptions: String
        ) {
            
            self.allowSubscriptions = allowSubscriptions
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.allowSubscriptions = try container.decode(String.self, forKey: .allowSubscriptions)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'allowSubscriptions': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(allowSubscriptions, forKey: .allowSubscriptions)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(allowSubscriptions)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.allowSubscriptions != other.allowSubscriptions {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let allowSubscriptionsValue = try allowSubscriptions.toCBORValue()
            map = map.adding(key: "allowSubscriptions", value: allowSubscriptionsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case allowSubscriptions
        }
    }
        
public struct ViewerState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#viewerState"
            public let muted: Bool?
            public let mutedByList: AppBskyGraphDefs.ListViewBasic?
            public let blockedBy: Bool?
            public let blocking: ATProtocolURI?
            public let blockingByList: AppBskyGraphDefs.ListViewBasic?
            public let following: ATProtocolURI?
            public let followedBy: ATProtocolURI?
            public let knownFollowers: KnownFollowers?
            public let activitySubscription: AppBskyNotificationDefs.ActivitySubscription?

        // Standard initializer
        public init(
            muted: Bool?, mutedByList: AppBskyGraphDefs.ListViewBasic?, blockedBy: Bool?, blocking: ATProtocolURI?, blockingByList: AppBskyGraphDefs.ListViewBasic?, following: ATProtocolURI?, followedBy: ATProtocolURI?, knownFollowers: KnownFollowers?, activitySubscription: AppBskyNotificationDefs.ActivitySubscription?
        ) {
            
            self.muted = muted
            self.mutedByList = mutedByList
            self.blockedBy = blockedBy
            self.blocking = blocking
            self.blockingByList = blockingByList
            self.following = following
            self.followedBy = followedBy
            self.knownFollowers = knownFollowers
            self.activitySubscription = activitySubscription
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.muted = try container.decodeIfPresent(Bool.self, forKey: .muted)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'muted': \(error)")
                
                throw error
            }
            do {
                
                
                self.mutedByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .mutedByList)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'mutedByList': \(error)")
                
                throw error
            }
            do {
                
                
                self.blockedBy = try container.decodeIfPresent(Bool.self, forKey: .blockedBy)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'blockedBy': \(error)")
                
                throw error
            }
            do {
                
                
                self.blocking = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blocking)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'blocking': \(error)")
                
                throw error
            }
            do {
                
                
                self.blockingByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .blockingByList)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'blockingByList': \(error)")
                
                throw error
            }
            do {
                
                
                self.following = try container.decodeIfPresent(ATProtocolURI.self, forKey: .following)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'following': \(error)")
                
                throw error
            }
            do {
                
                
                self.followedBy = try container.decodeIfPresent(ATProtocolURI.self, forKey: .followedBy)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'followedBy': \(error)")
                
                throw error
            }
            do {
                
                
                self.knownFollowers = try container.decodeIfPresent(KnownFollowers.self, forKey: .knownFollowers)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'knownFollowers': \(error)")
                
                throw error
            }
            do {
                
                
                self.activitySubscription = try container.decodeIfPresent(AppBskyNotificationDefs.ActivitySubscription.self, forKey: .activitySubscription)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'activitySubscription': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(muted, forKey: .muted)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(mutedByList, forKey: .mutedByList)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blockedBy, forKey: .blockedBy)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blocking, forKey: .blocking)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(blockingByList, forKey: .blockingByList)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(following, forKey: .following)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(followedBy, forKey: .followedBy)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(knownFollowers, forKey: .knownFollowers)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(activitySubscription, forKey: .activitySubscription)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = muted {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = mutedByList {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = blockedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = blocking {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = blockingByList {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = following {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = followedBy {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = knownFollowers {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = activitySubscription {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if muted != other.muted {
                return false
            }
            
            
            
            
            if mutedByList != other.mutedByList {
                return false
            }
            
            
            
            
            if blockedBy != other.blockedBy {
                return false
            }
            
            
            
            
            if blocking != other.blocking {
                return false
            }
            
            
            
            
            if blockingByList != other.blockingByList {
                return false
            }
            
            
            
            
            if following != other.following {
                return false
            }
            
            
            
            
            if followedBy != other.followedBy {
                return false
            }
            
            
            
            
            if knownFollowers != other.knownFollowers {
                return false
            }
            
            
            
            
            if activitySubscription != other.activitySubscription {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = muted {
                // Encode optional property even if it's an empty array for CBOR
                
                let mutedValue = try value.toCBORValue()
                map = map.adding(key: "muted", value: mutedValue)
            }
            
            
            
            
            
            if let value = mutedByList {
                // Encode optional property even if it's an empty array for CBOR
                
                let mutedByListValue = try value.toCBORValue()
                map = map.adding(key: "mutedByList", value: mutedByListValue)
            }
            
            
            
            
            
            if let value = blockedBy {
                // Encode optional property even if it's an empty array for CBOR
                
                let blockedByValue = try value.toCBORValue()
                map = map.adding(key: "blockedBy", value: blockedByValue)
            }
            
            
            
            
            
            if let value = blocking {
                // Encode optional property even if it's an empty array for CBOR
                
                let blockingValue = try value.toCBORValue()
                map = map.adding(key: "blocking", value: blockingValue)
            }
            
            
            
            
            
            if let value = blockingByList {
                // Encode optional property even if it's an empty array for CBOR
                
                let blockingByListValue = try value.toCBORValue()
                map = map.adding(key: "blockingByList", value: blockingByListValue)
            }
            
            
            
            
            
            if let value = following {
                // Encode optional property even if it's an empty array for CBOR
                
                let followingValue = try value.toCBORValue()
                map = map.adding(key: "following", value: followingValue)
            }
            
            
            
            
            
            if let value = followedBy {
                // Encode optional property even if it's an empty array for CBOR
                
                let followedByValue = try value.toCBORValue()
                map = map.adding(key: "followedBy", value: followedByValue)
            }
            
            
            
            
            
            if let value = knownFollowers {
                // Encode optional property even if it's an empty array for CBOR
                
                let knownFollowersValue = try value.toCBORValue()
                map = map.adding(key: "knownFollowers", value: knownFollowersValue)
            }
            
            
            
            
            
            if let value = activitySubscription {
                // Encode optional property even if it's an empty array for CBOR
                
                let activitySubscriptionValue = try value.toCBORValue()
                map = map.adding(key: "activitySubscription", value: activitySubscriptionValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case muted
            case mutedByList
            case blockedBy
            case blocking
            case blockingByList
            case following
            case followedBy
            case knownFollowers
            case activitySubscription
        }
    }
        
public struct KnownFollowers: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#knownFollowers"
            public let count: Int
            // Boxed to break circular reference
            private let _followers: IndirectBox<[ProfileViewBasic]>
            public var followers: [ProfileViewBasic] {
                
                _followers.value
            }

        // Standard initializer
        public init(
            count: Int, followers: [ProfileViewBasic]
        ) {
            
            self.count = count
            
            self._followers = IndirectBox(followers)
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.count = try container.decode(Int.self, forKey: .count)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'count': \(error)")
                
                throw error
            }
            do {
                
                
                let decoded = try container.decode([ProfileViewBasic].self, forKey: .followers)
                self._followers = IndirectBox(decoded)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'followers': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(count, forKey: .count)
            
            
            
            
            // Encode boxed property
            try container.encode(_followers.value, forKey: .followers)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(count)
            hasher.combine(_followers.value)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.count != other.count {
                return false
            }
            
            
            
            
            if _followers.value != other._followers.value {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let countValue = try count.toCBORValue()
            map = map.adding(key: "count", value: countValue)
            
            
            
            
            
            // Encode boxed property for CBOR
            
            let followersValue = try _followers.value.toCBORValue()
            map = map.adding(key: "followers", value: followersValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case count
            case followers
        }
    }
        
public struct VerificationState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#verificationState"
            public let verifications: [VerificationView]
            public let verifiedStatus: String
            public let trustedVerifierStatus: String

        // Standard initializer
        public init(
            verifications: [VerificationView], verifiedStatus: String, trustedVerifierStatus: String
        ) {
            
            self.verifications = verifications
            self.verifiedStatus = verifiedStatus
            self.trustedVerifierStatus = trustedVerifierStatus
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.verifications = try container.decode([VerificationView].self, forKey: .verifications)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'verifications': \(error)")
                
                throw error
            }
            do {
                
                
                self.verifiedStatus = try container.decode(String.self, forKey: .verifiedStatus)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'verifiedStatus': \(error)")
                
                throw error
            }
            do {
                
                
                self.trustedVerifierStatus = try container.decode(String.self, forKey: .trustedVerifierStatus)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'trustedVerifierStatus': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(verifications, forKey: .verifications)
            
            
            
            
            try container.encode(verifiedStatus, forKey: .verifiedStatus)
            
            
            
            
            try container.encode(trustedVerifierStatus, forKey: .trustedVerifierStatus)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(verifications)
            hasher.combine(verifiedStatus)
            hasher.combine(trustedVerifierStatus)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.verifications != other.verifications {
                return false
            }
            
            
            
            
            if self.verifiedStatus != other.verifiedStatus {
                return false
            }
            
            
            
            
            if self.trustedVerifierStatus != other.trustedVerifierStatus {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let verificationsValue = try verifications.toCBORValue()
            map = map.adding(key: "verifications", value: verificationsValue)
            
            
            
            
            
            
            let verifiedStatusValue = try verifiedStatus.toCBORValue()
            map = map.adding(key: "verifiedStatus", value: verifiedStatusValue)
            
            
            
            
            
            
            let trustedVerifierStatusValue = try trustedVerifierStatus.toCBORValue()
            map = map.adding(key: "trustedVerifierStatus", value: trustedVerifierStatusValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case verifications
            case verifiedStatus
            case trustedVerifierStatus
        }
    }
        
public struct VerificationView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#verificationView"
            public let issuer: DID
            public let uri: ATProtocolURI
            public let isValid: Bool
            public let createdAt: ATProtocolDate

        // Standard initializer
        public init(
            issuer: DID, uri: ATProtocolURI, isValid: Bool, createdAt: ATProtocolDate
        ) {
            
            self.issuer = issuer
            self.uri = uri
            self.isValid = isValid
            self.createdAt = createdAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.issuer = try container.decode(DID.self, forKey: .issuer)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'issuer': \(error)")
                
                throw error
            }
            do {
                
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'uri': \(error)")
                
                throw error
            }
            do {
                
                
                self.isValid = try container.decode(Bool.self, forKey: .isValid)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'isValid': \(error)")
                
                throw error
            }
            do {
                
                
                self.createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'createdAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(issuer, forKey: .issuer)
            
            
            
            
            try container.encode(uri, forKey: .uri)
            
            
            
            
            try container.encode(isValid, forKey: .isValid)
            
            
            
            
            try container.encode(createdAt, forKey: .createdAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(issuer)
            hasher.combine(uri)
            hasher.combine(isValid)
            hasher.combine(createdAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.issuer != other.issuer {
                return false
            }
            
            
            
            
            if self.uri != other.uri {
                return false
            }
            
            
            
            
            if self.isValid != other.isValid {
                return false
            }
            
            
            
            
            if self.createdAt != other.createdAt {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let issuerValue = try issuer.toCBORValue()
            map = map.adding(key: "issuer", value: issuerValue)
            
            
            
            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            
            
            let isValidValue = try isValid.toCBORValue()
            map = map.adding(key: "isValid", value: isValidValue)
            
            
            
            
            
            
            let createdAtValue = try createdAt.toCBORValue()
            map = map.adding(key: "createdAt", value: createdAtValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case issuer
            case uri
            case isValid
            case createdAt
        }
    }
        
public struct AdultContentPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#adultContentPref"
            public let enabled: Bool

        // Standard initializer
        public init(
            enabled: Bool
        ) {
            
            self.enabled = enabled
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.enabled = try container.decode(Bool.self, forKey: .enabled)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'enabled': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(enabled, forKey: .enabled)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(enabled)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.enabled != other.enabled {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let enabledValue = try enabled.toCBORValue()
            map = map.adding(key: "enabled", value: enabledValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case enabled
        }
    }
        
public struct ContentLabelPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#contentLabelPref"
            public let labelerDid: DID?
            public let label: String
            public let visibility: String

        // Standard initializer
        public init(
            labelerDid: DID?, label: String, visibility: String
        ) {
            
            self.labelerDid = labelerDid
            self.label = label
            self.visibility = visibility
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.labelerDid = try container.decodeIfPresent(DID.self, forKey: .labelerDid)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'labelerDid': \(error)")
                
                throw error
            }
            do {
                
                
                self.label = try container.decode(String.self, forKey: .label)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'label': \(error)")
                
                throw error
            }
            do {
                
                
                self.visibility = try container.decode(String.self, forKey: .visibility)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'visibility': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labelerDid, forKey: .labelerDid)
            
            
            
            
            try container.encode(label, forKey: .label)
            
            
            
            
            try container.encode(visibility, forKey: .visibility)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = labelerDid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(label)
            hasher.combine(visibility)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if labelerDid != other.labelerDid {
                return false
            }
            
            
            
            
            if self.label != other.label {
                return false
            }
            
            
            
            
            if self.visibility != other.visibility {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = labelerDid {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelerDidValue = try value.toCBORValue()
                map = map.adding(key: "labelerDid", value: labelerDidValue)
            }
            
            
            
            
            
            
            let labelValue = try label.toCBORValue()
            map = map.adding(key: "label", value: labelValue)
            
            
            
            
            
            
            let visibilityValue = try visibility.toCBORValue()
            map = map.adding(key: "visibility", value: visibilityValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case labelerDid
            case label
            case visibility
        }
    }
        
public struct SavedFeed: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#savedFeed"
            public let id: String
            public let type: String
            public let value: String
            public let pinned: Bool

        // Standard initializer
        public init(
            id: String, type: String, value: String, pinned: Bool
        ) {
            
            self.id = id
            self.type = type
            self.value = value
            self.pinned = pinned
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decode(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.type = try container.decode(String.self, forKey: .type)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'type': \(error)")
                
                throw error
            }
            do {
                
                
                self.value = try container.decode(String.self, forKey: .value)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'value': \(error)")
                
                throw error
            }
            do {
                
                
                self.pinned = try container.decode(Bool.self, forKey: .pinned)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'pinned': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(id, forKey: .id)
            
            
            
            
            try container.encode(type, forKey: .type)
            
            
            
            
            try container.encode(value, forKey: .value)
            
            
            
            
            try container.encode(pinned, forKey: .pinned)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(type)
            hasher.combine(value)
            hasher.combine(pinned)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.id != other.id {
                return false
            }
            
            
            
            
            if self.type != other.type {
                return false
            }
            
            
            
            
            if self.value != other.value {
                return false
            }
            
            
            
            
            if self.pinned != other.pinned {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            
            
            
            let typeValue = try type.toCBORValue()
            map = map.adding(key: "type", value: typeValue)
            
            
            
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            
            
            
            
            
            let pinnedValue = try pinned.toCBORValue()
            map = map.adding(key: "pinned", value: pinnedValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case type
            case value
            case pinned
        }
    }
        
public struct SavedFeedsPrefV2: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#savedFeedsPrefV2"
            public let items: [AppBskyActorDefs.SavedFeed]

        // Standard initializer
        public init(
            items: [AppBskyActorDefs.SavedFeed]
        ) {
            
            self.items = items
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.items = try container.decode([AppBskyActorDefs.SavedFeed].self, forKey: .items)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'items': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(items, forKey: .items)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(items)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.items != other.items {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case items
        }
    }
        
public struct SavedFeedsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#savedFeedsPref"
            public let pinned: [ATProtocolURI]
            public let saved: [ATProtocolURI]
            public let timelineIndex: Int?

        // Standard initializer
        public init(
            pinned: [ATProtocolURI], saved: [ATProtocolURI], timelineIndex: Int?
        ) {
            
            self.pinned = pinned
            self.saved = saved
            self.timelineIndex = timelineIndex
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.pinned = try container.decode([ATProtocolURI].self, forKey: .pinned)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'pinned': \(error)")
                
                throw error
            }
            do {
                
                
                self.saved = try container.decode([ATProtocolURI].self, forKey: .saved)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'saved': \(error)")
                
                throw error
            }
            do {
                
                
                self.timelineIndex = try container.decodeIfPresent(Int.self, forKey: .timelineIndex)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'timelineIndex': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(pinned, forKey: .pinned)
            
            
            
            
            try container.encode(saved, forKey: .saved)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(timelineIndex, forKey: .timelineIndex)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(pinned)
            hasher.combine(saved)
            if let value = timelineIndex {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.pinned != other.pinned {
                return false
            }
            
            
            
            
            if self.saved != other.saved {
                return false
            }
            
            
            
            
            if timelineIndex != other.timelineIndex {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let pinnedValue = try pinned.toCBORValue()
            map = map.adding(key: "pinned", value: pinnedValue)
            
            
            
            
            
            
            let savedValue = try saved.toCBORValue()
            map = map.adding(key: "saved", value: savedValue)
            
            
            
            
            
            if let value = timelineIndex {
                // Encode optional property even if it's an empty array for CBOR
                
                let timelineIndexValue = try value.toCBORValue()
                map = map.adding(key: "timelineIndex", value: timelineIndexValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case pinned
            case saved
            case timelineIndex
        }
    }
        
public struct PersonalDetailsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#personalDetailsPref"
            public let birthDate: ATProtocolDate?

        // Standard initializer
        public init(
            birthDate: ATProtocolDate?
        ) {
            
            self.birthDate = birthDate
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.birthDate = try container.decodeIfPresent(ATProtocolDate.self, forKey: .birthDate)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'birthDate': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(birthDate, forKey: .birthDate)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = birthDate {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if birthDate != other.birthDate {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = birthDate {
                // Encode optional property even if it's an empty array for CBOR
                
                let birthDateValue = try value.toCBORValue()
                map = map.adding(key: "birthDate", value: birthDateValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case birthDate
        }
    }
        
public struct FeedViewPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#feedViewPref"
            public let feed: String
            public let hideReplies: Bool?
            public let hideRepliesByUnfollowed: Bool?
            public let hideRepliesByLikeCount: Int?
            public let hideReposts: Bool?
            public let hideQuotePosts: Bool?

        // Standard initializer
        public init(
            feed: String, hideReplies: Bool?, hideRepliesByUnfollowed: Bool?, hideRepliesByLikeCount: Int?, hideReposts: Bool?, hideQuotePosts: Bool?
        ) {
            
            self.feed = feed
            self.hideReplies = hideReplies
            self.hideRepliesByUnfollowed = hideRepliesByUnfollowed
            self.hideRepliesByLikeCount = hideRepliesByLikeCount
            self.hideReposts = hideReposts
            self.hideQuotePosts = hideQuotePosts
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.feed = try container.decode(String.self, forKey: .feed)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'feed': \(error)")
                
                throw error
            }
            do {
                
                
                self.hideReplies = try container.decodeIfPresent(Bool.self, forKey: .hideReplies)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideReplies': \(error)")
                
                throw error
            }
            do {
                
                
                self.hideRepliesByUnfollowed = try container.decodeIfPresent(Bool.self, forKey: .hideRepliesByUnfollowed)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideRepliesByUnfollowed': \(error)")
                
                throw error
            }
            do {
                
                
                self.hideRepliesByLikeCount = try container.decodeIfPresent(Int.self, forKey: .hideRepliesByLikeCount)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideRepliesByLikeCount': \(error)")
                
                throw error
            }
            do {
                
                
                self.hideReposts = try container.decodeIfPresent(Bool.self, forKey: .hideReposts)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideReposts': \(error)")
                
                throw error
            }
            do {
                
                
                self.hideQuotePosts = try container.decodeIfPresent(Bool.self, forKey: .hideQuotePosts)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideQuotePosts': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(feed, forKey: .feed)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideReplies, forKey: .hideReplies)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideRepliesByUnfollowed, forKey: .hideRepliesByUnfollowed)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideRepliesByLikeCount, forKey: .hideRepliesByLikeCount)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideReposts, forKey: .hideReposts)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideQuotePosts, forKey: .hideQuotePosts)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(feed)
            if let value = hideReplies {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = hideRepliesByUnfollowed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = hideRepliesByLikeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = hideReposts {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = hideQuotePosts {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.feed != other.feed {
                return false
            }
            
            
            
            
            if hideReplies != other.hideReplies {
                return false
            }
            
            
            
            
            if hideRepliesByUnfollowed != other.hideRepliesByUnfollowed {
                return false
            }
            
            
            
            
            if hideRepliesByLikeCount != other.hideRepliesByLikeCount {
                return false
            }
            
            
            
            
            if hideReposts != other.hideReposts {
                return false
            }
            
            
            
            
            if hideQuotePosts != other.hideQuotePosts {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let feedValue = try feed.toCBORValue()
            map = map.adding(key: "feed", value: feedValue)
            
            
            
            
            
            if let value = hideReplies {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideRepliesValue = try value.toCBORValue()
                map = map.adding(key: "hideReplies", value: hideRepliesValue)
            }
            
            
            
            
            
            if let value = hideRepliesByUnfollowed {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideRepliesByUnfollowedValue = try value.toCBORValue()
                map = map.adding(key: "hideRepliesByUnfollowed", value: hideRepliesByUnfollowedValue)
            }
            
            
            
            
            
            if let value = hideRepliesByLikeCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideRepliesByLikeCountValue = try value.toCBORValue()
                map = map.adding(key: "hideRepliesByLikeCount", value: hideRepliesByLikeCountValue)
            }
            
            
            
            
            
            if let value = hideReposts {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideRepostsValue = try value.toCBORValue()
                map = map.adding(key: "hideReposts", value: hideRepostsValue)
            }
            
            
            
            
            
            if let value = hideQuotePosts {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideQuotePostsValue = try value.toCBORValue()
                map = map.adding(key: "hideQuotePosts", value: hideQuotePostsValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case feed
            case hideReplies
            case hideRepliesByUnfollowed
            case hideRepliesByLikeCount
            case hideReposts
            case hideQuotePosts
        }
    }
        
public struct ThreadViewPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#threadViewPref"
            public let sort: String?
            public let prioritizeFollowedUsers: Bool?

        // Standard initializer
        public init(
            sort: String?, prioritizeFollowedUsers: Bool?
        ) {
            
            self.sort = sort
            self.prioritizeFollowedUsers = prioritizeFollowedUsers
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.sort = try container.decodeIfPresent(String.self, forKey: .sort)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'sort': \(error)")
                
                throw error
            }
            do {
                
                
                self.prioritizeFollowedUsers = try container.decodeIfPresent(Bool.self, forKey: .prioritizeFollowedUsers)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'prioritizeFollowedUsers': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(sort, forKey: .sort)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(prioritizeFollowedUsers, forKey: .prioritizeFollowedUsers)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = sort {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = prioritizeFollowedUsers {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if sort != other.sort {
                return false
            }
            
            
            
            
            if prioritizeFollowedUsers != other.prioritizeFollowedUsers {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = sort {
                // Encode optional property even if it's an empty array for CBOR
                
                let sortValue = try value.toCBORValue()
                map = map.adding(key: "sort", value: sortValue)
            }
            
            
            
            
            
            if let value = prioritizeFollowedUsers {
                // Encode optional property even if it's an empty array for CBOR
                
                let prioritizeFollowedUsersValue = try value.toCBORValue()
                map = map.adding(key: "prioritizeFollowedUsers", value: prioritizeFollowedUsersValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case sort
            case prioritizeFollowedUsers
        }
    }
        
public struct InterestsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#interestsPref"
            public let tags: [String]

        // Standard initializer
        public init(
            tags: [String]
        ) {
            
            self.tags = tags
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.tags = try container.decode([String].self, forKey: .tags)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'tags': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(tags, forKey: .tags)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(tags)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.tags != other.tags {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let tagsValue = try tags.toCBORValue()
            map = map.adding(key: "tags", value: tagsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case tags
        }
    }
        
public struct MutedWord: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#mutedWord"
            public let id: String?
            public let value: String
            public let targets: [AppBskyActorDefs.MutedWordTarget]
            public let actorTarget: String?
            public let expiresAt: ATProtocolDate?

        // Standard initializer
        public init(
            id: String?, value: String, targets: [AppBskyActorDefs.MutedWordTarget], actorTarget: String?, expiresAt: ATProtocolDate?
        ) {
            
            self.id = id
            self.value = value
            self.targets = targets
            self.actorTarget = actorTarget
            self.expiresAt = expiresAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decodeIfPresent(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.value = try container.decode(String.self, forKey: .value)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'value': \(error)")
                
                throw error
            }
            do {
                
                
                self.targets = try container.decode([AppBskyActorDefs.MutedWordTarget].self, forKey: .targets)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'targets': \(error)")
                
                throw error
            }
            do {
                
                
                self.actorTarget = try container.decodeIfPresent(String.self, forKey: .actorTarget)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'actorTarget': \(error)")
                
                throw error
            }
            do {
                
                
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'expiresAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(id, forKey: .id)
            
            
            
            
            try container.encode(value, forKey: .value)
            
            
            
            
            try container.encode(targets, forKey: .targets)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(actorTarget, forKey: .actorTarget)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = id {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(value)
            hasher.combine(targets)
            if let value = actorTarget {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = expiresAt {
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
            
            
            
            
            if self.value != other.value {
                return false
            }
            
            
            
            
            if self.targets != other.targets {
                return false
            }
            
            
            
            
            if actorTarget != other.actorTarget {
                return false
            }
            
            
            
            
            if expiresAt != other.expiresAt {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = id {
                // Encode optional property even if it's an empty array for CBOR
                
                let idValue = try value.toCBORValue()
                map = map.adding(key: "id", value: idValue)
            }
            
            
            
            
            
            
            let valueValue = try value.toCBORValue()
            map = map.adding(key: "value", value: valueValue)
            
            
            
            
            
            
            let targetsValue = try targets.toCBORValue()
            map = map.adding(key: "targets", value: targetsValue)
            
            
            
            
            
            if let value = actorTarget {
                // Encode optional property even if it's an empty array for CBOR
                
                let actorTargetValue = try value.toCBORValue()
                map = map.adding(key: "actorTarget", value: actorTargetValue)
            }
            
            
            
            
            
            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case value
            case targets
            case actorTarget
            case expiresAt
        }
    }
        
public struct MutedWordsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#mutedWordsPref"
            public let items: [AppBskyActorDefs.MutedWord]

        // Standard initializer
        public init(
            items: [AppBskyActorDefs.MutedWord]
        ) {
            
            self.items = items
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.items = try container.decode([AppBskyActorDefs.MutedWord].self, forKey: .items)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'items': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(items, forKey: .items)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(items)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.items != other.items {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case items
        }
    }
        
public struct HiddenPostsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#hiddenPostsPref"
            public let items: [ATProtocolURI]

        // Standard initializer
        public init(
            items: [ATProtocolURI]
        ) {
            
            self.items = items
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.items = try container.decode([ATProtocolURI].self, forKey: .items)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'items': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(items, forKey: .items)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(items)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.items != other.items {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let itemsValue = try items.toCBORValue()
            map = map.adding(key: "items", value: itemsValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case items
        }
    }
        
public struct LabelersPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#labelersPref"
            public let labelers: [LabelerPrefItem]

        // Standard initializer
        public init(
            labelers: [LabelerPrefItem]
        ) {
            
            self.labelers = labelers
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.labelers = try container.decode([LabelerPrefItem].self, forKey: .labelers)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'labelers': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(labelers, forKey: .labelers)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(labelers)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.labelers != other.labelers {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let labelersValue = try labelers.toCBORValue()
            map = map.adding(key: "labelers", value: labelersValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case labelers
        }
    }
        
public struct LabelerPrefItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#labelerPrefItem"
            public let did: DID

        // Standard initializer
        public init(
            did: DID
        ) {
            
            self.did = did
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.did = try container.decode(DID.self, forKey: .did)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'did': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(did, forKey: .did)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.did != other.did {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }
        
public struct BskyAppStatePref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#bskyAppStatePref"
            public let activeProgressGuide: BskyAppProgressGuide?
            public let queuedNudges: [String]?
            public let nuxs: [AppBskyActorDefs.Nux]?

        // Standard initializer
        public init(
            activeProgressGuide: BskyAppProgressGuide?, queuedNudges: [String]?, nuxs: [AppBskyActorDefs.Nux]?
        ) {
            
            self.activeProgressGuide = activeProgressGuide
            self.queuedNudges = queuedNudges
            self.nuxs = nuxs
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.activeProgressGuide = try container.decodeIfPresent(BskyAppProgressGuide.self, forKey: .activeProgressGuide)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'activeProgressGuide': \(error)")
                
                throw error
            }
            do {
                
                
                self.queuedNudges = try container.decodeIfPresent([String].self, forKey: .queuedNudges)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'queuedNudges': \(error)")
                
                throw error
            }
            do {
                
                
                self.nuxs = try container.decodeIfPresent([AppBskyActorDefs.Nux].self, forKey: .nuxs)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'nuxs': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(activeProgressGuide, forKey: .activeProgressGuide)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(queuedNudges, forKey: .queuedNudges)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(nuxs, forKey: .nuxs)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = activeProgressGuide {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = queuedNudges {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = nuxs {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if activeProgressGuide != other.activeProgressGuide {
                return false
            }
            
            
            
            
            if queuedNudges != other.queuedNudges {
                return false
            }
            
            
            
            
            if nuxs != other.nuxs {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = activeProgressGuide {
                // Encode optional property even if it's an empty array for CBOR
                
                let activeProgressGuideValue = try value.toCBORValue()
                map = map.adding(key: "activeProgressGuide", value: activeProgressGuideValue)
            }
            
            
            
            
            
            if let value = queuedNudges {
                // Encode optional property even if it's an empty array for CBOR
                
                let queuedNudgesValue = try value.toCBORValue()
                map = map.adding(key: "queuedNudges", value: queuedNudgesValue)
            }
            
            
            
            
            
            if let value = nuxs {
                // Encode optional property even if it's an empty array for CBOR
                
                let nuxsValue = try value.toCBORValue()
                map = map.adding(key: "nuxs", value: nuxsValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case activeProgressGuide
            case queuedNudges
            case nuxs
        }
    }
        
public struct BskyAppProgressGuide: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#bskyAppProgressGuide"
            public let guide: String

        // Standard initializer
        public init(
            guide: String
        ) {
            
            self.guide = guide
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.guide = try container.decode(String.self, forKey: .guide)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'guide': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(guide, forKey: .guide)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(guide)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.guide != other.guide {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let guideValue = try guide.toCBORValue()
            map = map.adding(key: "guide", value: guideValue)
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case guide
        }
    }
        
public struct Nux: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#nux"
            public let id: String
            public let completed: Bool
            public let data: String?
            public let expiresAt: ATProtocolDate?

        // Standard initializer
        public init(
            id: String, completed: Bool, data: String?, expiresAt: ATProtocolDate?
        ) {
            
            self.id = id
            self.completed = completed
            self.data = data
            self.expiresAt = expiresAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.id = try container.decode(String.self, forKey: .id)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'id': \(error)")
                
                throw error
            }
            do {
                
                
                self.completed = try container.decode(Bool.self, forKey: .completed)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'completed': \(error)")
                
                throw error
            }
            do {
                
                
                self.data = try container.decodeIfPresent(String.self, forKey: .data)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'data': \(error)")
                
                throw error
            }
            do {
                
                
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'expiresAt': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(id, forKey: .id)
            
            
            
            
            try container.encode(completed, forKey: .completed)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(data, forKey: .data)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(completed)
            if let value = data {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = expiresAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.id != other.id {
                return false
            }
            
            
            
            
            if self.completed != other.completed {
                return false
            }
            
            
            
            
            if data != other.data {
                return false
            }
            
            
            
            
            if expiresAt != other.expiresAt {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let idValue = try id.toCBORValue()
            map = map.adding(key: "id", value: idValue)
            
            
            
            
            
            
            let completedValue = try completed.toCBORValue()
            map = map.adding(key: "completed", value: completedValue)
            
            
            
            
            
            if let value = data {
                // Encode optional property even if it's an empty array for CBOR
                
                let dataValue = try value.toCBORValue()
                map = map.adding(key: "data", value: dataValue)
            }
            
            
            
            
            
            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case id
            case completed
            case data
            case expiresAt
        }
    }
        
public struct VerificationPrefs: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#verificationPrefs"
            public let hideBadges: Bool?

        // Standard initializer
        public init(
            hideBadges: Bool?
        ) {
            
            self.hideBadges = hideBadges
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.hideBadges = try container.decodeIfPresent(Bool.self, forKey: .hideBadges)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'hideBadges': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(hideBadges, forKey: .hideBadges)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = hideBadges {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if hideBadges != other.hideBadges {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = hideBadges {
                // Encode optional property even if it's an empty array for CBOR
                
                let hideBadgesValue = try value.toCBORValue()
                map = map.adding(key: "hideBadges", value: hideBadgesValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case hideBadges
        }
    }
        
public struct PostInteractionSettingsPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#postInteractionSettingsPref"
            public let threadgateAllowRules: [PostInteractionSettingsPrefThreadgateAllowRulesUnion]?
            public let postgateEmbeddingRules: [PostInteractionSettingsPrefPostgateEmbeddingRulesUnion]?

        // Standard initializer
        public init(
            threadgateAllowRules: [PostInteractionSettingsPrefThreadgateAllowRulesUnion]?, postgateEmbeddingRules: [PostInteractionSettingsPrefPostgateEmbeddingRulesUnion]?
        ) {
            
            self.threadgateAllowRules = threadgateAllowRules
            self.postgateEmbeddingRules = postgateEmbeddingRules
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.threadgateAllowRules = try container.decodeIfPresent([PostInteractionSettingsPrefThreadgateAllowRulesUnion].self, forKey: .threadgateAllowRules)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'threadgateAllowRules': \(error)")
                
                throw error
            }
            do {
                
                
                self.postgateEmbeddingRules = try container.decodeIfPresent([PostInteractionSettingsPrefPostgateEmbeddingRulesUnion].self, forKey: .postgateEmbeddingRules)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'postgateEmbeddingRules': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(threadgateAllowRules, forKey: .threadgateAllowRules)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(postgateEmbeddingRules, forKey: .postgateEmbeddingRules)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = threadgateAllowRules {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = postgateEmbeddingRules {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if threadgateAllowRules != other.threadgateAllowRules {
                return false
            }
            
            
            
            
            if postgateEmbeddingRules != other.postgateEmbeddingRules {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            if let value = threadgateAllowRules {
                // Encode optional property even if it's an empty array for CBOR
                
                let threadgateAllowRulesValue = try value.toCBORValue()
                map = map.adding(key: "threadgateAllowRules", value: threadgateAllowRulesValue)
            }
            
            
            
            
            
            if let value = postgateEmbeddingRules {
                // Encode optional property even if it's an empty array for CBOR
                
                let postgateEmbeddingRulesValue = try value.toCBORValue()
                map = map.adding(key: "postgateEmbeddingRules", value: postgateEmbeddingRulesValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case threadgateAllowRules
            case postgateEmbeddingRules
        }
    }
        
public struct StatusView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#statusView"
            public let status: String
            public let record: ATProtocolValueContainer
            public let embed: StatusViewEmbedUnion?
            public let expiresAt: ATProtocolDate?
            public let isActive: Bool?

        // Standard initializer
        public init(
            status: String, record: ATProtocolValueContainer, embed: StatusViewEmbedUnion?, expiresAt: ATProtocolDate?, isActive: Bool?
        ) {
            
            self.status = status
            self.record = record
            self.embed = embed
            self.expiresAt = expiresAt
            self.isActive = isActive
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                
                self.status = try container.decode(String.self, forKey: .status)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'status': \(error)")
                
                throw error
            }
            do {
                
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
                
            } catch {
                
                LogManager.logError("Decoding error for required property 'record': \(error)")
                
                throw error
            }
            do {
                
                
                self.embed = try container.decodeIfPresent(StatusViewEmbedUnion.self, forKey: .embed)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'embed': \(error)")
                
                throw error
            }
            do {
                
                
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'expiresAt': \(error)")
                
                throw error
            }
            do {
                
                
                self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
                
                
            } catch {
                
                LogManager.logDebug("Decoding error for optional property 'isActive': \(error)")
                
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            
            try container.encode(status, forKey: .status)
            
            
            
            
            try container.encode(record, forKey: .record)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embed, forKey: .embed)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
            
            
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(isActive, forKey: .isActive)
            
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(status)
            hasher.combine(record)
            if let value = embed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = expiresAt {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = isActive {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            
            if self.status != other.status {
                return false
            }
            
            
            
            
            if self.record != other.record {
                return false
            }
            
            
            
            
            if embed != other.embed {
                return false
            }
            
            
            
            
            if expiresAt != other.expiresAt {
                return false
            }
            
            
            
            
            if isActive != other.isActive {
                return false
            }
            
            
            return true
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            
            let statusValue = try status.toCBORValue()
            map = map.adding(key: "status", value: statusValue)
            
            
            
            
            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            
            
            if let value = embed {
                // Encode optional property even if it's an empty array for CBOR
                
                let embedValue = try value.toCBORValue()
                map = map.adding(key: "embed", value: embedValue)
            }
            
            
            
            
            
            if let value = expiresAt {
                // Encode optional property even if it's an empty array for CBOR
                
                let expiresAtValue = try value.toCBORValue()
                map = map.adding(key: "expiresAt", value: expiresAtValue)
            }
            
            
            
            
            
            if let value = isActive {
                // Encode optional property even if it's an empty array for CBOR
                
                let isActiveValue = try value.toCBORValue()
                map = map.adding(key: "isActive", value: isActiveValue)
            }
            
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case status
            case record
            case embed
            case expiresAt
            case isActive
        }
    }


// Union Array Type


public struct Preferences: Codable, ATProtocolCodable, ATProtocolValue {
    public let items: [PreferencesForUnionArray]
    
    public init(items: [PreferencesForUnionArray]) {
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items = [PreferencesForUnionArray]()
        while !container.isAtEnd {
            let item = try container.decode(PreferencesForUnionArray.self)
            items.append(item)
        }
        self.items = items
    }

    public func encode(to encoder: Encoder) throws {
        // Encode the array regardless of whether it's empty
        var container = encoder.unkeyedContainer()
        for item in items {
            try container.encode(item)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Preferences else { return false }
        
        if self.items != other.items {
            return false
        }

        return true
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // For union arrays, we need to encode each item while preserving its order
        var itemsArray = [Any]()
        
        for item in items {
            let itemValue = try item.toCBORValue()
            itemsArray.append(itemValue)
        }
        
        return itemsArray
    }

}


public enum PreferencesForUnionArray: Codable, ATProtocolCodable, ATProtocolValue {
    case adultContentPref(AdultContentPref)
    case contentLabelPref(ContentLabelPref)
    case savedFeedsPref(SavedFeedsPref)
    case savedFeedsPrefV2(SavedFeedsPrefV2)
    case personalDetailsPref(PersonalDetailsPref)
    case feedViewPref(FeedViewPref)
    case threadViewPref(ThreadViewPref)
    case interestsPref(InterestsPref)
    case mutedWordsPref(MutedWordsPref)
    case hiddenPostsPref(HiddenPostsPref)
    case bskyAppStatePref(BskyAppStatePref)
    case labelersPref(LabelersPref)
    case postInteractionSettingsPref(PostInteractionSettingsPref)
    case verificationPrefs(VerificationPrefs)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AdultContentPref) {
        self = .adultContentPref(value)
    }
    public init(_ value: ContentLabelPref) {
        self = .contentLabelPref(value)
    }
    public init(_ value: SavedFeedsPref) {
        self = .savedFeedsPref(value)
    }
    public init(_ value: SavedFeedsPrefV2) {
        self = .savedFeedsPrefV2(value)
    }
    public init(_ value: PersonalDetailsPref) {
        self = .personalDetailsPref(value)
    }
    public init(_ value: FeedViewPref) {
        self = .feedViewPref(value)
    }
    public init(_ value: ThreadViewPref) {
        self = .threadViewPref(value)
    }
    public init(_ value: InterestsPref) {
        self = .interestsPref(value)
    }
    public init(_ value: MutedWordsPref) {
        self = .mutedWordsPref(value)
    }
    public init(_ value: HiddenPostsPref) {
        self = .hiddenPostsPref(value)
    }
    public init(_ value: BskyAppStatePref) {
        self = .bskyAppStatePref(value)
    }
    public init(_ value: LabelersPref) {
        self = .labelersPref(value)
    }
    public init(_ value: PostInteractionSettingsPref) {
        self = .postInteractionSettingsPref(value)
    }
    public init(_ value: VerificationPrefs) {
        self = .verificationPrefs(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.actor.defs#adultContentPref":
            let value = try AdultContentPref(from: decoder)
            self = .adultContentPref(value)
        case "app.bsky.actor.defs#contentLabelPref":
            let value = try ContentLabelPref(from: decoder)
            self = .contentLabelPref(value)
        case "app.bsky.actor.defs#savedFeedsPref":
            let value = try SavedFeedsPref(from: decoder)
            self = .savedFeedsPref(value)
        case "app.bsky.actor.defs#savedFeedsPrefV2":
            let value = try SavedFeedsPrefV2(from: decoder)
            self = .savedFeedsPrefV2(value)
        case "app.bsky.actor.defs#personalDetailsPref":
            let value = try PersonalDetailsPref(from: decoder)
            self = .personalDetailsPref(value)
        case "app.bsky.actor.defs#feedViewPref":
            let value = try FeedViewPref(from: decoder)
            self = .feedViewPref(value)
        case "app.bsky.actor.defs#threadViewPref":
            let value = try ThreadViewPref(from: decoder)
            self = .threadViewPref(value)
        case "app.bsky.actor.defs#interestsPref":
            let value = try InterestsPref(from: decoder)
            self = .interestsPref(value)
        case "app.bsky.actor.defs#mutedWordsPref":
            let value = try MutedWordsPref(from: decoder)
            self = .mutedWordsPref(value)
        case "app.bsky.actor.defs#hiddenPostsPref":
            let value = try HiddenPostsPref(from: decoder)
            self = .hiddenPostsPref(value)
        case "app.bsky.actor.defs#bskyAppStatePref":
            let value = try BskyAppStatePref(from: decoder)
            self = .bskyAppStatePref(value)
        case "app.bsky.actor.defs#labelersPref":
            let value = try LabelersPref(from: decoder)
            self = .labelersPref(value)
        case "app.bsky.actor.defs#postInteractionSettingsPref":
            let value = try PostInteractionSettingsPref(from: decoder)
            self = .postInteractionSettingsPref(value)
        case "app.bsky.actor.defs#verificationPrefs":
            let value = try VerificationPrefs(from: decoder)
            self = .verificationPrefs(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .adultContentPref(let value):
            try container.encode("app.bsky.actor.defs#adultContentPref", forKey: .type)
            try value.encode(to: encoder)
        case .contentLabelPref(let value):
            try container.encode("app.bsky.actor.defs#contentLabelPref", forKey: .type)
            try value.encode(to: encoder)
        case .savedFeedsPref(let value):
            try container.encode("app.bsky.actor.defs#savedFeedsPref", forKey: .type)
            try value.encode(to: encoder)
        case .savedFeedsPrefV2(let value):
            try container.encode("app.bsky.actor.defs#savedFeedsPrefV2", forKey: .type)
            try value.encode(to: encoder)
        case .personalDetailsPref(let value):
            try container.encode("app.bsky.actor.defs#personalDetailsPref", forKey: .type)
            try value.encode(to: encoder)
        case .feedViewPref(let value):
            try container.encode("app.bsky.actor.defs#feedViewPref", forKey: .type)
            try value.encode(to: encoder)
        case .threadViewPref(let value):
            try container.encode("app.bsky.actor.defs#threadViewPref", forKey: .type)
            try value.encode(to: encoder)
        case .interestsPref(let value):
            try container.encode("app.bsky.actor.defs#interestsPref", forKey: .type)
            try value.encode(to: encoder)
        case .mutedWordsPref(let value):
            try container.encode("app.bsky.actor.defs#mutedWordsPref", forKey: .type)
            try value.encode(to: encoder)
        case .hiddenPostsPref(let value):
            try container.encode("app.bsky.actor.defs#hiddenPostsPref", forKey: .type)
            try value.encode(to: encoder)
        case .bskyAppStatePref(let value):
            try container.encode("app.bsky.actor.defs#bskyAppStatePref", forKey: .type)
            try value.encode(to: encoder)
        case .labelersPref(let value):
            try container.encode("app.bsky.actor.defs#labelersPref", forKey: .type)
            try value.encode(to: encoder)
        case .postInteractionSettingsPref(let value):
            try container.encode("app.bsky.actor.defs#postInteractionSettingsPref", forKey: .type)
            try value.encode(to: encoder)
        case .verificationPrefs(let value):
            try container.encode("app.bsky.actor.defs#verificationPrefs", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .adultContentPref(let value):
            hasher.combine("app.bsky.actor.defs#adultContentPref")
            hasher.combine(value)
        case .contentLabelPref(let value):
            hasher.combine("app.bsky.actor.defs#contentLabelPref")
            hasher.combine(value)
        case .savedFeedsPref(let value):
            hasher.combine("app.bsky.actor.defs#savedFeedsPref")
            hasher.combine(value)
        case .savedFeedsPrefV2(let value):
            hasher.combine("app.bsky.actor.defs#savedFeedsPrefV2")
            hasher.combine(value)
        case .personalDetailsPref(let value):
            hasher.combine("app.bsky.actor.defs#personalDetailsPref")
            hasher.combine(value)
        case .feedViewPref(let value):
            hasher.combine("app.bsky.actor.defs#feedViewPref")
            hasher.combine(value)
        case .threadViewPref(let value):
            hasher.combine("app.bsky.actor.defs#threadViewPref")
            hasher.combine(value)
        case .interestsPref(let value):
            hasher.combine("app.bsky.actor.defs#interestsPref")
            hasher.combine(value)
        case .mutedWordsPref(let value):
            hasher.combine("app.bsky.actor.defs#mutedWordsPref")
            hasher.combine(value)
        case .hiddenPostsPref(let value):
            hasher.combine("app.bsky.actor.defs#hiddenPostsPref")
            hasher.combine(value)
        case .bskyAppStatePref(let value):
            hasher.combine("app.bsky.actor.defs#bskyAppStatePref")
            hasher.combine(value)
        case .labelersPref(let value):
            hasher.combine("app.bsky.actor.defs#labelersPref")
            hasher.combine(value)
        case .postInteractionSettingsPref(let value):
            hasher.combine("app.bsky.actor.defs#postInteractionSettingsPref")
            hasher.combine(value)
        case .verificationPrefs(let value):
            hasher.combine("app.bsky.actor.defs#verificationPrefs")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? PreferencesForUnionArray else { return false }

        switch (self, otherValue) {
        case (.adultContentPref(let selfValue), 
              .adultContentPref(let otherValue)):
            return selfValue == otherValue
        case (.contentLabelPref(let selfValue), 
              .contentLabelPref(let otherValue)):
            return selfValue == otherValue
        case (.savedFeedsPref(let selfValue), 
              .savedFeedsPref(let otherValue)):
            return selfValue == otherValue
        case (.savedFeedsPrefV2(let selfValue), 
              .savedFeedsPrefV2(let otherValue)):
            return selfValue == otherValue
        case (.personalDetailsPref(let selfValue), 
              .personalDetailsPref(let otherValue)):
            return selfValue == otherValue
        case (.feedViewPref(let selfValue), 
              .feedViewPref(let otherValue)):
            return selfValue == otherValue
        case (.threadViewPref(let selfValue), 
              .threadViewPref(let otherValue)):
            return selfValue == otherValue
        case (.interestsPref(let selfValue), 
              .interestsPref(let otherValue)):
            return selfValue == otherValue
        case (.mutedWordsPref(let selfValue), 
              .mutedWordsPref(let otherValue)):
            return selfValue == otherValue
        case (.hiddenPostsPref(let selfValue), 
              .hiddenPostsPref(let otherValue)):
            return selfValue == otherValue
        case (.bskyAppStatePref(let selfValue), 
              .bskyAppStatePref(let otherValue)):
            return selfValue == otherValue
        case (.labelersPref(let selfValue), 
              .labelersPref(let otherValue)):
            return selfValue == otherValue
        case (.postInteractionSettingsPref(let selfValue), 
              .postInteractionSettingsPref(let otherValue)):
            return selfValue == otherValue
        case (.verificationPrefs(let selfValue), 
              .verificationPrefs(let otherValue)):
            return selfValue == otherValue
        case (.unexpected(let selfValue), .unexpected(let otherValue)):
            return selfValue.isEqual(to: otherValue)
        default:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        
        switch self {
        case .adultContentPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#adultContentPref")
            
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
        case .contentLabelPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#contentLabelPref")
            
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
        case .savedFeedsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#savedFeedsPref")
            
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
        case .savedFeedsPrefV2(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#savedFeedsPrefV2")
            
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
        case .personalDetailsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#personalDetailsPref")
            
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
        case .feedViewPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#feedViewPref")
            
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
        case .threadViewPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#threadViewPref")
            
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
        case .interestsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#interestsPref")
            
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
        case .mutedWordsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#mutedWordsPref")
            
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
        case .hiddenPostsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#hiddenPostsPref")
            
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
        case .bskyAppStatePref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#bskyAppStatePref")
            
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
        case .labelersPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#labelersPref")
            
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
        case .postInteractionSettingsPref(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#postInteractionSettingsPref")
            
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
        case .verificationPrefs(let value):
            map = map.adding(key: "$type", value: "app.bsky.actor.defs#verificationPrefs")
            
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


public struct MutedWordTarget: Codable, ATProtocolCodable, ATProtocolValue {
            public let rawValue: String
            
            // Predefined constants
            // 
            public static let content = MutedWordTarget(rawValue: "content")
            // 
            public static let tag = MutedWordTarget(rawValue: "tag")
            
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
                guard let otherValue = other as? MutedWordTarget else { return false }
                return self.rawValue == otherValue.rawValue
            }
            
            // DAGCBOR encoding with field ordering
            public func toCBORValue() throws -> Any {
                // For string-based enum types, we return the raw string value directly
                return rawValue
            }
            
            // Provide allCases-like functionality
            public static var predefinedValues: [MutedWordTarget] {
                return [
                    .content,
                    .tag,
                ]
            }
        }




public enum PostInteractionSettingsPrefThreadgateAllowRulesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedThreadgateMentionRule(AppBskyFeedThreadgate.MentionRule)
    case appBskyFeedThreadgateFollowerRule(AppBskyFeedThreadgate.FollowerRule)
    case appBskyFeedThreadgateFollowingRule(AppBskyFeedThreadgate.FollowingRule)
    case appBskyFeedThreadgateListRule(AppBskyFeedThreadgate.ListRule)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyFeedThreadgate.MentionRule) {
        self = .appBskyFeedThreadgateMentionRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.FollowerRule) {
        self = .appBskyFeedThreadgateFollowerRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.FollowingRule) {
        self = .appBskyFeedThreadgateFollowingRule(value)
    }
    public init(_ value: AppBskyFeedThreadgate.ListRule) {
        self = .appBskyFeedThreadgateListRule(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.threadgate#mentionRule":
            let value = try AppBskyFeedThreadgate.MentionRule(from: decoder)
            self = .appBskyFeedThreadgateMentionRule(value)
        case "app.bsky.feed.threadgate#followerRule":
            let value = try AppBskyFeedThreadgate.FollowerRule(from: decoder)
            self = .appBskyFeedThreadgateFollowerRule(value)
        case "app.bsky.feed.threadgate#followingRule":
            let value = try AppBskyFeedThreadgate.FollowingRule(from: decoder)
            self = .appBskyFeedThreadgateFollowingRule(value)
        case "app.bsky.feed.threadgate#listRule":
            let value = try AppBskyFeedThreadgate.ListRule(from: decoder)
            self = .appBskyFeedThreadgateListRule(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            try container.encode("app.bsky.feed.threadgate#mentionRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateFollowerRule(let value):
            try container.encode("app.bsky.feed.threadgate#followerRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateFollowingRule(let value):
            try container.encode("app.bsky.feed.threadgate#followingRule", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedThreadgateListRule(let value):
            try container.encode("app.bsky.feed.threadgate#listRule", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            hasher.combine("app.bsky.feed.threadgate#mentionRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateFollowerRule(let value):
            hasher.combine("app.bsky.feed.threadgate#followerRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateFollowingRule(let value):
            hasher.combine("app.bsky.feed.threadgate#followingRule")
            hasher.combine(value)
        case .appBskyFeedThreadgateListRule(let value):
            hasher.combine("app.bsky.feed.threadgate#listRule")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: PostInteractionSettingsPrefThreadgateAllowRulesUnion, rhs: PostInteractionSettingsPrefThreadgateAllowRulesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedThreadgateMentionRule(let lhsValue),
              .appBskyFeedThreadgateMentionRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateFollowerRule(let lhsValue),
              .appBskyFeedThreadgateFollowerRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateFollowingRule(let lhsValue),
              .appBskyFeedThreadgateFollowingRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedThreadgateListRule(let lhsValue),
              .appBskyFeedThreadgateListRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? PostInteractionSettingsPrefThreadgateAllowRulesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedThreadgateMentionRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#mentionRule")
            
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
        case .appBskyFeedThreadgateFollowerRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followerRule")
            
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
        case .appBskyFeedThreadgateFollowingRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#followingRule")
            
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
        case .appBskyFeedThreadgateListRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.threadgate#listRule")
            
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




public enum PostInteractionSettingsPrefPostgateEmbeddingRulesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedPostgateDisableRule(AppBskyFeedPostgate.DisableRule)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyFeedPostgate.DisableRule) {
        self = .appBskyFeedPostgateDisableRule(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.postgate#disableRule":
            let value = try AppBskyFeedPostgate.DisableRule(from: decoder)
            self = .appBskyFeedPostgateDisableRule(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            try container.encode("app.bsky.feed.postgate#disableRule", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            hasher.combine("app.bsky.feed.postgate#disableRule")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: PostInteractionSettingsPrefPostgateEmbeddingRulesUnion, rhs: PostInteractionSettingsPrefPostgateEmbeddingRulesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedPostgateDisableRule(let lhsValue),
              .appBskyFeedPostgateDisableRule(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? PostInteractionSettingsPrefPostgateEmbeddingRulesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedPostgateDisableRule(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.postgate#disableRule")
            
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




public enum StatusViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
    case unexpected(ATProtocolValueContainer)
    public init(_ value: AppBskyEmbedExternal.View) {
        self = .appBskyEmbedExternalView(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.embed.external#view":
            let value = try AppBskyEmbedExternal.View(from: decoder)
            self = .appBskyEmbedExternalView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyEmbedExternalView(let value):
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedExternalView(let value):
            hasher.combine("app.bsky.embed.external#view")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: StatusViewEmbedUnion, rhs: StatusViewEmbedUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyEmbedExternalView(let lhsValue),
              .appBskyEmbedExternalView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? StatusViewEmbedUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyEmbedExternalView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.external#view")
            
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


                           
