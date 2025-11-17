// Lexicon: 1, ID: app.bsky.feed.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface PostviewEmbedUnion {
    @Serializable
    @SerialName("AppBskyEmbedImages.View")
    data class View(val value: AppBskyEmbedImages.View) : PostviewEmbedUnion

    @Serializable
    @SerialName("AppBskyEmbedVideo.View")
    data class View(val value: AppBskyEmbedVideo.View) : PostviewEmbedUnion

    @Serializable
    @SerialName("AppBskyEmbedExternal.View")
    data class View(val value: AppBskyEmbedExternal.View) : PostviewEmbedUnion

    @Serializable
    @SerialName("AppBskyEmbedRecord.View")
    data class View(val value: AppBskyEmbedRecord.View) : PostviewEmbedUnion

    @Serializable
    @SerialName("AppBskyEmbedRecordwithmedia.View")
    data class View(val value: AppBskyEmbedRecordwithmedia.View) : PostviewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PostviewEmbedUnion
}

@Serializable
sealed interface FeedviewpostReasonUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Reasonrepost")
    data class Reasonrepost(val value: Reasonrepost) : FeedviewpostReasonUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Reasonpin")
    data class Reasonpin(val value: Reasonpin) : FeedviewpostReasonUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : FeedviewpostReasonUnion
}

@Serializable
sealed interface ReplyrefRootUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Postview")
    data class Postview(val value: Postview) : ReplyrefRootUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Notfoundpost")
    data class Notfoundpost(val value: Notfoundpost) : ReplyrefRootUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Blockedpost")
    data class Blockedpost(val value: Blockedpost) : ReplyrefRootUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ReplyrefRootUnion
}

@Serializable
sealed interface ReplyrefParentUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Postview")
    data class Postview(val value: Postview) : ReplyrefParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Notfoundpost")
    data class Notfoundpost(val value: Notfoundpost) : ReplyrefParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Blockedpost")
    data class Blockedpost(val value: Blockedpost) : ReplyrefParentUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ReplyrefParentUnion
}

@Serializable
sealed interface ThreadviewpostParentUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Threadviewpost")
    data class Threadviewpost(val value: Threadviewpost) : ThreadviewpostParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Notfoundpost")
    data class Notfoundpost(val value: Notfoundpost) : ThreadviewpostParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Blockedpost")
    data class Blockedpost(val value: Blockedpost) : ThreadviewpostParentUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ThreadviewpostParentUnion
}

@Serializable
sealed interface ThreadviewpostRepliesUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Threadviewpost")
    data class Threadviewpost(val value: Threadviewpost) : ThreadviewpostRepliesUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Notfoundpost")
    data class Notfoundpost(val value: Notfoundpost) : ThreadviewpostRepliesUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Blockedpost")
    data class Blockedpost(val value: Blockedpost) : ThreadviewpostRepliesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ThreadviewpostRepliesUnion
}

@Serializable
sealed interface SkeletonfeedpostReasonUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#Skeletonreasonrepost")
    data class Skeletonreasonrepost(val value: Skeletonreasonrepost) : SkeletonfeedpostReasonUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#Skeletonreasonpin")
    data class Skeletonreasonpin(val value: Skeletonreasonpin) : SkeletonfeedpostReasonUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : SkeletonfeedpostReasonUnion
}

object AppBskyFeedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.defs"

        @Serializable
    data class Postview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefs.Profileviewbasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("embed")
        val embed: PostviewEmbedUnion?,        @SerialName("bookmarkCount")
        val bookmarkCount: Int?,        @SerialName("replyCount")
        val replyCount: Int?,        @SerialName("repostCount")
        val repostCount: Int?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("quoteCount")
        val quoteCount: Int?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("viewer")
        val viewer: Viewerstate?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("threadgate")
        val threadgate: Threadgateview?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#postview"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject content. Only has meaningful content for authed requests.
     */
    @Serializable
    data class Viewerstate(
        @SerialName("repost")
        val repost: ATProtocolURI?,        @SerialName("like")
        val like: ATProtocolURI?,        @SerialName("bookmarked")
        val bookmarked: Boolean?,        @SerialName("threadMuted")
        val threadMuted: Boolean?,        @SerialName("replyDisabled")
        val replyDisabled: Boolean?,        @SerialName("embeddingDisabled")
        val embeddingDisabled: Boolean?,        @SerialName("pinned")
        val pinned: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewerstate"
        }
    }

    /**
     * Metadata about this post within the context of the thread it is in.
     */
    @Serializable
    data class Threadcontext(
        @SerialName("rootAuthorLike")
        val rootAuthorLike: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threadcontext"
        }
    }

    @Serializable
    data class Feedviewpost(
        @SerialName("post")
        val post: Postview,        @SerialName("reply")
        val reply: Replyref?,        @SerialName("reason")
        val reason: FeedviewpostReasonUnion?,/** Context provided by feed generator that may be passed back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String?,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#feedviewpost"
        }
    }

    @Serializable
    data class Replyref(
        @SerialName("root")
        val root: ReplyrefRootUnion,        @SerialName("parent")
        val parent: ReplyrefParentUnion,/** When parent is a reply to another post, this is the author of that post. */        @SerialName("grandparentAuthor")
        val grandparentAuthor: AppBskyActorDefs.Profileviewbasic?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#replyref"
        }
    }

    @Serializable
    data class Reasonrepost(
        @SerialName("by")
        val `by`: AppBskyActorDefs.Profileviewbasic,        @SerialName("uri")
        val uri: ATProtocolURI?,        @SerialName("cid")
        val cid: CID?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#reasonrepost"
        }
    }

    @Serializable
    data class Reasonpin(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#reasonpin"
        }
    }

    @Serializable
    data class Threadviewpost(
        @SerialName("post")
        val post: Postview,        @SerialName("parent")
        val parent: ThreadviewpostParentUnion?,        @SerialName("replies")
        val replies: List<ThreadviewpostRepliesUnion>?,        @SerialName("threadContext")
        val threadContext: Threadcontext?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threadviewpost"
        }
    }

    @Serializable
    data class Notfoundpost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#notfoundpost"
        }
    }

    @Serializable
    data class Blockedpost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: Blockedauthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blockedpost"
        }
    }

    @Serializable
    data class Blockedauthor(
        @SerialName("did")
        val did: DID,        @SerialName("viewer")
        val viewer: AppBskyActorDefs.Viewerstate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blockedauthor"
        }
    }

    @Serializable
    data class Generatorview(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("did")
        val did: DID,        @SerialName("creator")
        val creator: AppBskyActorDefs.Profileview,        @SerialName("displayName")
        val displayName: String,        @SerialName("description")
        val description: String?,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("acceptsInteractions")
        val acceptsInteractions: Boolean?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("viewer")
        val viewer: Generatorviewerstate?,        @SerialName("contentMode")
        val contentMode: String?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#generatorview"
        }
    }

    @Serializable
    data class Generatorviewerstate(
        @SerialName("like")
        val like: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#generatorviewerstate"
        }
    }

    @Serializable
    data class Skeletonfeedpost(
        @SerialName("post")
        val post: ATProtocolURI,        @SerialName("reason")
        val reason: SkeletonfeedpostReasonUnion?,/** Context that will be passed through to client and may be passed to feed generator back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonfeedpost"
        }
    }

    @Serializable
    data class Skeletonreasonrepost(
        @SerialName("repost")
        val repost: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonreasonrepost"
        }
    }

    @Serializable
    data class Skeletonreasonpin(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#skeletonreasonpin"
        }
    }

    @Serializable
    data class Threadgateview(
        @SerialName("uri")
        val uri: ATProtocolURI?,        @SerialName("cid")
        val cid: CID?,        @SerialName("record")
        val record: JsonElement?,        @SerialName("lists")
        val lists: List<AppBskyGraphDefs.Listviewbasic>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threadgateview"
        }
    }

    @Serializable
    data class Interaction(
        @SerialName("item")
        val item: ATProtocolURI?,        @SerialName("event")
        val event: String?,/** Context on a feed item that was originally supplied by the feed generator on getFeedSkeleton. */        @SerialName("feedContext")
        val feedContext: String?,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#interaction"
        }
    }

}
