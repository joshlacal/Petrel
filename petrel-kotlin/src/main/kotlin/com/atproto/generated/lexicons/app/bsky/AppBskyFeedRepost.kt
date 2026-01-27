// Lexicon: 1, ID: app.bsky.feed.repost
// Record representing a 'repost' of an existing Bluesky post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedRepostDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.repost"
}

    /**
     * Record representing a 'repost' of an existing Bluesky post.
     */
    @Serializable
    data class AppBskyFeedRepost(
        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("via")
        val via: ComAtprotoRepoStrongRef? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
