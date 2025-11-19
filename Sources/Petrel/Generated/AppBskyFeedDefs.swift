import Foundation

// lexicon: 1, id: app.bsky.feed.defs

public enum AppBskyFeedDefs {
    public static let typeIdentifier = "app.bsky.feed.defs"

    public struct PostView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.defs#postView"
        public let uri: ATProtocolURI
        public let cid: CID
        public let author: AppBskyActorDefs.ProfileViewBasic
        public let record: ATProtocolValueContainer
        public let embed: PostViewEmbedUnion?
        public let bookmarkCount: Int?
        public let replyCount: Int?
        public let repostCount: Int?
        public let likeCount: Int?
        public let quoteCount: Int?
        public let indexedAt: ATProtocolDate
        public let viewer: ViewerState?
        public let labels: [ComAtprotoLabelDefs.Label]?
        public let threadgate: ThreadgateView?
        public let debug: ATProtocolValueContainer?

        // Standard initializer
        public init(
            uri: ATProtocolURI, cid: CID, author: AppBskyActorDefs.ProfileViewBasic, record: ATProtocolValueContainer, embed: PostViewEmbedUnion?, bookmarkCount: Int?, replyCount: Int?, repostCount: Int?, likeCount: Int?, quoteCount: Int?, indexedAt: ATProtocolDate, viewer: ViewerState?, labels: [ComAtprotoLabelDefs.Label]?, threadgate: ThreadgateView?, debug: ATProtocolValueContainer?
        ) {
            self.uri = uri
            self.cid = cid
            self.author = author
            self.record = record
            self.embed = embed
            self.bookmarkCount = bookmarkCount
            self.replyCount = replyCount
            self.repostCount = repostCount
            self.likeCount = likeCount
            self.quoteCount = quoteCount
            self.indexedAt = indexedAt
            self.viewer = viewer
            self.labels = labels
            self.threadgate = threadgate
            self.debug = debug
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                author = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")

                throw error
            }
            do {
                record = try container.decode(ATProtocolValueContainer.self, forKey: .record)

            } catch {
                LogManager.logError("Decoding error for required property 'record': \(error)")

                throw error
            }
            do {
                embed = try container.decodeIfPresent(PostViewEmbedUnion.self, forKey: .embed)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'embed': \(error)")

                throw error
            }
            do {
                bookmarkCount = try container.decodeIfPresent(Int.self, forKey: .bookmarkCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'bookmarkCount': \(error)")

                throw error
            }
            do {
                replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'replyCount': \(error)")

                throw error
            }
            do {
                repostCount = try container.decodeIfPresent(Int.self, forKey: .repostCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'repostCount': \(error)")

                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'likeCount': \(error)")

                throw error
            }
            do {
                quoteCount = try container.decodeIfPresent(Int.self, forKey: .quoteCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'quoteCount': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

                throw error
            }
            do {
                viewer = try container.decodeIfPresent(ViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")

                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")

                throw error
            }
            do {
                threadgate = try container.decodeIfPresent(ThreadgateView.self, forKey: .threadgate)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'threadgate': \(error)")

                throw error
            }
            do {
                debug = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .debug)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'debug': \(error)")

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
            try container.encodeIfPresent(bookmarkCount, forKey: .bookmarkCount)

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

            // Encode optional property even if it's an empty array
            try container.encodeIfPresent(debug, forKey: .debug)
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
            if let value = bookmarkCount {
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
            if let value = debug {
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

            if author != other.author {
                return false
            }

            if record != other.record {
                return false
            }

            if embed != other.embed {
                return false
            }

            if bookmarkCount != other.bookmarkCount {
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

            if indexedAt != other.indexedAt {
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

            if debug != other.debug {
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

            if let value = bookmarkCount {
                // Encode optional property even if it's an empty array for CBOR

                let bookmarkCountValue = try value.toCBORValue()
                map = map.adding(key: "bookmarkCount", value: bookmarkCountValue)
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

            if let value = debug {
                // Encode optional property even if it's an empty array for CBOR

                let debugValue = try value.toCBORValue()
                map = map.adding(key: "debug", value: debugValue)
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
            case bookmarkCount
            case replyCount
            case repostCount
            case likeCount
            case quoteCount
            case indexedAt
            case viewer
            case labels
            case threadgate
            case debug
        }
    }

    public struct ViewerState: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.feed.defs#viewerState"
        public let repost: ATProtocolURI?
        public let like: ATProtocolURI?
        public let bookmarked: Bool?
        public let threadMuted: Bool?
        public let replyDisabled: Bool?
        public let embeddingDisabled: Bool?
        public let pinned: Bool?

        // Standard initializer
        public init(
            repost: ATProtocolURI?, like: ATProtocolURI?, bookmarked: Bool?, threadMuted: Bool?, replyDisabled: Bool?, embeddingDisabled: Bool?, pinned: Bool?
        ) {
            self.repost = repost
            self.like = like
            self.bookmarked = bookmarked
            self.threadMuted = threadMuted
            self.replyDisabled = replyDisabled
            self.embeddingDisabled = embeddingDisabled
            self.pinned = pinned
        }

        // Codable initializer
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            do {
                repost = try container.decodeIfPresent(ATProtocolURI.self, forKey: .repost)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'repost': \(error)")

                throw error
            }
            do {
                like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'like': \(error)")

                throw error
            }
            do {
                bookmarked = try container.decodeIfPresent(Bool.self, forKey: .bookmarked)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'bookmarked': \(error)")

                throw error
            }
            do {
                threadMuted = try container.decodeIfPresent(Bool.self, forKey: .threadMuted)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'threadMuted': \(error)")

                throw error
            }
            do {
                replyDisabled = try container.decodeIfPresent(Bool.self, forKey: .replyDisabled)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'replyDisabled': \(error)")

                throw error
            }
            do {
                embeddingDisabled = try container.decodeIfPresent(Bool.self, forKey: .embeddingDisabled)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'embeddingDisabled': \(error)")

                throw error
            }
            do {
                pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'pinned': \(error)")

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
            try container.encodeIfPresent(bookmarked, forKey: .bookmarked)

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
            if let value = bookmarked {
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

            if bookmarked != other.bookmarked {
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

            if let value = bookmarked {
                // Encode optional property even if it's an empty array for CBOR

                let bookmarkedValue = try value.toCBORValue()
                map = map.adding(key: "bookmarked", value: bookmarkedValue)
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
            case bookmarked
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
                rootAuthorLike = try container.decodeIfPresent(ATProtocolURI.self, forKey: .rootAuthorLike)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'rootAuthorLike': \(error)")

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
                post = try container.decode(PostView.self, forKey: .post)

            } catch {
                LogManager.logError("Decoding error for required property 'post': \(error)")

                throw error
            }
            do {
                reply = try container.decodeIfPresent(ReplyRef.self, forKey: .reply)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reply': \(error)")

                throw error
            }
            do {
                reason = try container.decodeIfPresent(FeedViewPostReasonUnion.self, forKey: .reason)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")

                throw error
            }
            do {
                feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'feedContext': \(error)")

                throw error
            }
            do {
                reqId = try container.decodeIfPresent(String.self, forKey: .reqId)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reqId': \(error)")

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

            if post != other.post {
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
                root = try container.decode(ReplyRefRootUnion.self, forKey: .root)

            } catch {
                LogManager.logError("Decoding error for required property 'root': \(error)")

                throw error
            }
            do {
                parent = try container.decode(ReplyRefParentUnion.self, forKey: .parent)

            } catch {
                LogManager.logError("Decoding error for required property 'parent': \(error)")

                throw error
            }
            do {
                grandparentAuthor = try container.decodeIfPresent(AppBskyActorDefs.ProfileViewBasic.self, forKey: .grandparentAuthor)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'grandparentAuthor': \(error)")

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

            if root != other.root {
                return false
            }

            if parent != other.parent {
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
                by = try container.decode(AppBskyActorDefs.ProfileViewBasic.self, forKey: .by)

            } catch {
                LogManager.logError("Decoding error for required property 'by': \(error)")

                throw error
            }
            do {
                uri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'cid': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

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

            if by != other.by {
                return false
            }

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if indexedAt != other.indexedAt {
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
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type
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
                post = try container.decode(PostView.self, forKey: .post)

            } catch {
                LogManager.logError("Decoding error for required property 'post': \(error)")

                throw error
            }
            do {
                parent = try container.decodeIfPresent(ThreadViewPostParentUnion.self, forKey: .parent)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'parent': \(error)")

                throw error
            }
            do {
                replies = try container.decodeIfPresent([ThreadViewPostRepliesUnion].self, forKey: .replies)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'replies': \(error)")

                throw error
            }
            do {
                threadContext = try container.decodeIfPresent(ThreadContext.self, forKey: .threadContext)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'threadContext': \(error)")

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

            if post != other.post {
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
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                notFound = try container.decode(Bool.self, forKey: .notFound)

            } catch {
                LogManager.logError("Decoding error for required property 'notFound': \(error)")

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

            if uri != other.uri {
                return false
            }

            if notFound != other.notFound {
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
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                blocked = try container.decode(Bool.self, forKey: .blocked)

            } catch {
                LogManager.logError("Decoding error for required property 'blocked': \(error)")

                throw error
            }
            do {
                author = try container.decode(BlockedAuthor.self, forKey: .author)

            } catch {
                LogManager.logError("Decoding error for required property 'author': \(error)")

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

            if uri != other.uri {
                return false
            }

            if blocked != other.blocked {
                return false
            }

            if author != other.author {
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
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")

                throw error
            }
            do {
                viewer = try container.decodeIfPresent(AppBskyActorDefs.ViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")

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

            if did != other.did {
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
                uri = try container.decode(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logError("Decoding error for required property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decode(CID.self, forKey: .cid)

            } catch {
                LogManager.logError("Decoding error for required property 'cid': \(error)")

                throw error
            }
            do {
                did = try container.decode(DID.self, forKey: .did)

            } catch {
                LogManager.logError("Decoding error for required property 'did': \(error)")

                throw error
            }
            do {
                creator = try container.decode(AppBskyActorDefs.ProfileView.self, forKey: .creator)

            } catch {
                LogManager.logError("Decoding error for required property 'creator': \(error)")

                throw error
            }
            do {
                displayName = try container.decode(String.self, forKey: .displayName)

            } catch {
                LogManager.logError("Decoding error for required property 'displayName': \(error)")

                throw error
            }
            do {
                description = try container.decodeIfPresent(String.self, forKey: .description)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'description': \(error)")

                throw error
            }
            do {
                descriptionFacets = try container.decodeIfPresent([AppBskyRichtextFacet].self, forKey: .descriptionFacets)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'descriptionFacets': \(error)")

                throw error
            }
            do {
                avatar = try container.decodeIfPresent(URI.self, forKey: .avatar)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'avatar': \(error)")

                throw error
            }
            do {
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'likeCount': \(error)")

                throw error
            }
            do {
                acceptsInteractions = try container.decodeIfPresent(Bool.self, forKey: .acceptsInteractions)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'acceptsInteractions': \(error)")

                throw error
            }
            do {
                labels = try container.decodeIfPresent([ComAtprotoLabelDefs.Label].self, forKey: .labels)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'labels': \(error)")

                throw error
            }
            do {
                viewer = try container.decodeIfPresent(GeneratorViewerState.self, forKey: .viewer)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'viewer': \(error)")

                throw error
            }
            do {
                contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'contentMode': \(error)")

                throw error
            }
            do {
                indexedAt = try container.decode(ATProtocolDate.self, forKey: .indexedAt)

            } catch {
                LogManager.logError("Decoding error for required property 'indexedAt': \(error)")

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

            if uri != other.uri {
                return false
            }

            if cid != other.cid {
                return false
            }

            if did != other.did {
                return false
            }

            if creator != other.creator {
                return false
            }

            if displayName != other.displayName {
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

            if indexedAt != other.indexedAt {
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
                like = try container.decodeIfPresent(ATProtocolURI.self, forKey: .like)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'like': \(error)")

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
                post = try container.decode(ATProtocolURI.self, forKey: .post)

            } catch {
                LogManager.logError("Decoding error for required property 'post': \(error)")

                throw error
            }
            do {
                reason = try container.decodeIfPresent(SkeletonFeedPostReasonUnion.self, forKey: .reason)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reason': \(error)")

                throw error
            }
            do {
                feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'feedContext': \(error)")

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

            if post != other.post {
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
                repost = try container.decode(ATProtocolURI.self, forKey: .repost)

            } catch {
                LogManager.logError("Decoding error for required property 'repost': \(error)")

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

            if repost != other.repost {
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
        ) {}

        // Codable initializer
        public init(from decoder: Decoder) throws {
            _ = decoder // Acknowledge parameter for empty struct
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Self.typeIdentifier, forKey: .typeIdentifier)
        }

        public func hash(into hasher: inout Hasher) {}

        public func isEqual(to other: any ATProtocolValue) -> Bool {
            return other is Self // For empty structs, just check the type
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
                uri = try container.decodeIfPresent(ATProtocolURI.self, forKey: .uri)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'uri': \(error)")

                throw error
            }
            do {
                cid = try container.decodeIfPresent(CID.self, forKey: .cid)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'cid': \(error)")

                throw error
            }
            do {
                record = try container.decodeIfPresent(ATProtocolValueContainer.self, forKey: .record)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'record': \(error)")

                throw error
            }
            do {
                lists = try container.decodeIfPresent([AppBskyGraphDefs.ListViewBasic].self, forKey: .lists)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'lists': \(error)")

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
                item = try container.decodeIfPresent(ATProtocolURI.self, forKey: .item)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'item': \(error)")

                throw error
            }
            do {
                event = try container.decodeIfPresent(String.self, forKey: .event)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'event': \(error)")

                throw error
            }
            do {
                feedContext = try container.decodeIfPresent(String.self, forKey: .feedContext)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'feedContext': \(error)")

                throw error
            }
            do {
                reqId = try container.decodeIfPresent(String.self, forKey: .reqId)

            } catch {
                LogManager.logDebug("Decoding error for optional property 'reqId': \(error)")

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

    public indirect enum PostViewEmbedUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .appBskyEmbedImagesView(value):
                try container.encode("app.bsky.embed.images#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedVideoView(value):
                try container.encode("app.bsky.embed.video#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedExternalView(value):
                try container.encode("app.bsky.embed.external#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordView(value):
                try container.encode("app.bsky.embed.record#view", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyEmbedRecordWithMediaView(value):
                try container.encode("app.bsky.embed.recordWithMedia#view", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyEmbedImagesView(value):
                hasher.combine("app.bsky.embed.images#view")
                hasher.combine(value)
            case let .appBskyEmbedVideoView(value):
                hasher.combine("app.bsky.embed.video#view")
                hasher.combine(value)
            case let .appBskyEmbedExternalView(value):
                hasher.combine("app.bsky.embed.external#view")
                hasher.combine(value)
            case let .appBskyEmbedRecordView(value):
                hasher.combine("app.bsky.embed.record#view")
                hasher.combine(value)
            case let .appBskyEmbedRecordWithMediaView(value):
                hasher.combine("app.bsky.embed.recordWithMedia#view")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: PostViewEmbedUnion, rhs: PostViewEmbedUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyEmbedImagesView(lhsValue),
                .appBskyEmbedImagesView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedVideoView(lhsValue),
                .appBskyEmbedVideoView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedExternalView(lhsValue),
                .appBskyEmbedExternalView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordView(lhsValue),
                .appBskyEmbedRecordView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyEmbedRecordWithMediaView(lhsValue),
                .appBskyEmbedRecordWithMediaView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyEmbedImagesView(value):
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
            case let .appBskyEmbedVideoView(value):
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
            case let .appBskyEmbedRecordView(value):
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
            case let .appBskyEmbedRecordWithMediaView(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
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
            case let .appBskyFeedDefsReasonRepost(value):
                try container.encode("app.bsky.feed.defs#reasonRepost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsReasonPin(value):
                try container.encode("app.bsky.feed.defs#reasonPin", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsReasonRepost(value):
                hasher.combine("app.bsky.feed.defs#reasonRepost")
                hasher.combine(value)
            case let .appBskyFeedDefsReasonPin(value):
                hasher.combine("app.bsky.feed.defs#reasonPin")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: FeedViewPostReasonUnion, rhs: FeedViewPostReasonUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsReasonRepost(lhsValue),
                .appBskyFeedDefsReasonRepost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsReasonPin(lhsValue),
                .appBskyFeedDefsReasonPin(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedDefsReasonRepost(value):
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
            case let .appBskyFeedDefsReasonPin(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ReplyRefRootUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .appBskyFeedDefsPostView(value):
                try container.encode("app.bsky.feed.defs#postView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsNotFoundPost(value):
                try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsBlockedPost(value):
                try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsPostView(value):
                hasher.combine("app.bsky.feed.defs#postView")
                hasher.combine(value)
            case let .appBskyFeedDefsNotFoundPost(value):
                hasher.combine("app.bsky.feed.defs#notFoundPost")
                hasher.combine(value)
            case let .appBskyFeedDefsBlockedPost(value):
                hasher.combine("app.bsky.feed.defs#blockedPost")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ReplyRefRootUnion, rhs: ReplyRefRootUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsPostView(lhsValue),
                .appBskyFeedDefsPostView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsNotFoundPost(lhsValue),
                .appBskyFeedDefsNotFoundPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsBlockedPost(lhsValue),
                .appBskyFeedDefsBlockedPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedDefsPostView(value):
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
            case let .appBskyFeedDefsNotFoundPost(value):
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
            case let .appBskyFeedDefsBlockedPost(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ReplyRefParentUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
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
            case let .appBskyFeedDefsPostView(value):
                try container.encode("app.bsky.feed.defs#postView", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsNotFoundPost(value):
                try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsBlockedPost(value):
                try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsPostView(value):
                hasher.combine("app.bsky.feed.defs#postView")
                hasher.combine(value)
            case let .appBskyFeedDefsNotFoundPost(value):
                hasher.combine("app.bsky.feed.defs#notFoundPost")
                hasher.combine(value)
            case let .appBskyFeedDefsBlockedPost(value):
                hasher.combine("app.bsky.feed.defs#blockedPost")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ReplyRefParentUnion, rhs: ReplyRefParentUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsPostView(lhsValue),
                .appBskyFeedDefsPostView(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsNotFoundPost(lhsValue),
                .appBskyFeedDefsNotFoundPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsBlockedPost(lhsValue),
                .appBskyFeedDefsBlockedPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedDefsPostView(value):
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
            case let .appBskyFeedDefsNotFoundPost(value):
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
            case let .appBskyFeedDefsBlockedPost(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ThreadViewPostParentUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
        case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
        case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
        case unexpected(ATProtocolValueContainer)
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
            case let .appBskyFeedDefsThreadViewPost(value):
                try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsNotFoundPost(value):
                try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsBlockedPost(value):
                try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsThreadViewPost(value):
                hasher.combine("app.bsky.feed.defs#threadViewPost")
                hasher.combine(value)
            case let .appBskyFeedDefsNotFoundPost(value):
                hasher.combine("app.bsky.feed.defs#notFoundPost")
                hasher.combine(value)
            case let .appBskyFeedDefsBlockedPost(value):
                hasher.combine("app.bsky.feed.defs#blockedPost")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ThreadViewPostParentUnion, rhs: ThreadViewPostParentUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsThreadViewPost(lhsValue),
                .appBskyFeedDefsThreadViewPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsNotFoundPost(lhsValue),
                .appBskyFeedDefsNotFoundPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsBlockedPost(lhsValue),
                .appBskyFeedDefsBlockedPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
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
            case let .appBskyFeedDefsThreadViewPost(value):
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
            case let .appBskyFeedDefsNotFoundPost(value):
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
            case let .appBskyFeedDefsBlockedPost(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }

    public indirect enum ThreadViewPostRepliesUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
        case appBskyFeedDefsThreadViewPost(AppBskyFeedDefs.ThreadViewPost)
        case appBskyFeedDefsNotFoundPost(AppBskyFeedDefs.NotFoundPost)
        case appBskyFeedDefsBlockedPost(AppBskyFeedDefs.BlockedPost)
        case unexpected(ATProtocolValueContainer)
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
            case let .appBskyFeedDefsThreadViewPost(value):
                try container.encode("app.bsky.feed.defs#threadViewPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsNotFoundPost(value):
                try container.encode("app.bsky.feed.defs#notFoundPost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsBlockedPost(value):
                try container.encode("app.bsky.feed.defs#blockedPost", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsThreadViewPost(value):
                hasher.combine("app.bsky.feed.defs#threadViewPost")
                hasher.combine(value)
            case let .appBskyFeedDefsNotFoundPost(value):
                hasher.combine("app.bsky.feed.defs#notFoundPost")
                hasher.combine(value)
            case let .appBskyFeedDefsBlockedPost(value):
                hasher.combine("app.bsky.feed.defs#blockedPost")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: ThreadViewPostRepliesUnion, rhs: ThreadViewPostRepliesUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsThreadViewPost(lhsValue),
                .appBskyFeedDefsThreadViewPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsNotFoundPost(lhsValue),
                .appBskyFeedDefsNotFoundPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsBlockedPost(lhsValue),
                .appBskyFeedDefsBlockedPost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
                return lhsValue.isEqual(to: rhsValue)
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
            case let .appBskyFeedDefsThreadViewPost(value):
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
            case let .appBskyFeedDefsNotFoundPost(value):
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
            case let .appBskyFeedDefsBlockedPost(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
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
            case let .appBskyFeedDefsSkeletonReasonRepost(value):
                try container.encode("app.bsky.feed.defs#skeletonReasonRepost", forKey: .type)
                try value.encode(to: encoder)
            case let .appBskyFeedDefsSkeletonReasonPin(value):
                try container.encode("app.bsky.feed.defs#skeletonReasonPin", forKey: .type)
                try value.encode(to: encoder)
            case let .unexpected(container):
                try container.encode(to: encoder)
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .appBskyFeedDefsSkeletonReasonRepost(value):
                hasher.combine("app.bsky.feed.defs#skeletonReasonRepost")
                hasher.combine(value)
            case let .appBskyFeedDefsSkeletonReasonPin(value):
                hasher.combine("app.bsky.feed.defs#skeletonReasonPin")
                hasher.combine(value)
            case let .unexpected(container):
                hasher.combine("unexpected")
                hasher.combine(container)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        public static func == (lhs: SkeletonFeedPostReasonUnion, rhs: SkeletonFeedPostReasonUnion) -> Bool {
            switch (lhs, rhs) {
            case let (
                .appBskyFeedDefsSkeletonReasonRepost(lhsValue),
                .appBskyFeedDefsSkeletonReasonRepost(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (
                .appBskyFeedDefsSkeletonReasonPin(lhsValue),
                .appBskyFeedDefsSkeletonReasonPin(rhsValue)
            ):
                return lhsValue == rhsValue
            case let (.unexpected(lhsValue), .unexpected(rhsValue)):
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
            case let .appBskyFeedDefsSkeletonReasonRepost(value):
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
            case let .appBskyFeedDefsSkeletonReasonPin(value):
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
            case let .unexpected(container):
                return try container.toCBORValue()
            }
        }
    }
}
