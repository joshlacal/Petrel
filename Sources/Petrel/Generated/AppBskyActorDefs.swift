import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.actor.defs


public struct AppBskyActorDefs { 

    public static let typeIdentifier = "app.bsky.actor.defs"
        
public struct ProfileViewBasic: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileViewBasic"
            public let did: String
            public let handle: String
            public let displayName: String?
            public let avatar: URI?
            public let associated: ProfileAssociated?
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let createdAt: ATProtocolDate?

        // Standard initializer
        public init(
            did: String, handle: String, displayName: String?, avatar: URI?, associated: ProfileAssociated?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, createdAt: ATProtocolDate?
        ) {
            
            self.did = did
            self.handle = handle
            self.displayName = displayName
            self.avatar = avatar
            self.associated = associated
            self.viewer = viewer
            self.labels = labels
            self.createdAt = createdAt
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
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
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
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
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
                try container.encode(value, forKey: .labels)
            }
            
            
            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
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
            if let value = createdAt {
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
            
            
            if createdAt != other.createdAt {
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
            case createdAt
        }
    }
        
public struct ProfileView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileView"
            public let did: String
            public let handle: String
            public let displayName: String?
            public let description: String?
            public let avatar: URI?
            public let associated: ProfileAssociated?
            public let indexedAt: ATProtocolDate?
            public let createdAt: ATProtocolDate?
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?

        // Standard initializer
        public init(
            did: String, handle: String, displayName: String?, description: String?, avatar: URI?, associated: ProfileAssociated?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?
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
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            if let value = displayName {
                try container.encode(value, forKey: .displayName)
            }
            
            
            if let value = description {
                try container.encode(value, forKey: .description)
            }
            
            
            if let value = avatar {
                try container.encode(value, forKey: .avatar)
            }
            
            
            if let value = associated {
                try container.encode(value, forKey: .associated)
            }
            
            
            if let value = indexedAt {
                try container.encode(value, forKey: .indexedAt)
            }
            
            
            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }
            
            
            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
            
            
            if let value = labels {
                try container.encode(value, forKey: .labels)
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
            case description
            case avatar
            case associated
            case indexedAt
            case createdAt
            case viewer
            case labels
        }
    }
        
