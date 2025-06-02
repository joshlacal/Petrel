import Foundation



// lexicon: 1, id: app.bsky.feed.defs


public struct AppBskyFeedDefs { 

    public static let typeIdentifier = "app.bsky.feed.defs"
        
public struct PostView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#postView"
            public let uri: ATProtocolURI
            public let cid: CID
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
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer, embed: PostViewEmbedUnion?, replyCount: Int?, repostCount: Int?, likeCount: Int?, quoteCount: Int?, indexedAt: ATProtocolDate, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, threadgate: ThreadgateView?
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
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embed, forKey: .embed)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(replyCount, forKey: .replyCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(repostCount, forKey: .repostCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeCount, forKey: .likeCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(quoteCount, forKey: .quoteCount)
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(threadgate, forKey: .threadgate)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            
            
            
            
            let recordValue = try record.toCBORValue()
            map = map.adding(key: "record", value: recordValue)
            
            
            
            if let value = embed {
                // Encode optional property even if it's an empty array for CBOR
                
                let embedValue = try value.toCBORValue()
                map = map.adding(key: "embed", value: embedValue)
            }
            
            
            
            if let value = replyCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let replyCountValue = try value.toCBORValue()
                map = map.adding(key: "replyCount", value: replyCountValue)
            }
            
            
            
            if let value = repostCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let repostCountValue = try value.toCBORValue()
                map = map.adding(key: "repostCount", value: repostCountValue)
            }
            
            
            
            if let value = likeCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let likeCountValue = try value.toCBORValue()
                map = map.adding(key: "likeCount", value: likeCountValue)
            }
            
            
            
            if let value = quoteCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let quoteCountValue = try value.toCBORValue()
                map = map.adding(key: "quoteCount", value: quoteCountValue)
            }
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            
            
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
            
            
            
            if let value = threadgate {
                // Encode optional property even if it's an empty array for CBOR
                
                let threadgateValue = try value.toCBORValue()
                map = map.adding(key: "threadgate", value: threadgateValue)
            }
            
            

            return map
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
            public let pinned: Bool?

        // Standard initializer
        public init(
            repost: ATProtocolURI?, like: ATProtocolURI?, threadMuted: Bool?, replyDisabled: Bool?, embeddingDisabled: Bool?, pinned: Bool?
        ) {
            
            self.repost = repost
            self.like = like
            self.threadMuted = threadMuted
            self.replyDisabled = replyDisabled
            self.embeddingDisabled = embeddingDisabled
            self.pinned = pinned
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
            do {
                
                self.pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)
                
            } catch {
                LogManager.logError("Decoding error for property 'pinned': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(repost, forKey: .repost)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(like, forKey: .like)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(threadMuted, forKey: .threadMuted)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(replyDisabled, forKey: .replyDisabled)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(embeddingDisabled, forKey: .embeddingDisabled)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(pinned, forKey: .pinned)
            
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
            if let value = pinned {
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

            
            
            if let value = repost {
                // Encode optional property even if it's an empty array for CBOR
                
                let repostValue = try value.toCBORValue()
                map = map.adding(key: "repost", value: repostValue)
            }
            
            
            
            if let value = like {
                // Encode optional property even if it's an empty array for CBOR
                
                let likeValue = try value.toCBORValue()
                map = map.adding(key: "like", value: likeValue)
            }
            
            
            
            if let value = threadMuted {
                // Encode optional property even if it's an empty array for CBOR
                
                let threadMutedValue = try value.toCBORValue()
                map = map.adding(key: "threadMuted", value: threadMutedValue)
            }
            
            
            
            if let value = replyDisabled {
                // Encode optional property even if it's an empty array for CBOR
                
                let replyDisabledValue = try value.toCBORValue()
                map = map.adding(key: "replyDisabled", value: replyDisabledValue)
            }
            
            
            
            if let value = embeddingDisabled {
                // Encode optional property even if it's an empty array for CBOR
                
                let embeddingDisabledValue = try value.toCBORValue()
                map = map.adding(key: "embeddingDisabled", value: embeddingDisabledValue)
            }
            
            
            
            if let value = pinned {
                // Encode optional property even if it's an empty array for CBOR
                
                let pinnedValue = try value.toCBORValue()
                map = map.adding(key: "pinned", value: pinnedValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case repost
            case like
            case threadMuted
            case replyDisabled
            case embeddingDisabled
            case pinned
        }
    }
        
public struct ThreadContext: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#threadContext"
            public let rootAuthorLike: ATProtocolURI?

        // Standard initializer
        public init(
            rootAuthorLike: ATProtocolURI?
        ) {
            
            self.rootAuthorLike = rootAuthorLike
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.rootAuthorLike = try container.decodeIfPresent(ATProtocolURI.self, forKey: .rootAuthorLike)
                
            } catch {
                LogManager.logError("Decoding error for property 'rootAuthorLike': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(rootAuthorLike, forKey: .rootAuthorLike)
            
        }

        public func hash(into hasher: inout Hasher) {
            if let value = rootAuthorLike {
                hasher.combine(value)
            } else {
                hasher.combine(nil as Int?)
            }
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if rootAuthorLike != other.rootAuthorLike {
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

            
            
            if let value = rootAuthorLike {
                // Encode optional property even if it's an empty array for CBOR
                
                let rootAuthorLikeValue = try value.toCBORValue()
                map = map.adding(key: "rootAuthorLike", value: rootAuthorLikeValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case rootAuthorLike
        }
    }
        
public struct FeedViewPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#feedViewPost"
            public let post: PostView
            public let reply: ReplyRef?
            public let reason: FeedViewPostReasonUnion?
            public let feedContext: String?
            public let reqId: String?

        // Standard initializer
        public init(
            post: PostView, reply: ReplyRef?, reason: FeedViewPostReasonUnion?, feedContext: String?, reqId: String?
        ) {
            
            self.post = post
            self.reply = reply
            self.reason = reason
            self.feedContext = feedContext
            self.reqId = reqId
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
            do {
                
                self.reqId = try container.decodeIfPresent(String.self, forKey: .reqId)
                
            } catch {
                LogManager.logError("Decoding error for property 'reqId': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reply, forKey: .reply)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reason, forKey: .reason)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(feedContext, forKey: .feedContext)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reqId, forKey: .reqId)
            
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
            if let value = reqId {
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
            
            
            if reqId != other.reqId {
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

            
            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            if let value = reply {
                // Encode optional property even if it's an empty array for CBOR
                
                let replyValue = try value.toCBORValue()
                map = map.adding(key: "reply", value: replyValue)
            }
            
            
            
            if let value = reason {
                // Encode optional property even if it's an empty array for CBOR
                
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            
            
            
            if let value = feedContext {
                // Encode optional property even if it's an empty array for CBOR
                
                let feedContextValue = try value.toCBORValue()
                map = map.adding(key: "feedContext", value: feedContextValue)
            }
            
            
            
            if let value = reqId {
                // Encode optional property even if it's an empty array for CBOR
                
                let reqIdValue = try value.toCBORValue()
                map = map.adding(key: "reqId", value: reqIdValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case reply
            case reason
            case feedContext
            case reqId
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(grandparentAuthor, forKey: .grandparentAuthor)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let rootValue = try root.toCBORValue()
            map = map.adding(key: "root", value: rootValue)
            
            
            
            
            let parentValue = try parent.toCBORValue()
            map = map.adding(key: "parent", value: parentValue)
            
            
            
            if let value = grandparentAuthor {
                // Encode optional property even if it's an empty array for CBOR
                
                let grandparentAuthorValue = try value.toCBORValue()
                map = map.adding(key: "grandparentAuthor", value: grandparentAuthorValue)
            }
            
            

            return map
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
            public let uri: ATProtocolURI?
            public let cid: CID?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            by: AppBskyActorDefs.ProfileViewBasic, uri: ATProtocolURI?, cid: CID?, indexedAt: ATProtocolDate
        ) {
            
            self.by = by
            self.uri = uri
            self.cid = cid
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
                
                self.uri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .uri)
                
            } catch {
                LogManager.logError("Decoding error for property 'uri': \(error)")
                throw error
            }
            do {
                
                self.cid = try container.decodeIfPresent(CID.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(uri, forKey: .uri)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)
            
            
            try container.encode(indexedAt, forKey: .indexedAt)
            
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(by)
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
            hasher.combine(indexedAt)
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            guard let other = other as? Self else { return false }
            
            if self.by != other.by {
                return false
            }
            
            
            if uri != other.uri {
                return false
            }
            
            
            if cid != other.cid {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let byValue = try by.toCBORValue()
            map = map.adding(key: "by", value: byValue)
            
            
            
            if let value = uri {
                // Encode optional property even if it's an empty array for CBOR
                
                let uriValue = try value.toCBORValue()
                map = map.adding(key: "uri", value: uriValue)
            }
            
            
            
            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR
                
                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case by
            case uri
            case cid
            case indexedAt
        }
    }
        
public struct ReasonPin: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#reasonPin"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct ThreadViewPost: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#threadViewPost"
            public let post: PostView
            public let parent: ThreadViewPostParentUnion?
            public let replies: [ThreadViewPostRepliesUnion]?
            public let threadContext: ThreadContext?

        // Standard initializer
        public init(
            post: PostView, parent: ThreadViewPostParentUnion?, replies: [ThreadViewPostRepliesUnion]?, threadContext: ThreadContext?
        ) {
            
            self.post = post
            self.parent = parent
            self.replies = replies
            self.threadContext = threadContext
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
            do {
                
                self.threadContext = try container.decodeIfPresent(ThreadContext.self, forKey: .threadContext)
                
            } catch {
                LogManager.logError("Decoding error for property 'threadContext': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            try container.encode(post, forKey: .post)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(parent, forKey: .parent)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(replies, forKey: .replies)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(threadContext, forKey: .threadContext)
            
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
            if let value = threadContext {
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
            
            
            if threadContext != other.threadContext {
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

            
            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            if let value = parent {
                // Encode optional property even if it's an empty array for CBOR
                
                let parentValue = try value.toCBORValue()
                map = map.adding(key: "parent", value: parentValue)
            }
            
            
            
            if let value = replies {
                // Encode optional property even if it's an empty array for CBOR
                
                let repliesValue = try value.toCBORValue()
                map = map.adding(key: "replies", value: repliesValue)
            }
            
            
            
            if let value = threadContext {
                // Encode optional property even if it's an empty array for CBOR
                
                let threadContextValue = try value.toCBORValue()
                map = map.adding(key: "threadContext", value: threadContextValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case post
            case parent
            case replies
            case threadContext
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            let notFoundValue = try notFound.toCBORValue()
            map = map.adding(key: "notFound", value: notFoundValue)
            
            

            return map
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            let blockedValue = try blocked.toCBORValue()
            map = map.adding(key: "blocked", value: blockedValue)
            
            
            
            
            let authorValue = try author.toCBORValue()
            map = map.adding(key: "author", value: authorValue)
            
            

            return map
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
            public let did: DID
            public let viewer: AppBskyActorDefs.ViewerState?

        // Standard initializer
        public init(
            did: DID, viewer: AppBskyActorDefs.ViewerState?
        ) {
            
            self.did = did
            self.viewer = viewer
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                
                self.did = try container.decode(DID.self, forKey: .did)
                
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            

            return map
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
            public let cid: CID
            public let did: DID
            public let creator: AppBskyActorDefs.ProfileView
            public let displayName: String
            public let description: String?
            public let descriptionFacets: [AppBskyRichtextFacet]?
            public let avatar: URI?
            public let likeCount: Int?
            public let acceptsInteractions: Bool?
            public let labels: [ComAtprotoLabelDefs.Label]?
            public let viewer: GeneratorViewerState?
            public let contentMode: String?
            public let indexedAt: ATProtocolDate

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, did: DID, creator: AppBskyActorDefs.ProfileView, displayName: String, description: String?, descriptionFacets: [AppBskyRichtextFacet]?, avatar: URI?, likeCount: Int?, acceptsInteractions: Bool?, labels: [ComAtprotoLabelDefs.Label]?, viewer: GeneratorViewerState?, contentMode: String?, indexedAt: ATProtocolDate
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
            self.contentMode = contentMode
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
                
                self.cid = try container.decode(CID.self, forKey: .cid)
                
            } catch {
                LogManager.logError("Decoding error for property 'cid': \(error)")
                throw error
            }
            do {
                
                self.did = try container.decode(DID.self, forKey: .did)
                
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
                
                self.contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)
                
            } catch {
                LogManager.logError("Decoding error for property 'contentMode': \(error)")
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(description, forKey: .description)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(descriptionFacets, forKey: .descriptionFacets)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(avatar, forKey: .avatar)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(likeCount, forKey: .likeCount)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(acceptsInteractions, forKey: .acceptsInteractions)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(labels, forKey: .labels)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(viewer, forKey: .viewer)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(contentMode, forKey: .contentMode)
            
            
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
            if let value = contentMode {
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
            
            
            if contentMode != other.contentMode {
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let uriValue = try uri.toCBORValue()
            map = map.adding(key: "uri", value: uriValue)
            
            
            
            
            let cidValue = try cid.toCBORValue()
            map = map.adding(key: "cid", value: cidValue)
            
            
            
            
            let didValue = try did.toCBORValue()
            map = map.adding(key: "did", value: didValue)
            
            
            
            
            let creatorValue = try creator.toCBORValue()
            map = map.adding(key: "creator", value: creatorValue)
            
            
            
            
            let displayNameValue = try displayName.toCBORValue()
            map = map.adding(key: "displayName", value: displayNameValue)
            
            
            
            if let value = description {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionValue = try value.toCBORValue()
                map = map.adding(key: "description", value: descriptionValue)
            }
            
            
            
            if let value = descriptionFacets {
                // Encode optional property even if it's an empty array for CBOR
                
                let descriptionFacetsValue = try value.toCBORValue()
                map = map.adding(key: "descriptionFacets", value: descriptionFacetsValue)
            }
            
            
            
            if let value = avatar {
                // Encode optional property even if it's an empty array for CBOR
                
                let avatarValue = try value.toCBORValue()
                map = map.adding(key: "avatar", value: avatarValue)
            }
            
            
            
            if let value = likeCount {
                // Encode optional property even if it's an empty array for CBOR
                
                let likeCountValue = try value.toCBORValue()
                map = map.adding(key: "likeCount", value: likeCountValue)
            }
            
            
            
            if let value = acceptsInteractions {
                // Encode optional property even if it's an empty array for CBOR
                
                let acceptsInteractionsValue = try value.toCBORValue()
                map = map.adding(key: "acceptsInteractions", value: acceptsInteractionsValue)
            }
            
            
            
            if let value = labels {
                // Encode optional property even if it's an empty array for CBOR
                
                let labelsValue = try value.toCBORValue()
                map = map.adding(key: "labels", value: labelsValue)
            }
            
            
            
            if let value = viewer {
                // Encode optional property even if it's an empty array for CBOR
                
                let viewerValue = try value.toCBORValue()
                map = map.adding(key: "viewer", value: viewerValue)
            }
            
            
            
            if let value = contentMode {
                // Encode optional property even if it's an empty array for CBOR
                
                let contentModeValue = try value.toCBORValue()
                map = map.adding(key: "contentMode", value: contentModeValue)
            }
            
            
            
            
            let indexedAtValue = try indexedAt.toCBORValue()
            map = map.adding(key: "indexedAt", value: indexedAtValue)
            
            

            return map
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
            case contentMode
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
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(like, forKey: .like)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            if let value = like {
                // Encode optional property even if it's an empty array for CBOR
                
                let likeValue = try value.toCBORValue()
                map = map.adding(key: "like", value: likeValue)
            }
            
            

            return map
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
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reason, forKey: .reason)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(feedContext, forKey: .feedContext)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let postValue = try post.toCBORValue()
            map = map.adding(key: "post", value: postValue)
            
            
            
            if let value = reason {
                // Encode optional property even if it's an empty array for CBOR
                
                let reasonValue = try value.toCBORValue()
                map = map.adding(key: "reason", value: reasonValue)
            }
            
            
            
            if let value = feedContext {
                // Encode optional property even if it's an empty array for CBOR
                
                let feedContextValue = try value.toCBORValue()
                map = map.adding(key: "feedContext", value: feedContextValue)
            }
            
            

            return map
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            
            let repostValue = try repost.toCBORValue()
            map = map.adding(key: "repost", value: repostValue)
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case repost
        }
    }
        
public struct SkeletonReasonPin: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#skeletonReasonPin"

        // Standard initializer
        public init(
            
        ) {
            
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            
            let _ = decoder  // Acknowledge parameter for empty struct
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {
        }

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            
            return other is Self  // For empty structs, just check the type
            
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.isEqual(to: rhs)
        }

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
        }
    }
        
public struct ThreadgateView: ATProtocolCodable, ATProtocolValue {
            public static let typeIdentifier = "app.bsky.feed.defs#threadgateView"
            public let uri: ATProtocolURI?
            public let cid: CID?
            public let record: ATProtocolValueContainer?
            public let lists: [AppBskyGraphDefs.ListViewBasic]?

        // Standard initializer
        public init(
            uri: ATProtocolURI?, cid: CID?, record: ATProtocolValueContainer?, lists: [AppBskyGraphDefs.ListViewBasic]?
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
                
                self.cid = try container.decodeIfPresent(CID.self, forKey: .cid)
                
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
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(uri, forKey: .uri)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(cid, forKey: .cid)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(record, forKey: .record)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(lists, forKey: .lists)
            
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

        // DAGCBOR encoding with field ordering
        public func toCBORValue() throws -> Any {
            var map = OrderedCBORMap()

            map = map.adding(key: "$type", value: Self.typeIdentifier)

            
            
            if let value = uri {
                // Encode optional property even if it's an empty array for CBOR
                
                let uriValue = try value.toCBORValue()
                map = map.adding(key: "uri", value: uriValue)
            }
            
            
            
            if let value = cid {
                // Encode optional property even if it's an empty array for CBOR
                
                let cidValue = try value.toCBORValue()
                map = map.adding(key: "cid", value: cidValue)
            }
            
            
            
            if let value = record {
                // Encode optional property even if it's an empty array for CBOR
                
                let recordValue = try value.toCBORValue()
                map = map.adding(key: "record", value: recordValue)
            }
            
            
            
            if let value = lists {
                // Encode optional property even if it's an empty array for CBOR
                
                let listsValue = try value.toCBORValue()
                map = map.adding(key: "lists", value: listsValue)
            }
            
            

            return map
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
            public let reqId: String?

        // Standard initializer
        public init(
            item: ATProtocolURI?, event: String?, feedContext: String?, reqId: String?
        ) {
            
            self.item = item
            self.event = event
            self.feedContext = feedContext
            self.reqId = reqId
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
            do {
                
                self.reqId = try container.decodeIfPresent(String.self, forKey: .reqId)
                
            } catch {
                LogManager.logError("Decoding error for property 'reqId': \(error)")
                throw error
            }
            
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(item, forKey: .item)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(event, forKey: .event)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(feedContext, forKey: .feedContext)
            
            
            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(reqId, forKey: .reqId)
            
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
            if let value = reqId {
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
            
            
            if reqId != other.reqId {
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

            
            
            if let value = item {
                // Encode optional property even if it's an empty array for CBOR
                
                let itemValue = try value.toCBORValue()
                map = map.adding(key: "item", value: itemValue)
            }
            
            
            
            if let value = event {
                // Encode optional property even if it's an empty array for CBOR
                
                let eventValue = try value.toCBORValue()
                map = map.adding(key: "event", value: eventValue)
            }
            
            
            
            if let value = feedContext {
                // Encode optional property even if it's an empty array for CBOR
                
                let feedContextValue = try value.toCBORValue()
                map = map.adding(key: "feedContext", value: feedContextValue)
            }
            
            
            
            if let value = reqId {
                // Encode optional property even if it's an empty array for CBOR
                
                let reqIdValue = try value.toCBORValue()
                map = map.adding(key: "reqId", value: reqIdValue)
            }
            
            

            return map
        }

        private enum CodingKeys: String, CodingKey {
            case typeIdentifier = "$type"
            case item
            case event
            case feedContext
            case reqId
        }
    }





public enum PostViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyEmbedImagesView(AppBskyEmbedImages.View)
    case appBskyEmbedVideoView(AppBskyEmbedVideo.View)
    case appBskyEmbedExternalView(AppBskyEmbedExternal.View)
    case appBskyEmbedRecordView(AppBskyEmbedRecord.View)
    case appBskyEmbedRecordWithMediaView(AppBskyEmbedRecordWithMedia.View)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyEmbedImages.View) {
        self = .appBskyEmbedImagesView(value)
    }
    public init(_ value: AppBskyEmbedVideo.View) {
        self = .appBskyEmbedVideoView(value)
    }
    public init(_ value: AppBskyEmbedExternal.View) {
        self = .appBskyEmbedExternalView(value)
    }
    public init(_ value: AppBskyEmbedRecord.View) {
        self = .appBskyEmbedRecordView(value)
    }
    public init(_ value: AppBskyEmbedRecordWithMedia.View) {
        self = .appBskyEmbedRecordWithMediaView(value)
    }

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: PostViewEmbedUnion, rhs: PostViewEmbedUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyEmbedImagesView(let lhsValue),
              .appBskyEmbedImagesView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedVideoView(let lhsValue),
              .appBskyEmbedVideoView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedExternalView(let lhsValue),
              .appBskyEmbedExternalView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordView(let lhsValue),
              .appBskyEmbedRecordView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyEmbedRecordWithMediaView(let lhsValue),
              .appBskyEmbedRecordWithMediaView(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? PostViewEmbedUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyEmbedImagesView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.images#view")
            
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
        case .appBskyEmbedVideoView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.video#view")
            
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
        case .appBskyEmbedRecordView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.record#view")
            
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
        case .appBskyEmbedRecordWithMediaView(let value):
            map = map.adding(key: "$type", value: "app.bsky.embed.recordWithMedia#view")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyEmbedImagesView(let value):
            return value.hasPendingData
        case .appBskyEmbedVideoView(let value):
            return value.hasPendingData
        case .appBskyEmbedExternalView(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordView(let value):
            return value.hasPendingData
        case .appBskyEmbedRecordWithMediaView(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyEmbedImagesView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedImagesView(value)
        case .appBskyEmbedVideoView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedVideoView(value)
        case .appBskyEmbedExternalView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedExternalView(value)
        case .appBskyEmbedRecordView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordView(value)
        case .appBskyEmbedRecordWithMediaView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyEmbedRecordWithMediaView(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum FeedViewPostReasonUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsReasonRepost(AppBskyFeedDefs.ReasonRepost)
    case appBskyFeedDefsReasonPin(AppBskyFeedDefs.ReasonPin)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyFeedDefs.ReasonRepost) {
        self = .appBskyFeedDefsReasonRepost(value)
    }
    public init(_ value: AppBskyFeedDefs.ReasonPin) {
        self = .appBskyFeedDefsReasonPin(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.feed.defs#reasonRepost":
            let value = try AppBskyFeedDefs.ReasonRepost(from: decoder)
            self = .appBskyFeedDefsReasonRepost(value)
        case "app.bsky.feed.defs#reasonPin":
            let value = try AppBskyFeedDefs.ReasonPin(from: decoder)
            self = .appBskyFeedDefsReasonPin(value)
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
        case .appBskyFeedDefsReasonPin(let value):
            try container.encode("app.bsky.feed.defs#reasonPin", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsReasonRepost(let value):
            hasher.combine("app.bsky.feed.defs#reasonRepost")
            hasher.combine(value)
        case .appBskyFeedDefsReasonPin(let value):
            hasher.combine("app.bsky.feed.defs#reasonPin")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: FeedViewPostReasonUnion, rhs: FeedViewPostReasonUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsReasonRepost(let lhsValue),
              .appBskyFeedDefsReasonRepost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsReasonPin(let lhsValue),
              .appBskyFeedDefsReasonPin(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? FeedViewPostReasonUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsReasonRepost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#reasonRepost")
            
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
        case .appBskyFeedDefsReasonPin(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#reasonPin")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyFeedDefsReasonRepost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsReasonPin(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyFeedDefsReasonRepost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsReasonRepost(value)
        case .appBskyFeedDefsReasonPin(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsReasonPin(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum ReplyRefRootUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsPostView(AppBskyFeedDefs.PostView)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyFeedDefs.PostView) {
        self = .appBskyFeedDefsPostView(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ReplyRefRootUnion, rhs: ReplyRefRootUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsPostView(let lhsValue),
              .appBskyFeedDefsPostView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ReplyRefRootUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsPostView(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#postView")
            
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
        case .appBskyFeedDefsNotFoundPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
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
        case .appBskyFeedDefsBlockedPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyFeedDefsPostView(let value):
            return value.hasPendingData
        case .appBskyFeedDefsNotFoundPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsBlockedPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyFeedDefsPostView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsPostView(value)
        case .appBskyFeedDefsNotFoundPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsNotFoundPost(value)
        case .appBskyFeedDefsBlockedPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsBlockedPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum ReplyRefParentUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsPostView(AppBskyFeedDefs.PostView)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyFeedDefs.PostView) {
        self = .appBskyFeedDefsPostView(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ReplyRefParentUnion, rhs: ReplyRefParentUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsPostView(let lhsValue),
              .appBskyFeedDefsPostView(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ReplyRefParentUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsPostView(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#postView")
            
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
        case .appBskyFeedDefsNotFoundPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
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
        case .appBskyFeedDefsBlockedPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyFeedDefsPostView(let value):
            return value.hasPendingData
        case .appBskyFeedDefsNotFoundPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsBlockedPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyFeedDefsPostView(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsPostView(value)
        case .appBskyFeedDefsNotFoundPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsNotFoundPost(value)
        case .appBskyFeedDefsBlockedPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsBlockedPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}



public indirect enum ThreadViewPostParentUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)
    
    case pending(PendingDecodeData)
    
    
    public init(_ value: AppBskyFeedDefs.ThreadViewPost) {
        self = .appBskyFeedDefsThreadViewPost(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        
        let depth = decoder.codingPath.count
        
        // Check if we're at a recursion depth that might cause stack overflow
        if depth > DecodingConfiguration.standard.threshold {
            if DecodingConfiguration.standard.debugMode {
                print("🔄 Deferring deep decode for ThreadViewPostParentUnion at depth \(depth), type: \(typeValue)")
            }
            
            // Get the original JSON data if available
            if let originalData = decoder.userInfo[.originalData] as? Data {
                do {
                    // Extract just the portion we need based on the coding path
                    if let nestedData = try SafeDecoder.extractNestedJSON(from: originalData, at: decoder.codingPath) {
                        self = .pending(PendingDecodeData(rawData: nestedData, type: typeValue))
                        return
                    }
                } catch {
                    // Fall through to minimal data approach if extraction fails
                }
            }
            
            // Fallback if we can't get the nested data - store minimal information
            let minimalData = try JSONEncoder().encode(["$type": typeValue])
            self = .pending(PendingDecodeData(rawData: minimalData, type: typeValue))
            return
        }
        

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        case .pending(let pendingData):
            try container.encode(pendingData.type, forKey: .type)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        case .pending(let pendingData):
            hasher.combine("pending")
            hasher.combine(pendingData.type)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ThreadViewPostParentUnion, rhs: ThreadViewPostParentUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsThreadViewPost(let lhsValue),
              .appBskyFeedDefsThreadViewPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        case (.pending(let lhsData), .pending(let rhsData)):
            return lhsData.type == rhsData.type
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ThreadViewPostParentUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#threadViewPost")
            
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
        case .appBskyFeedDefsNotFoundPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
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
        case .appBskyFeedDefsBlockedPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
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
        
        case .pending(let pendingData):
            map = map.adding(key: "$type", value: pendingData.type)
            return map
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .pending:
            return true
        
        case .appBskyFeedDefsThreadViewPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsNotFoundPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsBlockedPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .pending(let pendingData):
            do {
                // Attempt to decode the full object using the raw data
                switch pendingData.type {
                case "app.bsky.feed.defs#threadViewPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.ThreadViewPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsThreadViewPost(value)
                case "app.bsky.feed.defs#notFoundPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.NotFoundPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsNotFoundPost(value)
                case "app.bsky.feed.defs#blockedPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.BlockedPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsBlockedPost(value)
                default:
                    let unknownValue = ATProtocolValueContainer.string("Unknown type: \(pendingData.type)")
                    self = .unexpected(unknownValue)
                }
            } catch {
                if DecodingConfiguration.standard.debugMode {
                    print("❌ Failed to decode pending data for ThreadViewPostParentUnion: \(error)")
                }
                self = .unexpected(ATProtocolValueContainer.string("Failed to decode: \(error)"))
            }
        
        case .appBskyFeedDefsThreadViewPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsThreadViewPost(value)
        case .appBskyFeedDefsNotFoundPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsNotFoundPost(value)
        case .appBskyFeedDefsBlockedPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsBlockedPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}



public indirect enum ThreadViewPostRepliesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
    case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
    case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
    case unexpected(ATProtocolValueContainer)
    
    case pending(PendingDecodeData)
    
    
    public init(_ value: AppBskyFeedDefs.ThreadViewPost) {
        self = .appBskyFeedDefsThreadViewPost(value)
    }
    public init(_ value: AppBskyFeedDefs.NotFoundPost) {
        self = .appBskyFeedDefsNotFoundPost(value)
    }
    public init(_ value: AppBskyFeedDefs.BlockedPost) {
        self = .appBskyFeedDefsBlockedPost(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        
        let depth = decoder.codingPath.count
        
        // Check if we're at a recursion depth that might cause stack overflow
        if depth > DecodingConfiguration.standard.threshold {
            if DecodingConfiguration.standard.debugMode {
                print("🔄 Deferring deep decode for ThreadViewPostRepliesUnion at depth \(depth), type: \(typeValue)")
            }
            
            // Get the original JSON data if available
            if let originalData = decoder.userInfo[.originalData] as? Data {
                do {
                    // Extract just the portion we need based on the coding path
                    if let nestedData = try SafeDecoder.extractNestedJSON(from: originalData, at: decoder.codingPath) {
                        self = .pending(PendingDecodeData(rawData: nestedData, type: typeValue))
                        return
                    }
                } catch {
                    // Fall through to minimal data approach if extraction fails
                }
            }
            
            // Fallback if we can't get the nested data - store minimal information
            let minimalData = try JSONEncoder().encode(["$type": typeValue])
            self = .pending(PendingDecodeData(rawData: minimalData, type: typeValue))
            return
        }
        

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
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        case .pending(let pendingData):
            try container.encode(pendingData.type, forKey: .type)
        
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
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        case .pending(let pendingData):
            hasher.combine("pending")
            hasher.combine(pendingData.type)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: ThreadViewPostRepliesUnion, rhs: ThreadViewPostRepliesUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsThreadViewPost(let lhsValue),
              .appBskyFeedDefsThreadViewPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsNotFoundPost(let lhsValue),
              .appBskyFeedDefsNotFoundPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsBlockedPost(let lhsValue),
              .appBskyFeedDefsBlockedPost(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        case (.pending(let lhsData), .pending(let rhsData)):
            return lhsData.type == rhsData.type
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? ThreadViewPostRepliesUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsThreadViewPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#threadViewPost")
            
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
        case .appBskyFeedDefsNotFoundPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#notFoundPost")
            
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
        case .appBskyFeedDefsBlockedPost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#blockedPost")
            
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
        
        case .pending(let pendingData):
            map = map.adding(key: "$type", value: pendingData.type)
            return map
        
        }
    }
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .pending:
            return true
        
        case .appBskyFeedDefsThreadViewPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsNotFoundPost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsBlockedPost(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .pending(let pendingData):
            do {
                // Attempt to decode the full object using the raw data
                switch pendingData.type {
                case "app.bsky.feed.defs#threadViewPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.ThreadViewPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsThreadViewPost(value)
                case "app.bsky.feed.defs#notFoundPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.NotFoundPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsNotFoundPost(value)
                case "app.bsky.feed.defs#blockedPost":
                    let value = try await SafeDecoder.decode(
                        AppBskyFeedDefs.BlockedPost.self,
                        from: pendingData.rawData
                    )
                    self = .appBskyFeedDefsBlockedPost(value)
                default:
                    let unknownValue = ATProtocolValueContainer.string("Unknown type: \(pendingData.type)")
                    self = .unexpected(unknownValue)
                }
            } catch {
                if DecodingConfiguration.standard.debugMode {
                    print("❌ Failed to decode pending data for ThreadViewPostRepliesUnion: \(error)")
                }
                self = .unexpected(ATProtocolValueContainer.string("Failed to decode: \(error)"))
            }
        
        case .appBskyFeedDefsThreadViewPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsThreadViewPost(value)
        case .appBskyFeedDefsNotFoundPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsNotFoundPost(value)
        case .appBskyFeedDefsBlockedPost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsBlockedPost(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}




public enum SkeletonFeedPostReasonUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case appBskyFeedDefsSkeletonReasonRepost(AppBskyFeedDefs.SkeletonReasonRepost)
    case appBskyFeedDefsSkeletonReasonPin(AppBskyFeedDefs.SkeletonReasonPin)
    case unexpected(ATProtocolValueContainer)
    
    public init(_ value: AppBskyFeedDefs.SkeletonReasonRepost) {
        self = .appBskyFeedDefsSkeletonReasonRepost(value)
    }
    public init(_ value: AppBskyFeedDefs.SkeletonReasonPin) {
        self = .appBskyFeedDefsSkeletonReasonPin(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)
        

        switch typeValue {
        case "app.bsky.feed.defs#skeletonReasonRepost":
            let value = try AppBskyFeedDefs.SkeletonReasonRepost(from: decoder)
            self = .appBskyFeedDefsSkeletonReasonRepost(value)
        case "app.bsky.feed.defs#skeletonReasonPin":
            let value = try AppBskyFeedDefs.SkeletonReasonPin(from: decoder)
            self = .appBskyFeedDefsSkeletonReasonPin(value)
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
        case .appBskyFeedDefsSkeletonReasonPin(let value):
            try container.encode("app.bsky.feed.defs#skeletonReasonPin", forKey: .type)
            try value.encode(to: encoder)
        case .unexpected(let container):
            try container.encode(to: encoder)
        
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .appBskyFeedDefsSkeletonReasonRepost(let value):
            hasher.combine("app.bsky.feed.defs#skeletonReasonRepost")
            hasher.combine(value)
        case .appBskyFeedDefsSkeletonReasonPin(let value):
            hasher.combine("app.bsky.feed.defs#skeletonReasonPin")
            hasher.combine(value)
        case .unexpected(let container):
            hasher.combine("unexpected")
            hasher.combine(container)
        
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    public static func == (lhs: SkeletonFeedPostReasonUnion, rhs: SkeletonFeedPostReasonUnion) -> Bool {
        switch (lhs, rhs) {
        case (.appBskyFeedDefsSkeletonReasonRepost(let lhsValue),
              .appBskyFeedDefsSkeletonReasonRepost(let rhsValue)):
            return lhsValue == rhsValue
        case (.appBskyFeedDefsSkeletonReasonPin(let lhsValue),
              .appBskyFeedDefsSkeletonReasonPin(let rhsValue)):
            return lhsValue == rhsValue
        case (.unexpected(let lhsValue), .unexpected(let rhsValue)):
            return lhsValue.isEqual(to: rhsValue)
        
        default:
            return false
        }
    }
    
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? SkeletonFeedPostReasonUnion else { return false }
        return self == other
    }
    
    // DAGCBOR encoding with field ordering
    public func toCBORValue() throws -> Any {
        // Create an ordered map to maintain field order
        var map = OrderedCBORMap()
        
        switch self {
        case .appBskyFeedDefsSkeletonReasonRepost(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#skeletonReasonRepost")
            
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
        case .appBskyFeedDefsSkeletonReasonPin(let value):
            map = map.adding(key: "$type", value: "app.bsky.feed.defs#skeletonReasonPin")
            
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
    
    /// Property that indicates if this enum contains pending data that needs loading
    public var hasPendingData: Bool {
        switch self {
        
        case .appBskyFeedDefsSkeletonReasonRepost(let value):
            return value.hasPendingData
        case .appBskyFeedDefsSkeletonReasonPin(let value):
            return value.hasPendingData
        case .unexpected:
            return false
        }
    }
    
    /// Attempts to load any pending data in this enum or its children
    public mutating func loadPendingData() async {
        switch self {
        
        case .appBskyFeedDefsSkeletonReasonRepost(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsSkeletonReasonRepost(value)
        case .appBskyFeedDefsSkeletonReasonPin(var value):
            // Since ATProtocolValue already includes PendingDataLoadable,
            // we can directly call loadPendingData without conditional casting
            await value.loadPendingData()
            // Update the enum case with the potentially updated value
            self = .appBskyFeedDefsSkeletonReasonPin(value)
        case .unexpected:
            // Nothing to load for unexpected values
            break
        }
    }
}


}


                           
