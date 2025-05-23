import Foundation

// lexicon: 1, id: app.bsky.actor.defs

public struct AppBskyActorDefs {
    public static let typeIdentifier = "app.bsky.actor.defs"

    public struct ProfileViewBasic: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.actor.defs#profileViewBasic"
        public let did: DID
        public let handle: Handle
        public let displayName: String?
        public let avatar: URI?
        public let associated: ProfileAssociated?
        public let viewer: ViewerState?
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let createdAt: ATProtocolDate?
        public let verification: VerificationState?
        public let status: StatusView?

        // Standard initializer
        public init(
            did: DID, handle: Handle, displayName: String?, avatar: URI?, associated: ProfileAssociated?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, createdAt: ATProtocolDate?, verification: VerificationState?, status: StatusView?
        ) {
            self.did = did
            self.handle = handle
            self.displayName = displayName
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                displayName = try container.decodeIfPresent(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)

            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)

            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)

            } catch {
                LogManager.logError("Decoding error for property 'verification': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(StatusView.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
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
            did: DID, handle: Handle, displayName: String?, description: String?, avatar: URI?, associated: ProfileAssociated?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, verification: VerificationState?, status: StatusView?
        ) {
            self.did = did
            self.handle = handle
            self.displayName = displayName
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                displayName = try container.decodeIfPresent(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)

            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)

            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)

            } catch {
                LogManager.logError("Decoding error for property 'verification': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(StatusView.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
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

            if did != other.did {
                return false
            }

            if handle != other.handle {
                return false
            }

            if displayName != other.displayName {
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
            did: DID, handle: Handle, displayName: String?, description: String?, avatar: URI?, banner: URI?, followersCount: Int?, followsCount: Int?, postsCount: Int?, associated: ProfileAssociated?, joinedViaStarterPack: AppBskyGraphDefs.StarterPackViewBasic?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, pinnedPost: ComAtprotoRepoStrongRef?, verification: VerificationState?, status: StatusView?
        ) {
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.description = description
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                handle = try container.decode(Handle.self, forKey: .handle)

            } catch {
                LogManager.logError("Decoding error for property 'handle': \(error)")
                throw error
            }
            do {
                displayName = try container.decodeIfPresent(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for property 'displayName': \(error)")
                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)

            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                banner = try container.decodeIfPresent(URI.self, forKey: .banner)

            } catch {
                LogManager.logError("Decoding error for property 'banner': \(error)")
                throw error
            }
            do {
                followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)

            } catch {
                LogManager.logError("Decoding error for property 'followersCount': \(error)")
                throw error
            }
            do {
                followsCount = try container.decodeIfPresent(Int.self, forKey: .followsCount)

            } catch {
                LogManager.logError("Decoding error for property 'followsCount': \(error)")
                throw error
            }
            do {
                postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount)

            } catch {
                LogManager.logError("Decoding error for property 'postsCount': \(error)")
                throw error
            }
            do {
                associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)

            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                joinedViaStarterPack = try container.decodeIfPresent(AppBskyGraphDefs.StarterPackViewBasic.self, forKey: .joinedViaStarterPack)

            } catch {
                LogManager.logError("Decoding error for property 'joinedViaStarterPack': \(error)")
                throw error
            }
            do {
                indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                pinnedPost = try container.decodeIfPresent(ComAtprotoRepoStrongRef.self, forKey: .pinnedPost)

            } catch {
                LogManager.logError("Decoding error for property 'pinnedPost': \(error)")
                throw error
            }
            do {
                verification = try container.decodeIfPresent(VerificationState.self, forKey: .verification)

            } catch {
                LogManager.logError("Decoding error for property 'verification': \(error)")
                throw error
            }
            do {
                status = try container.decodeIfPresent(StatusView.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
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

            if did != other.did {
                return false
            }

            if handle != other.handle {
                return false
            }

            if displayName != other.displayName {
                return false
            }

            if description != other.description {
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

        // Standard initializer
        public init(
            lists: Int?, feedgens: Int?, starterPacks: Int?, labeler: Bool?, chat: ProfileAssociatedChat?
        ) {
            self.lists = lists
            self.feedgens = feedgens
            self.starterPacks = starterPacks
            self.labeler = labeler
            self.chat = chat
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                lists = try container.decodeIfPresent(Int.self, forKey: .lists)

            } catch {
                LogManager.logError("Decoding error for property 'lists': \(error)")
                throw error
            }
            do {
                feedgens = try container.decodeIfPresent(Int.self, forKey: .feedgens)

            } catch {
                LogManager.logError("Decoding error for property 'feedgens': \(error)")
                throw error
            }
            do {
                starterPacks = try container.decodeIfPresent(Int.self, forKey: .starterPacks)

            } catch {
                LogManager.logError("Decoding error for property 'starterPacks': \(error)")
                throw error
            }
            do {
                labeler = try container.decodeIfPresent(Bool.self, forKey: .labeler)

            } catch {
                LogManager.logError("Decoding error for property 'labeler': \(error)")
                throw error
            }
            do {
                chat = try container.decodeIfPresent(ProfileAssociatedChat.self, forKey: .chat)

            } catch {
                LogManager.logError("Decoding error for property 'chat': \(error)")
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

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case lists
            case feedgens
            case starterPacks
            case labeler
            case chat
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
                allowIncoming = try container.decode(String.self, forKey: .allowIncoming)

            } catch {
                LogManager.logError("Decoding error for property 'allowIncoming': \(error)")
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

            if allowIncoming != other.allowIncoming {
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

        // Standard initializer
        public init(
            muted: Bool?, mutedByList: AppBskyGraphDefs.ListViewBasic?, blockedBy: Bool?, blocking: ATProtocolURI?, blockingByList: AppBskyGraphDefs.ListViewBasic?, following: ATProtocolURI?, followedBy: ATProtocolURI?, knownFollowers: KnownFollowers?
        ) {
            self.muted = muted
            self.mutedByList = mutedByList
            self.blockedBy = blockedBy
            self.blocking = blocking
            self.blockingByList = blockingByList
            self.following = following
            self.followedBy = followedBy
            self.knownFollowers = knownFollowers
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                muted = try container.decodeIfPresent(Bool.self, forKey: .muted)

            } catch {
                LogManager.logError("Decoding error for property 'muted': \(error)")
                throw error
            }
            do {
                mutedByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .mutedByList)

            } catch {
                LogManager.logError("Decoding error for property 'mutedByList': \(error)")
                throw error
            }
            do {
                blockedBy = try container.decodeIfPresent(Bool.self, forKey: .blockedBy)

            } catch {
                LogManager.logError("Decoding error for property 'blockedBy': \(error)")
                throw error
            }
            do {
                blocking = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blocking)

            } catch {
                LogManager.logError("Decoding error for property 'blocking': \(error)")
                throw error
            }
            do {
                blockingByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .blockingByList)

            } catch {
                LogManager.logError("Decoding error for property 'blockingByList': \(error)")
                throw error
            }
            do {
                following = try container.decodeIfPresent(ATProtocolURI.self, forKey: .following)

            } catch {
                LogManager.logError("Decoding error for property 'following': \(error)")
                throw error
            }
            do {
                followedBy = try container.decodeIfPresent(ATProtocolURI.self, forKey: .followedBy)

            } catch {
                LogManager.logError("Decoding error for property 'followedBy': \(error)")
                throw error
            }
            do {
                knownFollowers = try container.decodeIfPresent(KnownFollowers.self, forKey: .knownFollowers)

            } catch {
                LogManager.logError("Decoding error for property 'knownFollowers': \(error)")
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
        }
    }

    public struct KnownFollowers: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.actor.defs#knownFollowers"
        public let count: Int
        public let followers: [ProfileViewBasic]

        // Standard initializer
        public init(
            count: Int, followers: [ProfileViewBasic]
        ) {
            self.count = count
            self.followers = followers
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                count = try container.decode(Int.self, forKey: .count)

            } catch {
                LogManager.logError("Decoding error for property 'count': \(error)")
                throw error
            }
            do {
                followers = try container.decode([ProfileViewBasic].self, forKey: .followers)

            } catch {
                LogManager.logError("Decoding error for property 'followers': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)

            try container.encode(count, forKey: .count)

            try container.encode(followers, forKey: .followers)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(count)
            hasher.combine(followers)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }

            if count != other.count {
                return false
            }

            if followers != other.followers {
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

            let followersValue = try followers.toCBORValue()
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
                verifications = try container.decode([VerificationView].self, forKey: .verifications)

            } catch {
                LogManager.logError("Decoding error for property 'verifications': \(error)")
                throw error
            }
            do {
                verifiedStatus = try container.decode(String.self, forKey: .verifiedStatus)

            } catch {
                LogManager.logError("Decoding error for property 'verifiedStatus': \(error)")
                throw error
            }
            do {
                trustedVerifierStatus = try container.decode(String.self, forKey: .trustedVerifierStatus)

            } catch {
                LogManager.logError("Decoding error for property 'trustedVerifierStatus': \(error)")
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

            if verifications != other.verifications {
                return false
            }

            if verifiedStatus != other.verifiedStatus {
                return false
            }

            if trustedVerifierStatus != other.trustedVerifierStatus {
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
                issuer = try container.decode(DID.self, forKey: .issuer)

            } catch {
                LogManager.logError("Decoding error for property 'issuer': \(error)")
                throw error
            }
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                isValid = try container.decode(Bool.self, forKey: .isValid)

            } catch {
                LogManager.logError("Decoding error for property 'isValid': \(error)")
                throw error
            }
            do {
                createdAt = try container.decode(ATProtocolDate.self, forKey: .createdAt)

            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
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

            if issuer != other.issuer {
                return false
            }

            if uri != other.uri {
                return false
            }

            if isValid != other.isValid {
                return false
            }

            if createdAt != other.createdAt {
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
                enabled = try container.decode(Bool.self, forKey: .enabled)

            } catch {
                LogManager.logError("Decoding error for property 'enabled': \(error)")
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

            if enabled != other.enabled {
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
                labelerDid = try container.decodeIfPresent(DID.self, forKey: .labelerDid)

            } catch {
                LogManager.logError("Decoding error for property 'labelerDid': \(error)")
                throw error
            }
            do {
                label = try container.decode(String.self, forKey: .label)

            } catch {
                LogManager.logError("Decoding error for property 'label': \(error)")
                throw error
            }
            do {
                visibility = try container.decode(String.self, forKey: .visibility)

            } catch {
                LogManager.logError("Decoding error for property 'visibility': \(error)")
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

            if label != other.label {
                return false
            }

            if visibility != other.visibility {
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
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                type = try container.decode(String.self, forKey: .type)

            } catch {
                LogManager.logError("Decoding error for property 'type': \(error)")
                throw error
            }
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                pinned = try container.decode(Bool.self, forKey: .pinned)

            } catch {
                LogManager.logError("Decoding error for property 'pinned': \(error)")
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

            if id != other.id {
                return false
            }

            if type != other.type {
                return false
            }

            if value != other.value {
                return false
            }

            if pinned != other.pinned {
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
                items = try container.decode([AppBskyActorDefs.SavedFeed].self, forKey: .items)

            } catch {
                LogManager.logError("Decoding error for property 'items': \(error)")
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

            if items != other.items {
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
                pinned = try container.decode([ATProtocolURI].self, forKey: .pinned)

            } catch {
                LogManager.logError("Decoding error for property 'pinned': \(error)")
                throw error
            }
            do {
                saved = try container.decode([ATProtocolURI].self, forKey: .saved)

            } catch {
                LogManager.logError("Decoding error for property 'saved': \(error)")
                throw error
            }
            do {
                timelineIndex = try container.decodeIfPresent(Int.self, forKey: .timelineIndex)

            } catch {
                LogManager.logError("Decoding error for property 'timelineIndex': \(error)")
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

            if pinned != other.pinned {
                return false
            }

            if saved != other.saved {
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
                birthDate = try container.decodeIfPresent(ATProtocolDate.self, forKey: .birthDate)

            } catch {
                LogManager.logError("Decoding error for property 'birthDate': \(error)")
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
                feed = try container.decode(String.self, forKey: .feed)

            } catch {
                LogManager.logError("Decoding error for property 'feed': \(error)")
                throw error
            }
            do {
                hideReplies = try container.decodeIfPresent(Bool.self, forKey: .hideReplies)

            } catch {
                LogManager.logError("Decoding error for property 'hideReplies': \(error)")
                throw error
            }
            do {
                hideRepliesByUnfollowed = try container.decodeIfPresent(Bool.self, forKey: .hideRepliesByUnfollowed)

            } catch {
                LogManager.logError("Decoding error for property 'hideRepliesByUnfollowed': \(error)")
                throw error
            }
            do {
                hideRepliesByLikeCount = try container.decodeIfPresent(Int.self, forKey: .hideRepliesByLikeCount)

            } catch {
                LogManager.logError("Decoding error for property 'hideRepliesByLikeCount': \(error)")
                throw error
            }
            do {
                hideReposts = try container.decodeIfPresent(Bool.self, forKey: .hideReposts)

            } catch {
                LogManager.logError("Decoding error for property 'hideReposts': \(error)")
                throw error
            }
            do {
                hideQuotePosts = try container.decodeIfPresent(Bool.self, forKey: .hideQuotePosts)

            } catch {
                LogManager.logError("Decoding error for property 'hideQuotePosts': \(error)")
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

            if feed != other.feed {
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
                sort = try container.decodeIfPresent(String.self, forKey: .sort)

            } catch {
                LogManager.logError("Decoding error for property 'sort': \(error)")
                throw error
            }
            do {
                prioritizeFollowedUsers = try container.decodeIfPresent(Bool.self, forKey: .prioritizeFollowedUsers)

            } catch {
                LogManager.logError("Decoding error for property 'prioritizeFollowedUsers': \(error)")
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
                tags = try container.decode([String].self, forKey: .tags)

            } catch {
                LogManager.logError("Decoding error for property 'tags': \(error)")
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

            if tags != other.tags {
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
                id = try container.decodeIfPresent(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                value = try container.decode(String.self, forKey: .value)

            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                targets = try container.decode([AppBskyActorDefs.MutedWordTarget].self, forKey: .targets)

            } catch {
                LogManager.logError("Decoding error for property 'targets': \(error)")
                throw error
            }
            do {
                actorTarget = try container.decodeIfPresent(String.self, forKey: .actorTarget)

            } catch {
                LogManager.logError("Decoding error for property 'actorTarget': \(error)")
                throw error
            }
            do {
                expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)

            } catch {
                LogManager.logError("Decoding error for property 'expiresAt': \(error)")
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

            if value != other.value {
                return false
            }

            if targets != other.targets {
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
                items = try container.decode([AppBskyActorDefs.MutedWord].self, forKey: .items)

            } catch {
                LogManager.logError("Decoding error for property 'items': \(error)")
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

            if items != other.items {
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
                items = try container.decode([ATProtocolURI].self, forKey: .items)

            } catch {
                LogManager.logError("Decoding error for property 'items': \(error)")
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

            if items != other.items {
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
                labelers = try container.decode([LabelerPrefItem].self, forKey: .labelers)

            } catch {
                LogManager.logError("Decoding error for property 'labelers': \(error)")
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

            if labelers != other.labelers {
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
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

            if did != other.did {
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
                activeProgressGuide = try container.decodeIfPresent(BskyAppProgressGuide.self, forKey: .activeProgressGuide)

            } catch {
                LogManager.logError("Decoding error for property 'activeProgressGuide': \(error)")
                throw error
            }
            do {
                queuedNudges = try container.decodeIfPresent([String].self, forKey: .queuedNudges)

            } catch {
                LogManager.logError("Decoding error for property 'queuedNudges': \(error)")
                throw error
            }
            do {
                nuxs = try container.decodeIfPresent([AppBskyActorDefs.Nux].self, forKey: .nuxs)

            } catch {
                LogManager.logError("Decoding error for property 'nuxs': \(error)")
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
                guide = try container.decode(String.self, forKey: .guide)

            } catch {
                LogManager.logError("Decoding error for property 'guide': \(error)")
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

            if guide != other.guide {
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
                id = try container.decode(String.self, forKey: .id)

            } catch {
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                completed = try container.decode(Bool.self, forKey: .completed)

            } catch {
                LogManager.logError("Decoding error for property 'completed': \(error)")
                throw error
            }
            do {
                data = try container.decodeIfPresent(String.self, forKey: .data)

            } catch {
                LogManager.logError("Decoding error for property 'data': \(error)")
                throw error
            }
            do {
                expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)

            } catch {
                LogManager.logError("Decoding error for property 'expiresAt': \(error)")
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

            if id != other.id {
                return false
            }

            if completed != other.completed {
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
                hideBadges = try container.decodeIfPresent(Bool.self, forKey: .hideBadges)

            } catch {
                LogManager.logError("Decoding error for property 'hideBadges': \(error)")
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
                threadgateAllowRules = try container.decodeIfPresent([PostInteractionSettingsPrefThreadgateAllowRulesUnion].self, forKey: .threadgateAllowRules)

            } catch {
                LogManager.logError("Decoding error for property 'threadgateAllowRules': \(error)")
                throw error
            }
            do {
                postgateEmbeddingRules = try container.decodeIfPresent([PostInteractionSettingsPrefPostgateEmbeddingRulesUnion].self, forKey: .postgateEmbeddingRules)

            } catch {
                LogManager.logError("Decoding error for property 'postgateEmbeddingRules': \(error)")
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
                status = try container.decode(String.self, forKey: .status)

            } catch {
                LogManager.logError("Decoding error for property 'status': \(error)")
                throw error
            }
            do {
                record = try container.decode(ATProtocolValueContainer.self, forKey: .record)

            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                embed = try container.decodeIfPresent(StatusViewEmbedUnion.self, forKey: .embed)

            } catch {
                LogManager.logError("Decoding error for property 'embed': \(error)")
                throw error
            }
            do {
                expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)

            } catch {
                LogManager.logError("Decoding error for property 'expiresAt': \(error)")
                throw error
            }
            do {
                isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)

            } catch {
                LogManager.logError("Decoding error for property 'isActive': \(error)")
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

            if status != other.status {
                return false
            }

            if record != other.record {
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

            if items != other.items {
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
            case let .adultContentPref(value):
                try container.encode("app.bsky.actor.defs#adultContentPref", forKey: .type)
                try value.encode(to: encoder)
            case let .contentLabelPref(value):
                try container.encode("app.bsky.actor.defs#contentLabelPref", forKey: .type)
                try value.encode(to: encoder)
            case let .savedFeedsPref(value):
                try container.encode("app.bsky.actor.defs#savedFeedsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .savedFeedsPrefV2(value):
                try container.encode("app.bsky.actor.defs#savedFeedsPrefV2", forKey: .type)
                try value.encode(to: encoder)
            case let .personalDetailsPref(value):
                try container.encode("app.bsky.actor.defs#personalDetailsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .feedViewPref(value):
                try container.encode("app.bsky.actor.defs#feedViewPref", forKey: .type)
                try value.encode(to: encoder)
            case let .threadViewPref(value):
                try container.encode("app.bsky.actor.defs#threadViewPref", forKey: .type)
                try value.encode(to: encoder)
            case let .interestsPref(value):
                try container.encode("app.bsky.actor.defs#interestsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .mutedWordsPref(value):
                try container.encode("app.bsky.actor.defs#mutedWordsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .hiddenPostsPref(value):
                try container.encode("app.bsky.actor.defs#hiddenPostsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .bskyAppStatePref(value):
                try container.encode("app.bsky.actor.defs#bskyAppStatePref", forKey: .type)
                try value.encode(to: encoder)
            case let .labelersPref(value):
                try container.encode("app.bsky.actor.defs#labelersPref", forKey: .type)
                try value.encode(to: encoder)
            case let .postInteractionSettingsPref(value):
                try container.encode("app.bsky.actor.defs#postInteractionSettingsPref", forKey: .type)
                try value.encode(to: encoder)
            case let .verificationPrefs(value):
                try container.encode("app.bsky.actor.defs#verificationPrefs", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(ATProtocolValueContainer):
                try ATProtocolValueContainer.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .adultContentPref(value):
                hasher.combine("app.bsky.actor.defs#adultContentPref")
                hasher.combine(value)
            case let .contentLabelPref(value):
                hasher.combine("app.bsky.actor.defs#contentLabelPref")
                hasher.combine(value)
            case let .savedFeedsPref(value):
                hasher.combine("app.bsky.actor.defs#savedFeedsPref")
                hasher.combine(value)
            case let .savedFeedsPrefV2(value):
                hasher.combine("app.bsky.actor.defs#savedFeedsPrefV2")
                hasher.combine(value)
            case let .personalDetailsPref(value):
                hasher.combine("app.bsky.actor.defs#personalDetailsPref")
                hasher.combine(value)
            case let .feedViewPref(value):
                hasher.combine("app.bsky.actor.defs#feedViewPref")
                hasher.combine(value)
            case let .threadViewPref(value):
                hasher.combine("app.bsky.actor.defs#threadViewPref")
                hasher.combine(value)
            case let .interestsPref(value):
                hasher.combine("app.bsky.actor.defs#interestsPref")
                hasher.combine(value)
            case let .mutedWordsPref(value):
                hasher.combine("app.bsky.actor.defs#mutedWordsPref")
                hasher.combine(value)
            case let .hiddenPostsPref(value):
                hasher.combine("app.bsky.actor.defs#hiddenPostsPref")
                hasher.combine(value)
            case let .bskyAppStatePref(value):
                hasher.combine("app.bsky.actor.defs#bskyAppStatePref")
                hasher.combine(value)
            case let .labelersPref(value):
                hasher.combine("app.bsky.actor.defs#labelersPref")
                hasher.combine(value)
            case let .postInteractionSettingsPref(value):
                hasher.combine("app.bsky.actor.defs#postInteractionSettingsPref")
                hasher.combine(value)
            case let .verificationPrefs(value):
                hasher.combine("app.bsky.actor.defs#verificationPrefs")
                hasher.combine(value)
            case let .unexpected(ATProtocolValueContainer):
                hasher.combine("unexpected")
                hasher.combine(ATProtocolValueContainer)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let otherValue = other as? PreferencesForUnionArray else { return false }

            switch (self, otherValue) {
            case let (
                .adultContentPref(selfValue),
                .adultContentPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .contentLabelPref(selfValue),
                .contentLabelPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .savedFeedsPref(selfValue),
                .savedFeedsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .savedFeedsPrefV2(selfValue),
                .savedFeedsPrefV2(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .personalDetailsPref(selfValue),
                .personalDetailsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .feedViewPref(selfValue),
                .feedViewPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .threadViewPref(selfValue),
                .threadViewPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .interestsPref(selfValue),
                .interestsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .mutedWordsPref(selfValue),
                .mutedWordsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .hiddenPostsPref(selfValue),
                .hiddenPostsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .bskyAppStatePref(selfValue),
                .bskyAppStatePref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .labelersPref(selfValue),
                .labelersPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .postInteractionSettingsPref(selfValue),
                .postInteractionSettingsPref(otherValue)
            ):
                return selfValue == otherValue
            case let (
                .verificationPrefs(selfValue),
                .verificationPrefs(otherValue)
            ):
                return selfValue == otherValue
            case let (.unexpected(selfValue), .unexpected(otherValue)):
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
            case let .adultContentPref(value):
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
            case let .contentLabelPref(value):
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
            case let .savedFeedsPref(value):
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
            case let .savedFeedsPrefV2(value):
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
            case let .personalDetailsPref(value):
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
            case let .feedViewPref(value):
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
            case let .threadViewPref(value):
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
            case let .interestsPref(value):
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
            case let .mutedWordsPref(value):
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
            case let .hiddenPostsPref(value):
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
            case let .bskyAppStatePref(value):
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
            case let .labelersPref(value):
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
            case let .postInteractionSettingsPref(value):
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
            case let .verificationPrefs(value):
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
            case let .unexpected(container):
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
            return rawValue == otherValue.rawValue
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
            case let .appBskyFeedThreadgateMentionRule(value):
                try container.encode("app.bsky.feed.threadgate#mentionRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowerRule(value):
                try container.encode("app.bsky.feed.threadgate#followerRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateFollowingRule(value):
                try container.encode("app.bsky.feed.threadgate#followingRule", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedThreadgateListRule(value):
                try container.encode("app.bsky.feed.threadgate#listRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                hasher.combine("app.bsky.feed.threadgate#mentionRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowerRule(value):
                hasher.combine("app.bsky.feed.threadgate#followerRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateFollowingRule(value):
                hasher.combine("app.bsky.feed.threadgate#followingRule")
                hasher.combine(value)
            case let .appBskyFeedThreadgateListRule(value):
                hasher.combine("app.bsky.feed.threadgate#listRule")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: PostInteractionSettingsPrefThreadgateAllowRulesUnion, rhs: PostInteractionSettingsPrefThreadgateAllowRulesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedThreadgateMentionRule(lhsValue),
                .appBskyFeedThreadgateMentionRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowerRule(lhsValue),
                .appBskyFeedThreadgateFollowerRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateFollowingRule(lhsValue),
                .appBskyFeedThreadgateFollowingRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedThreadgateListRule(lhsValue),
                .appBskyFeedThreadgateListRule(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedThreadgateMentionRule(value):
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
            case let .appBskyFeedThreadgateFollowerRule(value):
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
            case let .appBskyFeedThreadgateFollowingRule(value):
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
            case let .appBskyFeedThreadgateListRule(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyFeedThreadgateMentionRule(value):
                return value.hasPendingData
            case let .appBskyFeedThreadgateFollowerRule(value):
                return value.hasPendingData
            case let .appBskyFeedThreadgateFollowingRule(value):
                return value.hasPendingData
            case let .appBskyFeedThreadgateListRule(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyFeedThreadgateMentionRule(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedThreadgateMentionRule(value)
            case var .appBskyFeedThreadgateFollowerRule(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedThreadgateFollowerRule(value)
            case var .appBskyFeedThreadgateFollowingRule(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedThreadgateFollowingRule(value)
            case var .appBskyFeedThreadgateListRule(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedThreadgateListRule(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
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
            case let .appBskyFeedPostgateDisableRule(value):
                try container.encode("app.bsky.feed.postgate#disableRule", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                hasher.combine("app.bsky.feed.postgate#disableRule")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: PostInteractionSettingsPrefPostgateEmbeddingRulesUnion, rhs: PostInteractionSettingsPrefPostgateEmbeddingRulesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedPostgateDisableRule(lhsValue),
                .appBskyFeedPostgateDisableRule(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedPostgateDisableRule(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyFeedPostgateDisableRule(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyFeedPostgateDisableRule(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyFeedPostgateDisableRule(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
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
            case let .appBskyEmbedExternalView(value):
                try container.encode("app.bsky.embed.external#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedExternalView(value):
                hasher.combine("app.bsky.embed.external#view")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: StatusViewEmbedUnion, rhs: StatusViewEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedExternalView(lhsValue),
                .appBskyEmbedExternalView(rhsValue)
            ):
                return lhsValue == rhsValue

            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyEmbedExternalView(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }

        /// Property that indicates if this enum contains pending data that needs loading
        public var hasPendingData: Bool {
            switch self {
            case let .appBskyEmbedExternalView(value):
                return value.hasPendingData
            case .unexpected:
                return false
            }
        }

        /// Attempts to load any pending data in this enum or its children
        public mutating func loadPendingData() async {
            switch self {
            case var .appBskyEmbedExternalView(value):
                // Since ATProtocolValue already includes PendingDataLoadable,
                // we can directly call loadPendingData without conditional casting
                await value.loadPendingData()
                // Update the enum case with the potentially updated value
                self = .appBskyEmbedExternalView(value)
            case .unexpected:
                // Nothing to load for unexpected values
                break
            }
        }
    }
}
