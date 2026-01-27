// Lexicon: 1, ID: app.bsky.bookmark.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyBookmarkDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.defs"
}

@Serializable
sealed interface AppBskyBookmarkDefsBookmarkViewItemUnion {
    @Serializable
    @SerialName("app.bsky.bookmark.defs#AppBskyFeedDefsBlockedPost")
    data class AppBskyFeedDefsBlockedPost(val value: AppBskyFeedDefsBlockedPost) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    @SerialName("app.bsky.bookmark.defs#AppBskyFeedDefsNotFoundPost")
    data class AppBskyFeedDefsNotFoundPost(val value: AppBskyFeedDefsNotFoundPost) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    @SerialName("app.bsky.bookmark.defs#AppBskyFeedDefsPostView")
    data class AppBskyFeedDefsPostView(val value: AppBskyFeedDefsPostView) : AppBskyBookmarkDefsBookmarkViewItemUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyBookmarkDefsBookmarkViewItemUnion
}

    /**
     * Object used to store bookmark data in stash.
     */
    @Serializable
    data class AppBskyBookmarkDefsBookmark(
/** A strong ref to the record to be bookmarked. Currently, only `app.bsky.feed.post` records are supported. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyBookmarkDefsBookmark"
        }
    }

    @Serializable
    data class AppBskyBookmarkDefsBookmarkView(
/** A strong ref to the bookmarked record. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("item")
        val item: AppBskyBookmarkDefsBookmarkViewItemUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyBookmarkDefsBookmarkView"
        }
    }
