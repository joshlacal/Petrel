// Lexicon: 1, ID: app.bsky.bookmark.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface BookmarkviewItemUnion {
    @Serializable
    @SerialName("AppBskyFeedDefs.Blockedpost")
    data class Blockedpost(val value: AppBskyFeedDefs.Blockedpost) : BookmarkviewItemUnion

    @Serializable
    @SerialName("AppBskyFeedDefs.Notfoundpost")
    data class Notfoundpost(val value: AppBskyFeedDefs.Notfoundpost) : BookmarkviewItemUnion

    @Serializable
    @SerialName("AppBskyFeedDefs.Postview")
    data class Postview(val value: AppBskyFeedDefs.Postview) : BookmarkviewItemUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : BookmarkviewItemUnion
}

object AppBskyBookmarkDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.defs"

        /**
     * Object used to store bookmark data in stash.
     */
    @Serializable
    data class Bookmark(
/** A strong ref to the record to be bookmarked. Currently, only `app.bsky.feed.post` records are supported. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongref    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#bookmark"
        }
    }

    @Serializable
    data class Bookmarkview(
/** A strong ref to the bookmarked record. */        @SerialName("subject")
        val subject: ComAtprotoRepoStrongref,        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,        @SerialName("item")
        val item: BookmarkviewItemUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#bookmarkview"
        }
    }

}
