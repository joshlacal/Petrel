import Foundation
import ZippyJSON


// lexicon: 1, id: app.bsky.feed.defs


public struct AppBskyFeedDefs { 

    public static let typeIdentifier = "app.bsky.feed.defs"
        
public struct PostView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#postView"
            public let uri: ATProtocolURI
            public let cid: String
            public let author: AppBskyActorDefs.ProfileViewBasic
            public let record: ATProtocolValueContainer
            public let embed: PostViewEmbedUnion?
            public let replyCount: Int?
            public let repostCount: Int?
            public let likeCount: Int?
            public let quoteCount: Int?
            public let indexedAt: ATProtocolDate
            public let viewer: ViewerState?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let threadgate: ThreadgateView?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer, embed: PostViewEmbedUnion?, replyCount: Int?, repostCount: Int?, likeCount: Int?, quoteCount: Int?, indexedAt: ATProtocolDate, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, threadgate: ThreadgateView?
        ) {
            
            self.uri = uri
            self.cid = cid
            self.author = author
            self.record = record
            self.embed = embed
            self.replyCount = replyCount
            self.repostCount = repostCount
            self.likeCount = likeCount
            self.quoteCount = quoteCount
            self.indexedAt = indexedAt
            self.viewer = viewer
            self.labels = labels
            self.threadgate = threadgate
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decode(String.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)
                
            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
                throw error
            }
            do {
                
                self.record = try container.decode(ATProtocolValueContainer.self, forKey: .record)
                
            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                
                self.embed = try container.decodeIfPresent(PostViewEmbedUnion.self, forKey: .embed)
                
            } catch {
                LogManager.logError("Decoding error for property 'embed': \(error)")
                throw error
            }
            do {
                
                self.replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'replyCount': \(error)")
                throw error
            }
            do {
                
                self.repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'repostCount': \(error)")
                throw error
            }
            do {
                
                self.likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                
                self.quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'quoteCount': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
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
                
                self.threadgate = try container.decodeIfPresent(ThreadgateView.self, forKey: .threadgate)
                
            } catch {
                LogManager.logError("Decoding error for property 'threadgate': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            try container.encode(author, forKey: .author)
            
            
            try container.encode(record, forKey: .record)
            
            
            if let value = embed {
                try container.encode(value, forKey: .embed)
            }
            
            
            if let value = replyCount {
                try container.encode(value, forKey: .replyCount)
            }
            
            
            if let value = repostCount {
                try container.encode(value, forKey: .repostCount)
            }
            
            
            if let value = likeCount {
                try container.encode(value, forKey: .likeCount)
            }
            
            
            if let value = quoteCount {
                try container.encode(value, forKey: .quoteCount)
            }
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
            
            
            if let value = labels {
                try container.encode(value, forKey: .labels)
            }
            
            
            if let value = threadgate {
                try container.encode(value, forKey: .threadgate)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(author)
            hasher.combine(record)
            if let value = embed {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = replyCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = repostCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = likeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = quoteCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(indexedAt)
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
            if let value = threadgate {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            if self.author != other.author {
                return false
            }
            
            
            if self.record != other.record {
                return false
            }
            
            
            if embed != other.embed {
                return false
            }
            
            
            if replyCount != other.replyCount {
                return false
            }
            
            
            if repostCount != other.repostCount {
                return false
            }
            
            
            if likeCount != other.likeCount {
                return false
            }
            
            
            if quoteCount != other.quoteCount {
                return false
            }
            
            
            if self.indexedAt != other.indexedAt {
                return false
            }
            
            
            if viewer != other.viewer {
                return false
            }
            
            
            if labels != other.labels {
                return false
            }
            
            
            if threadgate != other.threadgate {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case author
            case record
            case embed
            case replyCount
            case repostCount
            case likeCount
            case quoteCount
            case indexedAt
            case viewer
            case labels
            case threadgate
        }
    }
        
public struct ViewerState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#viewerState"
            public let repost: ATProtocolURI?
            public let like: ATProtocolURI?
            public let threadMuted: Bool?
            public let replyDisabled: Bool?
            public let embeddingDisabled: Bool?

        // Standard initializer
        public init(
            repost: ATProtocolURI?, like: ATProtocolURI?, threadMuted: Bool?, replyDisabled: Bool?, embeddingDisabled: Bool?
        ) {
            
            self.repost = repost
            self.like = like
            self.threadMuted = threadMuted
            self.replyDisabled = replyDisabled
            self.embeddingDisabled = embeddingDisabled
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.repost = try container.decodeIfPresent(ATProtocolURI.self, forKey: .repost)
                
            } catch {
                LogManager.logError("Decoding error for property 'repost': \(error)")
                throw error
            }
            do {
                
                self.like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)
                
            } catch {
                LogManager.logError("Decoding error for property 'like': \(error)")
                throw error
            }
            do {
                
                self.threadMuted = try container.decodeIfPresent(Bool.self, forKey: .threadMuted)
                
            } catch {
                LogManager.logError("Decoding error for property 'threadMuted': \(error)")
                throw error
            }
            do {
                
                self.replyDisabled = try container.decodeIfPresent(Bool.self, forKey: .replyDisabled)
                
            } catch {
                LogManager.logError("Decoding error for property 'replyDisabled': \(error)")
                throw error
            }
            do {
                
                self.embeddingDisabled = try container.decodeIfPresent(Bool.self, forKey: .embeddingDisabled)
                
            } catch {
                LogManager.logError("Decoding error for property 'embeddingDisabled': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = repost {
                try container.encode(value, forKey: .repost)
            }
            
            
            if let value = like {
                try container.encode(value, forKey: .like)
            }
            
            
            if let value = threadMuted {
                try container.encode(value, forKey: .threadMuted)
            }
            
            
            if let value = replyDisabled {
                try container.encode(value, forKey: .replyDisabled)
            }
            
            
            if let value = embeddingDisabled {
                try container.encode(value, forKey: .embeddingDisabled)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = repost {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = like {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = threadMuted {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = replyDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = embeddingDisabled {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if repost != other.repost {
                return false
            }
            
            
            if like != other.like {
                return false
            }
            
            
            if threadMuted != other.threadMuted {
                return false
            }
            
            
            if replyDisabled != other.replyDisabled {
                return false
            }
            
            
            if embeddingDisabled != other.embeddingDisabled {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case repost
            case like
            case threadMuted
            case replyDisabled
            case embeddingDisabled
        }
    }
        
public struct FeedViewPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#feedViewPost"
            public let post: PostView
            public let reply: ReplyRef?
            public let reason: FeedViewPostReasonUnion?
            public let feedContext: String?

        // Standard initializer
        public init(
            post: PostView, reply: ReplyRef?, reason: FeedViewPostReasonUnion?, feedContext: String?
        ) {
            
            self.post = post
            self.reply = reply
            self.reason = reason
            self.feedContext = feedContext
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.post = try container.decode(PostView.self, forKey: .post)
                
            } catch {
                LogManager.logError("Decoding error for property 'post': \(error)")
                throw error
            }
            do {
                
                self.reply = try container.decodeIfPresent(ReplyRef.self, forKey: .reply)
                
            } catch {
                LogManager.logError("Decoding error for property 'reply': \(error)")
                throw error
            }
            do {
                
                self.reason = try container.decodeIfPresent(FeedViewPostReasonUnion.self, forKey: .reason)
                
            } catch {
                LogManager.logError("Decoding error for property 'reason': \(error)")
                throw error
            }
            do {
                
                self.feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)
                
            } catch {
                LogManager.logError("Decoding error for property 'feedContext': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            if let value = reply {
                try container.encode(value, forKey: .reply)
            }
            
            
            if let value = reason {
                try container.encode(value, forKey: .reason)
            }
            
            
            if let value = feedContext {
                try container.encode(value, forKey: .feedContext)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            if let value = reply {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = feedContext {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.post != other.post {
                return false
            }
            
            
            if reply != other.reply {
                return false
            }
            
            
            if reason != other.reason {
                return false
            }
            
            
            if feedContext != other.feedContext {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case reply
            case reason
            case feedContext
        }
    }
        
public struct ReplyRef: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#replyRef"
            public let root: ReplyRefRootUnion
            public let parent: ReplyRefParentUnion
            public let grandparentAuthor: AppBskyActorDefs.ProfileViewBasic?

        // Standard initializer
        public init(
            root: ReplyRefRootUnion, parent: ReplyRefParentUnion, grandparentAuthor: AppBskyActorDefs.ProfileViewBasic?
        ) {
            
            self.root = root
            self.parent = parent
            self.grandparentAuthor = grandparentAuthor
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.root = try container.decode(ReplyRefRootUnion.self, forKey: .root)
                
            } catch {
                LogManager.logError("Decoding error for property 'root': \(error)")
                throw error
            }
            do {
                
                self.parent = try container.decode(ReplyRefParentUnion.self, forKey: .parent)
                
            } catch {
                LogManager.logError("Decoding error for property 'parent': \(error)")
                throw error
            }
            do {
                
                self.grandparentAuthor = try container.decodeIfPresent(AppBskyActorDefs.ProfileViewBasic.self, forKey: .grandparentAuthor)
                
            } catch {
                LogManager.logError("Decoding error for property 'grandparentAuthor': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(root, forKey: .root)
            
            
            try container.encode(parent, forKey: .parent)
            
            
            if let value = grandparentAuthor {
                try container.encode(value, forKey: .grandparentAuthor)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(root)
            hasher.combine(parent)
            if let value = grandparentAuthor {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.root != other.root {
                return false
            }
            
            
            if self.parent != other.parent {
                return false
            }
            
            
            if grandparentAuthor != other.grandparentAuthor {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case root
            case parent
            case grandparentAuthor
        }
    }
        
public struct ReasonRepost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#reasonRepost"
            public let by: AppBskyActorDefs.ProfileViewBasic
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            by: AppBskyActorDefs.ProfileViewBasic, indexedAt: ATProtocolDate
        ) {
            
            self.by = by
            self.indexedAt = indexedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.by = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .by)
                
            } catch {
                LogManager.logError("Decoding error for property 'by': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(by, forKey: .by)
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(by)
            hasher.combine(indexedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.by != other.by {
                return false
            }
            
            
            if self.indexedAt != other.indexedAt {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case by
            case indexedAt
        }
    }
        
public struct ThreadViewPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#threadViewPost"
            public let post: PostView
            public let parent: ThreadViewPostParentUnion?
            public let replies: [ThreadViewPostRepliesUnion]?

        // Standard initializer
        public init(
            post: PostView, parent: ThreadViewPostParentUnion?, replies: [ThreadViewPostRepliesUnion]?
        ) {
            
            self.post = post
            self.parent = parent
            self.replies = replies
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.post = try container.decode(PostView.self, forKey: .post)
                
            } catch {
                LogManager.logError("Decoding error for property 'post': \(error)")
                throw error
            }
            do {
                
                self.parent = try container.decodeIfPresent(ThreadViewPostParentUnion.self, forKey: .parent)
                
            } catch {
                LogManager.logError("Decoding error for property 'parent': \(error)")
                throw error
            }
            do {
                
                self.replies = try container.decodeIfPresent([ThreadViewPostRepliesUnion].self, forKey: .replies)
                
            } catch {
                LogManager.logError("Decoding error for property 'replies': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            if let value = parent {
                try container.encode(value, forKey: .parent)
            }
            
            
            if let value = replies {
                try container.encode(value, forKey: .replies)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            if let value = parent {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = replies {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.post != other.post {
                return false
            }
            
            
            if parent != other.parent {
                return false
            }
            
            
            if replies != other.replies {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case parent
            case replies
        }
    }
        
public struct NotFoundPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#notFoundPost"
            public let uri: ATProtocolURI
            public let notFound: Bool

        // Standard initializer
        public init(
            uri: ATProtocolURI, notFound: Bool
        ) {
            
            self.uri = uri
            self.notFound = notFound
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.notFound = try container.decode(Bool.self, forKey: .notFound)
                
            } catch {
                LogManager.logError("Decoding error for property 'notFound': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(notFound, forKey: .notFound)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(notFound)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.notFound != other.notFound {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case notFound
        }
    }
        
public struct BlockedPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#blockedPost"
            public let uri: ATProtocolURI
            public let blocked: Bool
            public let author: BlockedAuthor

        // Standard initializer
        public init(
            uri: ATProtocolURI, blocked: Bool, author: BlockedAuthor
        ) {
            
            self.uri = uri
            self.blocked = blocked
            self.author = author
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.blocked = try container.decode(Bool.self, forKey: .blocked)
                
            } catch {
                LogManager.logError("Decoding error for property 'blocked': \(error)")
                throw error
            }
            do {
                
                self.author = try container.decode(BlockedAuthor.self, forKey: .author)
                
            } catch {
                LogManager.logError("Decoding error for property 'author': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(blocked, forKey: .blocked)
            
            
            try container.encode(author, forKey: .author)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(blocked)
            hasher.combine(author)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.blocked != other.blocked {
                return false
            }
            
            
            if self.author != other.author {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case blocked
            case author
        }
    }
        
public struct BlockedAuthor: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#blockedAuthor"
            public let did: String
            public let viewer: AppBskyActorDefs.ViewerState?

        // Standard initializer
        public init(
            did: String, viewer: AppBskyActorDefs.ViewerState?
        ) {
            
            self.did = did
            self.viewer = viewer
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
                
                self.viewer = try container.decodeIfPresent(AppBskyActorDefs.ViewerState.self, forKey: .viewer)
                
            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(did, forKey: .did)
            
            
            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(did)
            if let value = viewer {
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
            
            
            if viewer != other.viewer {
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
            case viewer
        }
    }
        
public struct GeneratorView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#generatorView"
            public let uri: ATProtocolURI
            public let cid: String
            public let did: String
            public let creator: AppBskyActorDefs.ProfileView
            public let displayName: String
            public let description: String?
            public let descriptionFacets: [AppBskyRichtextFacet]?
            public let avatar: URI?
            public let likeCount: Int?
            public let acceptsInteractions: Bool?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let viewer: GeneratorViewerState?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: String, did: String, creator: AppBskyActorDefs.ProfileView, displayName: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: URI?, likeCount: Int?, acceptsInteractions: Bool?, labels: [ComAtprotoLabelDefs.Label]?, viewer: GeneratorViewerState?, indexedAt: ATProtocolDate
        ) {
            
            self.uri = uri
            self.cid = cid
            self.did = did
            self.creator = creator
            self.displayName = displayName
            self.description = description
            self.descriptionFacets = descriptionFacets
            self.avatar = avatar
            self.likeCount = likeCount
            self.acceptsInteractions = acceptsInteractions
            self.labels = labels
            self.viewer = viewer
            self.indexedAt = indexedAt
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decode(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decode(String.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.did = try container.decode(String.self, forKey: .did)
                
            } catch {
                LogManager.logError("Decoding error for property 'did': \(error)")
                throw error
            }
            do {
                
                self.creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)
                
            } catch {
                LogManager.logError("Decoding error for property 'creator': \(error)")
                throw error
            }
            do {
                
                self.displayName = try container.decode(String.self, forKey: .displayName)
                
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
                
                self.descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)
                
            } catch {
                LogManager.logError("Decoding error for property 'descriptionFacets': \(error)")
                throw error
            }
            do {
                
                self.avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)
                
            } catch {
                LogManager.logError("Decoding error for property 'avatar': \(error)")
                throw error
            }
            do {
                
                self.likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
                
            } catch {
                LogManager.logError("Decoding error for property 'likeCount': \(error)")
                throw error
            }
            do {
                
                self.acceptsInteractions = try container.decodeIfPresent(Bool.self, forKey: .acceptsInteractions)
                
            } catch {
                LogManager.logError("Decoding error for property 'acceptsInteractions': \(error)")
                throw error
            }
            do {
                
                self.labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)
                
            } catch {
                LogManager.logError("Decoding error for property 'labels': \(error)")
                throw error
            }
            do {
                
                self.viewer = try container.decodeIfPresent(GeneratorViewerState.self, forKey: .viewer)
                
            } catch {
                LogManager.logError("Decoding error for property 'viewer': \(error)")
                throw error
            }
            do {
                
                self.indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)
                
            } catch {
                LogManager.logError("Decoding error for property 'indexedAt': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(uri, forKey: .uri)
            
            
            try container.encode(cid, forKey: .cid)
            
            
            try container.encode(did, forKey: .did)
            
            
            try container.encode(creator, forKey: .creator)
            
            
            try container.encode(displayName, forKey: .displayName)
            
            
            if let value = description {
                try container.encode(value, forKey: .description)
            }
            
            
            if let value = descriptionFacets {
                try container.encode(value, forKey: .descriptionFacets)
            }
            
            
            if let value = avatar {
                try container.encode(value, forKey: .avatar)
            }
            
            
            if let value = likeCount {
                try container.encode(value, forKey: .likeCount)
            }
            
            
            if let value = acceptsInteractions {
                try container.encode(value, forKey: .acceptsInteractions)
            }
            
            
            if let value = labels {
                try container.encode(value, forKey: .labels)
            }
            
            
            if let value = viewer {
                try container.encode(value, forKey: .viewer)
            }
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uri)
            hasher.combine(cid)
            hasher.combine(did)
            hasher.combine(creator)
            hasher.combine(displayName)
            if let value = description {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = descriptionFacets {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = avatar {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = likeCount {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = acceptsInteractions {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = labels {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = viewer {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            hasher.combine(indexedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.uri != other.uri {
                return false
            }
            
            
            if self.cid != other.cid {
                return false
            }
            
            
            if self.did != other.did {
                return false
            }
            
            
            if self.creator != other.creator {
                return false
            }
            
            
            if self.displayName != other.displayName {
                return false
            }
            
            
            if description != other.description {
                return false
            }
            
            
            if descriptionFacets != other.descriptionFacets {
                return false
            }
            
            
            if avatar != other.avatar {
                return false
            }
            
            
            if likeCount != other.likeCount {
                return false
            }
            
            
            if acceptsInteractions != other.acceptsInteractions {
                return false
            }
            
            
            if labels != other.labels {
                return false
            }
            
            
            if viewer != other.viewer {
                return false
            }
            
            
            if self.indexedAt != other.indexedAt {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case did
            case creator
            case displayName
            case description
            case descriptionFacets
            case avatar
            case likeCount
            case acceptsInteractions
            case labels
            case viewer
            case indexedAt
        }
    }
        
public struct GeneratorViewerState: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#generatorViewerState"
            public let like: ATProtocolURI?

        // Standard initializer
        public init(
            like: ATProtocolURI?
        ) {
            
            self.like = like
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)
                
            } catch {
                LogManager.logError("Decoding error for property 'like': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = like {
                try container.encode(value, forKey: .like)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = like {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if like != other.like {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case like
        }
    }
        
public struct SkeletonFeedPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#skeletonFeedPost"
            public let post: ATProtocolURI
            public let reason: SkeletonFeedPostReasonUnion?
            public let feedContext: String?

        // Standard initializer
        public init(
            post: ATProtocolURI, reason: SkeletonFeedPostReasonUnion?, feedContext: String?
        ) {
            
            self.post = post
            self.reason = reason
            self.feedContext = feedContext
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.post = try container.decode(ATProtocolURI.self, forKey: .post)
                
            } catch {
                LogManager.logError("Decoding error for property 'post': \(error)")
                throw error
            }
            do {
                
                self.reason = try container.decodeIfPresent(SkeletonFeedPostReasonUnion.self, forKey: .reason)
                
            } catch {
                LogManager.logError("Decoding error for property 'reason': \(error)")
                throw error
            }
            do {
                
                self.feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)
                
            } catch {
                LogManager.logError("Decoding error for property 'feedContext': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            if let value = reason {
                try container.encode(value, forKey: .reason)
            }
            
            
            if let value = feedContext {
                try container.encode(value, forKey: .feedContext)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(post)
            if let value = reason {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = feedContext {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.post != other.post {
                return false
            }
            
            
            if reason != other.reason {
                return false
            }
            
            
            if feedContext != other.feedContext {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case reason
            case feedContext
        }
    }
        
public struct SkeletonReasonRepost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#skeletonReasonRepost"
            public let repost: ATProtocolURI

        // Standard initializer
        public init(
            repost: ATProtocolURI
        ) {
            
            self.repost = repost
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.repost = try container.decode(ATProtocolURI.self, forKey: .repost)
                
            } catch {
                LogManager.logError("Decoding error for property 'repost': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(repost, forKey: .repost)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(repost)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if self.repost != other.repost {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case repost
        }
    }
        
public struct ThreadgateView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#threadgateView"
            public let uri: ATProtocolURI?
            public let cid: String?
            public let record: ATProtocolValueContainer?
            public let lists: [AppBskyGraphDefs.ListViewBasic]?

        // Standard initializer
        public init(
            uri: ATProtocolURI?, cid: String?, record: ATProtocolValueContainer?, lists: [AppBskyGraphDefs.ListViewBasic]?
        ) {
            
            self.uri = uri
            self.cid = cid
            self.record = record
            self.lists = lists
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.uri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decodeIfPresent(String.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.record = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .record)
                
            } catch {
                LogManager.logError("Decoding error for property 'record': \(error)")
                throw error
            }
            do {
                
                self.lists = try container.decodeIfPresent([AppBskyGraphDefs.ListViewBasic].self, forKey: .lists)
                
            } catch {
                LogManager.logError("Decoding error for property 'lists': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = uri {
                try container.encode(value, forKey: .uri)
            }
            
            
            if let value = cid {
                try container.encode(value, forKey: .cid)
            }
            
            
            if let value = record {
                try container.encode(value, forKey: .record)
            }
            
            
            if let value = lists {
                try container.encode(value, forKey: .lists)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = uri {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = cid {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = record {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = lists {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if uri != other.uri {
                return false
            }
            
            
            if cid != other.cid {
                return false
            }
            
            
            if record != other.record {
                return false
            }
            
            
            if lists != other.lists {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case uri
            case cid
            case record
            case lists
        }
    }
        
public struct Interaction: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#interaction"
            public let item: ATProtocolURI?
            public let event: String?
            public let feedContext: String?

        // Standard initializer
        public init(
            item: ATProtocolURI?, event: String?, feedContext: String?
        ) {
            
            self.item = item
            self.event = event
            self.feedContext = feedContext
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.item = try container.decodeIfPresent(ATProtocolURI.self, forKey: .item)
                
            } catch {
                LogManager.logError("Decoding error for property 'item': \(error)")
                throw error
            }
            do {
                
                self.event = try container.decodeIfPresent(String.self, forKey: .event)
                
            } catch {
                LogManager.logError("Decoding error for property 'event': \(error)")
                throw error
            }
            do {
                
                self.feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)
                
            } catch {
                LogManager.logError("Decoding error for property 'feedContext': \(error)")
                throw error
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            if let value = item {
                try container.encode(value, forKey: .item)
            }
            
            
            if let value = event {
                try container.encode(value, forKey: .event)
            }
            
            
            if let value = feedContext {
                try container.encode(value, forKey: .feedContext)
            }
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = item {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = event {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
            if let value = feedContext {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            guard let other = other as? Self else { return false }
            
            if item != other.item {
                return false
            }
            
            
            if event != other.event {
                return false
            }
            
            
            if feedContext != other.feedContext {
                return false
            }
            
            return true
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case item
            case event
            case feedContext
        }
    }





public enum PostViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyEmbedImagesView(AppBskyEmbedImages.View)
    case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
    case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
    case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
    case appBskyEmbedRecordWithMediaView(AppBskyEmbedRecordWithMedia.View)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.embed.images#view":
            let value = try AppBskyEmbedImages.View(from: decoder)
            self = .appBskyEmbedImagesView(value)
        case "app.bsky.embed.video#view":
            let value = try AppBskyEmbedVideo.View(from: decoder)
            self = .appBskyEmbedVideoView(value)
        case "app.bsky.embed.external#view":
            let value = try AppBskyEmbedExternal.View(from: decoder)
            self = .appBskyEmbedExternalView(value)
        case "app.bsky.embed.record#view":
            let value = try AppBskyEmbedRecord.View(from: decoder)
            self = .appBskyEmbedRecordView(value)
        case "app.bsky.embed.recordWithMedia#view":
            let value = try AppBskyEmbedRecordWithMedia.View(from: decoder)
            self = .appBskyEmbedRecordWithMediaView(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyEmbedImagesView(let value):
            try container.encode("app.bsky.embed.images#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedVideoView(let value):
            try container.encode("app.bsky.embed.video#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedExternalView(let value):
            try container.encode("app.bsky.embed.external#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordView(let value):
            try container.encode("app.bsky.embed.record#view", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyEmbedRecordWithMediaView(let value):
            try container.encode("app.bsky.embed.recordWithMedia#view", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyEmbedImagesView(let value):
            hasher.combine("app.bsky.embed.images#view")
            hasher.combine(value)
        case .appBskyEmbedVideoView(let value):
            hasher.combine("app.bsky.embed.video#view")
            hasher.combine(value)
        case .appBskyEmbedExternalView(let value):
            hasher.combine("app.bsky.embed.external#view")
            hasher.combine(value)
        case .appBskyEmbedRecordView(let value):
            hasher.combine("app.bsky.embed.record#view")
            hasher.combine(value)
        case .appBskyEmbedRecordWithMediaView(let value):
            hasher.combine("app.bsky.embed.recordWithMedia#view")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? PostViewEmbedUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyEmbedImagesView(let selfValue), 
                .appBskyEmbedImagesView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedVideoView(let selfValue), 
                .appBskyEmbedVideoView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedExternalView(let selfValue), 
                .appBskyEmbedExternalView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedRecordView(let selfValue), 
                .appBskyEmbedRecordView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyEmbedRecordWithMediaView(let selfValue), 
                .appBskyEmbedRecordWithMediaView(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum FeedViewPostReasonUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsReasonRepost(AppBskyFeedDefs.ReasonRepost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#reasonRepost":
            let value = try AppBskyFeedDefs.ReasonRepost(from: decoder)
            self = .appBskyFeedDefsReasonRepost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsReasonRepost(let value):
            try container.encode("app.bsky.feed.defs#reasonRepost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsReasonRepost(let value):
            hasher.combine("app.bsky.feed.defs#reasonRepost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? FeedViewPostReasonUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsReasonRepost(let selfValue), 
                .appBskyFeedDefsReasonRepost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum ReplyRefRootUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsPostView(AppBskyFeedDefs.PostView)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#postView":
            let value = try AppBskyFeedDefs.PostView(from: decoder)
            self = .appBskyFeedDefsPostView(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsPostView(let value):
            try container.encode("app.bsky.feed.defs#postView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsPostView(let value):
            hasher.combine("app.bsky.feed.defs#postView")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ReplyRefRootUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsPostView(let selfValue), 
                .appBskyFeedDefsPostView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsNotFoundPost(let selfValue), 
                .appBskyFeedDefsNotFoundPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsBlockedPost(let selfValue), 
                .appBskyFeedDefsBlockedPost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum ReplyRefParentUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsPostView(AppBskyFeedDefs.PostView)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#postView":
            let value = try AppBskyFeedDefs.PostView(from: decoder)
            self = .appBskyFeedDefsPostView(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsPostView(let value):
            try container.encode("app.bsky.feed.defs#postView", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsPostView(let value):
            hasher.combine("app.bsky.feed.defs#postView")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ReplyRefParentUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsPostView(let selfValue), 
                .appBskyFeedDefsPostView(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsNotFoundPost(let selfValue), 
                .appBskyFeedDefsNotFoundPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsBlockedPost(let selfValue), 
                .appBskyFeedDefsBlockedPost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}



public indirect enum ThreadViewPostParentUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#threadViewPost":
            let value = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
            self = .appBskyFeedDefsThreadViewPost(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            hasher.combine("app.bsky.feed.defs#threadViewPost")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ThreadViewPostParentUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsThreadViewPost(let selfValue), 
                .appBskyFeedDefsThreadViewPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsNotFoundPost(let selfValue), 
                .appBskyFeedDefsNotFoundPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsBlockedPost(let selfValue), 
                .appBskyFeedDefsBlockedPost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}



public indirect enum ThreadViewPostRepliesUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#threadViewPost":
            let value = try AppBskyFeedDefs.ThreadViewPost(from: decoder)
            self = .appBskyFeedDefsThreadViewPost(value)
        case "app.bsky.feed.defs#notFoundPost":
            let value = try AppBskyFeedDefs.NotFoundPost(from: decoder)
            self = .appBskyFeedDefsNotFoundPost(value)
        case "app.bsky.feed.defs#blockedPost":
            let value = try AppBskyFeedDefs.BlockedPost(from: decoder)
            self = .appBskyFeedDefsBlockedPost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsNotFoundPost(let value):
            try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
            try value.encode(to: encoder)
        case .appBskyFeedDefsBlockedPost(let value):
            try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            hasher.combine("app.bsky.feed.defs#threadViewPost")
            hasher.combine(value)
        case .appBskyFeedDefsNotFoundPost(let value):
            hasher.combine("app.bsky.feed.defs#notFoundPost")
            hasher.combine(value)
        case .appBskyFeedDefsBlockedPost(let value):
            hasher.combine("app.bsky.feed.defs#blockedPost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? ThreadViewPostRepliesUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsThreadViewPost(let selfValue), 
                .appBskyFeedDefsThreadViewPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsNotFoundPost(let selfValue), 
                .appBskyFeedDefsNotFoundPost(let otherValue)):
                return selfValue == otherValue
            case (.appBskyFeedDefsBlockedPost(let selfValue), 
                .appBskyFeedDefsBlockedPost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}




public enum SkeletonFeedPostReasonUnion: Codable, ATProtocolCodable, ATProtocolValue {
    case appBskyFeedDefsSkeletonReasonRepost(AppBskyFeedDefs.SkeletonReasonRepost)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "app.bsky.feed.defs#skeletonReasonRepost":
            let value = try AppBskyFeedDefs.SkeletonReasonRepost(from: decoder)
            self = .appBskyFeedDefsSkeletonReasonRepost(value)
        default:
            let unknownValue = try ATProtocolValueContainer(from: decoder)
            self = .unexpected(unknownValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appBskyFeedDefsSkeletonReasonRepost(let value):
            try container.encode("app.bsky.feed.defs#skeletonReasonRepost", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let ATProtocolValueContainer):
            try ATProtocolValueContainer.encode(to: encoder)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsSkeletonReasonRepost(let value):
            hasher.combine("app.bsky.feed.defs#skeletonReasonRepost")
            hasher.combine(value)
        case .unexpected(let ATProtocolValueContainer):
            hasher.combine("unexpected")
            hasher.combine(ATProtocolValueContainer)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherValue = other as? SkeletonFeedPostReasonUnion else { return false }

        switch (self, otherValue) {
            case (.appBskyFeedDefsSkeletonReasonRepost(let selfValue), 
                .appBskyFeedDefsSkeletonReasonRepost(let otherValue)):
                return selfValue == otherValue
            case (.unexpected(let selfValue), .unexpected(let otherValue)):
                return selfValue.isEqual(to: otherValue)
            default:
                return false
        }
    }
}


}


                           
