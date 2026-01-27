// Lexicon: 1, ID: app.bsky.feed.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.defs"
}

@Serializable
sealed interface AppBskyFeedDefsPostViewEmbedUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyEmbedImagesView")
    data class AppBskyEmbedImagesView(val value: AppBskyEmbedImagesView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyEmbedVideoView")
    data class AppBskyEmbedVideoView(val value: AppBskyEmbedVideoView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyEmbedExternalView")
    data class AppBskyEmbedExternalView(val value: AppBskyEmbedExternalView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyEmbedRecordView")
    data class AppBskyEmbedRecordView(val value: AppBskyEmbedRecordView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyEmbedRecordWithMediaView")
    data class AppBskyEmbedRecordWithMediaView(val value: AppBskyEmbedRecordWithMediaView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsPostViewEmbedUnion
}

@Serializable
sealed interface AppBskyFeedDefsFeedViewPostReasonUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsReasonRepost")
    data class AppBskyFeedDefsReasonRepost(val value: AppBskyFeedDefsReasonRepost) : AppBskyFeedDefsFeedViewPostReasonUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsReasonPin")
    data class AppBskyFeedDefsReasonPin(val value: AppBskyFeedDefsReasonPin) : AppBskyFeedDefsFeedViewPostReasonUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsFeedViewPostReasonUnion
}

@Serializable
sealed interface AppBskyFeedDefsReplyRefRootUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsPostView")
    data class AppBskyFeedDefsPostView(val value: AppBskyFeedDefsPostView) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsReplyRefRootUnion
}

@Serializable
sealed interface AppBskyFeedDefsReplyRefParentUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsPostView")
    data class AppBskyFeedDefsPostView(val value: AppBskyFeedDefsPostView) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsReplyRefParentUnion
}

@Serializable
sealed interface AppBskyFeedDefsThreadViewPostParentUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsThreadViewPost")
    data class AppBskyFeedDefsThreadViewPost(val value: AppBskyFeedDefsThreadViewPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsThreadViewPostParentUnion
}

@Serializable
sealed interface AppBskyFeedDefsThreadViewPostRepliesUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsThreadViewPost")
    data class AppBskyFeedDefsThreadViewPost(val value: AppBskyFeedDefsThreadViewPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsThreadViewPostRepliesUnion
}

@Serializable
sealed interface AppBskyFeedDefsSkeletonFeedPostReasonUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsSkeletonReasonRepost")
    data class AppBskyFeedDefsSkeletonReasonRepost(val value: AppBskyFeedDefsSkeletonReasonRepost) : AppBskyFeedDefsSkeletonFeedPostReasonUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#AppBskyFeedDefsSkeletonReasonPin")
    data class AppBskyFeedDefsSkeletonReasonPin(val value: AppBskyFeedDefsSkeletonReasonPin) : AppBskyFeedDefsSkeletonFeedPostReasonUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsSkeletonFeedPostReasonUnion
}

    @Serializable
    data class AppBskyFeedDefsPostView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("embed")
        val embed: AppBskyFeedDefsPostViewEmbedUnion?,        @SerialName("bookmarkCount")
        val bookmarkCount: Int?,        @SerialName("replyCount")
        val replyCount: Int?,        @SerialName("repostCount")
        val repostCount: Int?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("quoteCount")
        val quoteCount: Int?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("viewer")
        val viewer: AppBskyFeedDefsViewerState?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefsThreadgateView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsPostView"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject content. Only has meaningful content for authed requests.
     */
    @Serializable
    data class AppBskyFeedDefsViewerState(
        @SerialName("repost")
        val repost: ATProtocolURI?,        @SerialName("like")
        val like: ATProtocolURI?,        @SerialName("bookmarked")
        val bookmarked: Boolean?,        @SerialName("threadMuted")
        val threadMuted: Boolean?,        @SerialName("replyDisabled")
        val replyDisabled: Boolean?,        @SerialName("embeddingDisabled")
        val embeddingDisabled: Boolean?,        @SerialName("pinned")
        val pinned: Boolean?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsViewerState"
        }
    }

    /**
     * Metadata about this post within the context of the thread it is in.
     */
    @Serializable
    data class AppBskyFeedDefsThreadContext(
        @SerialName("rootAuthorLike")
        val rootAuthorLike: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadContext"
        }
    }

    @Serializable
    data class AppBskyFeedDefsFeedViewPost(
        @SerialName("post")
        val post: AppBskyFeedDefsPostView,        @SerialName("reply")
        val reply: AppBskyFeedDefsReplyRef?,        @SerialName("reason")
        val reason: AppBskyFeedDefsFeedViewPostReasonUnion?,/** Context provided by feed generator that may be passed back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String?,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsFeedViewPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsReplyRef(
        @SerialName("root")
        val root: AppBskyFeedDefsReplyRefRootUnion,        @SerialName("parent")
        val parent: AppBskyFeedDefsReplyRefParentUnion,/** When parent is a reply to another post, this is the author of that post. */        @SerialName("grandparentAuthor")
        val grandparentAuthor: AppBskyActorDefsProfileViewBasic?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReplyRef"
        }
    }

    @Serializable
    data class AppBskyFeedDefsReasonRepost(
        @SerialName("by")
        val `by`: AppBskyActorDefsProfileViewBasic,        @SerialName("uri")
        val uri: ATProtocolURI?,        @SerialName("cid")
        val cid: CID?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReasonRepost"
        }
    }

    @Serializable
    class AppBskyFeedDefsReasonPin {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReasonPin"
        }
    }

    @Serializable
    data class AppBskyFeedDefsThreadViewPost(
        @SerialName("post")
        val post: AppBskyFeedDefsPostView,        @SerialName("parent")
        val parent: AppBskyFeedDefsThreadViewPostParentUnion?,        @SerialName("replies")
        val replies: List<AppBskyFeedDefsThreadViewPostRepliesUnion>?,        @SerialName("threadContext")
        val threadContext: AppBskyFeedDefsThreadContext?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadViewPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsNotFoundPost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsNotFoundPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsBlockedPost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: AppBskyFeedDefsBlockedAuthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsBlockedPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsBlockedAuthor(
        @SerialName("did")
        val did: DID,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsBlockedAuthor"
        }
    }

    @Serializable
    data class AppBskyFeedDefsGeneratorView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("did")
        val did: DID,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileView,        @SerialName("displayName")
        val displayName: String,        @SerialName("description")
        val description: String?,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>?,        @SerialName("avatar")
        val avatar: URI?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("acceptsInteractions")
        val acceptsInteractions: Boolean?,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("viewer")
        val viewer: AppBskyFeedDefsGeneratorViewerState?,        @SerialName("contentMode")
        val contentMode: String?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsGeneratorView"
        }
    }

    @Serializable
    data class AppBskyFeedDefsGeneratorViewerState(
        @SerialName("like")
        val like: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsGeneratorViewerState"
        }
    }

    @Serializable
    data class AppBskyFeedDefsSkeletonFeedPost(
        @SerialName("post")
        val post: ATProtocolURI,        @SerialName("reason")
        val reason: AppBskyFeedDefsSkeletonFeedPostReasonUnion?,/** Context that will be passed through to client and may be passed to feed generator back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonFeedPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsSkeletonReasonRepost(
        @SerialName("repost")
        val repost: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonReasonRepost"
        }
    }

    @Serializable
    class AppBskyFeedDefsSkeletonReasonPin {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonReasonPin"
        }
    }

    @Serializable
    data class AppBskyFeedDefsThreadgateView(
        @SerialName("uri")
        val uri: ATProtocolURI?,        @SerialName("cid")
        val cid: CID?,        @SerialName("record")
        val record: JsonElement?,        @SerialName("lists")
        val lists: List<AppBskyGraphDefsListViewBasic>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadgateView"
        }
    }

    @Serializable
    data class AppBskyFeedDefsInteraction(
        @SerialName("item")
        val item: ATProtocolURI?,        @SerialName("event")
        val event: String?,/** Context on a feed item that was originally supplied by the feed generator on getFeedSkeleton. */        @SerialName("feedContext")
        val feedContext: String?,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsInteraction"
        }
    }