public struct ProfileViewDetailed: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#profileViewDetailed"
            public let did: String
            public let handle: String
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

        // Standard initializer
        public init(
            did: String, handle: String, displayName: String?, description: String?, avatar: URI?, banner: URI?, followersCount: Int?, followsCount: Int?, postsCount: Int?, associated: ProfileAssociated?, joinedViaStarterPack: AppBskyGraphDefs.StarterPackViewBasic?, indexedAt: ATProtocolDate?, createdAt: ATProtocolDate?, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?
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
                
                self.description = try container.decodeIfPresent(String.self, forKey: .description)
                
            } catch {
                LogManager.logError("Decoding error for property 'description': \(error)")
                throw error
            }
            do {
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                
                self.banner = try container.decodeIfPresent(URI.self, forKey: .banner)
                
            } catch {
                LogManager.logError("Decoding error for property 'banner': \(error)")
                throw error
            }
            do {
                
                self.followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'followersCount': \(error)")
                throw error
            }
            do {
                
                self.followsCount = try container.decodeIfPresent(Int.self, forKey: .followsCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'followsCount': \(error)")
                throw error
            }
            do {
                
                self.postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'postsCount': \(error)")
                throw error
            }
            do {
                
                self.associated = try container.decodeIfPresent(ProfileAssociated.self, forKey: .associated)
                
            } catch {
                LogManager.logError("Decoding error for property 'associated': \(error)")
                throw error
            }
            do {
                
                self.joinedViaStarterPack = try container.decodeIfPresent(AppBskyGraphDefs.StarterPackViewBasic.self, forKey: .joinedViaStarterPack)
                
            } catch {
                LogManager.logError("Decoding error for property 'joinedViaStarterPack': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
            do {
                
                self.createdAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .createdAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'createdAt': \(error)")
                throw error
            }
            do {
                
                self.viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)
                
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(handle, forKey: .handle)
            
            
            if let value = displayName {
                try container.encode(value, forKey: .displayName)
            }
            
            
            if let value = description {
                try container.encode(value, forKey: .description)
            }
            
            
            if let value = avatar {
                try container.encode(value, forKey: .avatar)
            }
            
            
            if let value = banner {
                try container.encode(value, forKey: .banner)
            }
            
            
            if let value = followersCount {
                try container.encode(value, forKey: .followersCount)
            }
            
            
            if let value = followsCount {
                try container.encode(value, forKey: .followsCount)
            }
            
            
            if let value = postsCount {
                try container.encode(value, forKey: .postsCount)
            }
            
            
            if let value = associated {
                try container.encode(value, forKey: .associated)
            }
            
            
            if let value = joinedViaStarterPack {
                try container.encode(value, forKey: .joinedViaStarterPack)
            }
            
            
            if let value = indexedAt {
                try container.encode(value, forKey: .indexedAt)
            }
            
            
            if let value = createdAt {
                try container.encode(value, forKey: .createdAt)
            }
            
            
            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
            
            
            if let value = labels {
                try container.encode(value, forKey: .labels)
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
                
                self.lists = try container.decodeIfPresent(Int.self, forKey: .lists)
                
            } catch {
                LogManager.logError("Decoding error for property 'lists': \(error)")
                throw error
            }
            do {
                
                self.feedgens = try container.decodeIfPresent(Int.self, forKey: .feedgens)
                
            } catch {
                LogManager.logError("Decoding error for property 'feedgens': \(error)")
                throw error
            }
            do {
                
                self.starterPacks = try container.decodeIfPresent(Int.self, forKey: .starterPacks)
                
            } catch {
                LogManager.logError("Decoding error for property 'starterPacks': \(error)")
                throw error
            }
            do {
                
                self.labeler = try container.decodeIfPresent(Bool.self, forKey: .labeler)
                
            } catch {
                LogManager.logError("Decoding error for property 'labeler': \(error)")
                throw error
            }
            do {
                
                self.chat = try container.decodeIfPresent(ProfileAssociatedChat.self, forKey: .chat)
                
            } catch {
                LogManager.logError("Decoding error for property 'chat': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = lists {
                try container.encode(value, forKey: .lists)
            }
            
            
            if let value = feedgens {
                try container.encode(value, forKey: .feedgens)
            }
            
            
            if let value = starterPacks {
                try container.encode(value, forKey: .starterPacks)
            }
            
            
            if let value = labeler {
                try container.encode(value, forKey: .labeler)
            }
            
            
            if let value = chat {
                try container.encode(value, forKey: .chat)
            }
            
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
                
                self.allowIncoming = try container.decode(String.self, forKey: .allowIncoming)
                
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
            
            if self.allowIncoming != other.allowIncoming {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
                
                self.muted = try container.decodeIfPresent(Bool.self, forKey: .muted)
                
            } catch {
                LogManager.logError("Decoding error for property 'muted': \(error)")
                throw error
            }
            do {
                
                self.mutedByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .mutedByList)
                
            } catch {
                LogManager.logError("Decoding error for property 'mutedByList': \(error)")
                throw error
            }
            do {
                
                self.blockedBy = try container.decodeIfPresent(Bool.self, forKey: .blockedBy)
                
            } catch {
                LogManager.logError("Decoding error for property 'blockedBy': \(error)")
                throw error
            }
            do {
                
                self.blocking = try container.decodeIfPresent(ATProtocolURI.self, forKey: .blocking)
                
            } catch {
                LogManager.logError("Decoding error for property 'blocking': \(error)")
                throw error
            }
            do {
                
                self.blockingByList = try container.decodeIfPresent(AppBskyGraphDefs.ListViewBasic.self, forKey: .blockingByList)
                
            } catch {
                LogManager.logError("Decoding error for property 'blockingByList': \(error)")
                throw error
            }
            do {
                
                self.following = try container.decodeIfPresent(ATProtocolURI.self, forKey: .following)
                
            } catch {
                LogManager.logError("Decoding error for property 'following': \(error)")
                throw error
            }
            do {
                
                self.followedBy = try container.decodeIfPresent(ATProtocolURI.self, forKey: .followedBy)
                
            } catch {
                LogManager.logError("Decoding error for property 'followedBy': \(error)")
                throw error
            }
            do {
                
                self.knownFollowers = try container.decodeIfPresent(KnownFollowers.self, forKey: .knownFollowers)
                
            } catch {
                LogManager.logError("Decoding error for property 'knownFollowers': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = muted {
                try container.encode(value, forKey: .muted)
            }
            
            
            if let value = mutedByList {
                try container.encode(value, forKey: .mutedByList)
            }
            
            
            if let value = blockedBy {
                try container.encode(value, forKey: .blockedBy)
            }
            
            
            if let value = blocking {
                try container.encode(value, forKey: .blocking)
            }
            
            
            if let value = blockingByList {
                try container.encode(value, forKey: .blockingByList)
            }
            
            
            if let value = following {
                try container.encode(value, forKey: .following)
            }
            
            
            if let value = followedBy {
                try container.encode(value, forKey: .followedBy)
            }
            
            
            if let value = knownFollowers {
                try container.encode(value, forKey: .knownFollowers)
            }
            
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
                
                self.count = try container.decode(Int.self, forKey: .count)
                
            } catch {
                LogManager.logError("Decoding error for property 'count': \(error)")
                throw error
            }
            do {
                
                self.followers = try container.decode([ProfileViewBasic].self, forKey: .followers)
                
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
            
            if self.count != other.count {
                return false
            }
            
            
            if self.followers != other.followers {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case count
            case followers
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
            
            if self.enabled != other.enabled {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case enabled
        }
    }
        
public struct ContentLabelPref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#contentLabelPref"
            public let labelerDid: String?
            public let label: String
            public let visibility: String

        // Standard initializer
        public init(
            labelerDid: String?, label: String, visibility: String
        ) {
            
            self.labelerDid = labelerDid
            self.label = label
            self.visibility = visibility
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.labelerDid = try container.decodeIfPresent(String.self, forKey: .labelerDid)
                
            } catch {
                LogManager.logError("Decoding error for property 'labelerDid': \(error)")
                throw error
            }
            do {
                
                self.label = try container.decode(String.self, forKey: .label)
                
            } catch {
                LogManager.logError("Decoding error for property 'label': \(error)")
                throw error
            }
            do {
                
                self.visibility = try container.decode(String.self, forKey: .visibility)
                
            } catch {
                LogManager.logError("Decoding error for property 'visibility': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = labelerDid {
                try container.encode(value, forKey: .labelerDid)
            }
            
            
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
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                
                self.type = try container.decode(String.self, forKey: .type)
                
            } catch {
                LogManager.logError("Decoding error for property 'type': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(String.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                
                self.pinned = try container.decode(Bool.self, forKey: .pinned)
                
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
            
            if self.items != other.items {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
                LogManager.logError("Decoding error for property 'pinned': \(error)")
                throw error
            }
            do {
                
                self.saved = try container.decode([ATProtocolURI].self, forKey: .saved)
                
            } catch {
                LogManager.logError("Decoding error for property 'saved': \(error)")
                throw error
            }
            do {
                
                self.timelineIndex = try container.decodeIfPresent(Int.self, forKey: .timelineIndex)
                
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
            
            
            if let value = timelineIndex {
                try container.encode(value, forKey: .timelineIndex)
            }
            
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
                LogManager.logError("Decoding error for property 'birthDate': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = birthDate {
                try container.encode(value, forKey: .birthDate)
            }
            
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
                LogManager.logError("Decoding error for property 'feed': \(error)")
                throw error
            }
            do {
                
                self.hideReplies = try container.decodeIfPresent(Bool.self, forKey: .hideReplies)
                
            } catch {
                LogManager.logError("Decoding error for property 'hideReplies': \(error)")
                throw error
            }
            do {
                
                self.hideRepliesByUnfollowed = try container.decodeIfPresent(Bool.self, forKey: .hideRepliesByUnfollowed)
                
            } catch {
                LogManager.logError("Decoding error for property 'hideRepliesByUnfollowed': \(error)")
                throw error
            }
            do {
                
                self.hideRepliesByLikeCount = try container.decodeIfPresent(Int.self, forKey: .hideRepliesByLikeCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'hideRepliesByLikeCount': \(error)")
                throw error
            }
            do {
                
                self.hideReposts = try container.decodeIfPresent(Bool.self, forKey: .hideReposts)
                
            } catch {
                LogManager.logError("Decoding error for property 'hideReposts': \(error)")
                throw error
            }
            do {
                
                self.hideQuotePosts = try container.decodeIfPresent(Bool.self, forKey: .hideQuotePosts)
                
            } catch {
                LogManager.logError("Decoding error for property 'hideQuotePosts': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(feed, forKey: .feed)
            
            
            if let value = hideReplies {
                try container.encode(value, forKey: .hideReplies)
            }
            
            
            if let value = hideRepliesByUnfollowed {
                try container.encode(value, forKey: .hideRepliesByUnfollowed)
            }
            
            
            if let value = hideRepliesByLikeCount {
                try container.encode(value, forKey: .hideRepliesByLikeCount)
            }
            
            
            if let value = hideReposts {
                try container.encode(value, forKey: .hideReposts)
            }
            
            
            if let value = hideQuotePosts {
                try container.encode(value, forKey: .hideQuotePosts)
            }
            
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
                LogManager.logError("Decoding error for property 'sort': \(error)")
                throw error
            }
            do {
                
                self.prioritizeFollowedUsers = try container.decodeIfPresent(Bool.self, forKey: .prioritizeFollowedUsers)
                
            } catch {
                LogManager.logError("Decoding error for property 'prioritizeFollowedUsers': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = sort {
                try container.encode(value, forKey: .sort)
            }
            
            
            if let value = prioritizeFollowedUsers {
                try container.encode(value, forKey: .prioritizeFollowedUsers)
            }
            
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
            
            if self.tags != other.tags {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
                LogManager.logError("Decoding error for property 'id': \(error)")
                throw error
            }
            do {
                
                self.value = try container.decode(String.self, forKey: .value)
                
            } catch {
                LogManager.logError("Decoding error for property 'value': \(error)")
                throw error
            }
            do {
                
                self.targets = try container.decode([AppBskyActorDefs.MutedWordTarget].self, forKey: .targets)
                
            } catch {
                LogManager.logError("Decoding error for property 'targets': \(error)")
                throw error
            }
            do {
                
                self.actorTarget = try container.decodeIfPresent(String.self, forKey: .actorTarget)
                
            } catch {
                LogManager.logError("Decoding error for property 'actorTarget': \(error)")
                throw error
            }
            do {
                
                self.expiresAt = try container.decodeIfPresent(ATProtocolDate.self, forKey: .expiresAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'expiresAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = id {
                try container.encode(value, forKey: .id)
            }
            
            
            try container.encode(value, forKey: .value)
            
            
            try container.encode(targets, forKey: .targets)
            
            
            if let value = actorTarget {
                try container.encode(value, forKey: .actorTarget)
            }
            
            
            if let value = expiresAt {
                try container.encode(value, forKey: .expiresAt)
            }
            
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
            
            if self.items != other.items {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
            
            if self.items != other.items {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
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
            
            if self.labelers != other.labelers {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case labelers
        }
    }
        
public struct LabelerPrefItem: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#labelerPrefItem"
            public let did: String

        // Standard initializer
        public init(
            did: String
        ) {
            
            self.did = did
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

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case did
        }
    }
        
public struct BskyAppStatePref: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.actor.defs#bskyAppStatePref"
            public let activeProgressGuide: BskyAppProgressGuide?
            public let queuedNudges: [String]?

        // Standard initializer
        public init(
            activeProgressGuide: BskyAppProgressGuide?, queuedNudges: [String]?
        ) {
            
            self.activeProgressGuide = activeProgressGuide
            self.queuedNudges = queuedNudges
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.activeProgressGuide = try container.decodeIfPresent(BskyAppProgressGuide.self, forKey: .activeProgressGuide)
                
            } catch {
                LogManager.logError("Decoding error for property 'activeProgressGuide': \(error)")
                throw error
            }
            do {
                
                self.queuedNudges = try container.decodeIfPresent([String].self, forKey: .queuedNudges)
                
            } catch {
                LogManager.logError("Decoding error for property 'queuedNudges': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = activeProgressGuide {
                try container.encode(value, forKey: .activeProgressGuide)
            }
            
            
            if let value = queuedNudges {
                try container.encode(value, forKey: .queuedNudges)
            }
            
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
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if activeProgressGuide != other.activeProgressGuide {
                return false
            }
            
            
            if queuedNudges != other.queuedNudges {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case activeProgressGuide
            case queuedNudges
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
            
            if self.guide != other.guide {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case guide
        }
    }


// Union Array Type


public struct Preferences: Codable, ATProtocolCodable, ATProtocolValue {
    public let items: [PreferencesForUnionArray]

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
        var container = encoder.unkeyedContainer()
        for item in items {
            try container.encode(item)
        }
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        
        if self.items != other.items {
            return false
        }

        return true
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
    case unexpected(ATProtocolValueContainer)

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
        case (.unexpected(let selfValue), .unexpected(let otherValue)):
            return selfValue.isEqual(to: otherValue)
        default:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
}

        
public enum MutedWordTarget: String, Codable, ATProtocolCodable, ATProtocolValue, CaseIterable {
            // 
            case content = "content"
            // 
            case tag = "tag"

            public func isEqual(to other: any ATProtocolValue) -> Bool {
                guard let otherEnum = other as? MutedWordTarget else { return false }
                return self.rawValue == otherEnum.rawValue
            }
        }


}


                           
