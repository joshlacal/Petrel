// Lexicon: 1, ID: app.bsky.feed.like
// Record declaring a 'like' of a piece of subject content.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedLikeDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.like"
}

    /**
     * Record declaring a 'like' of a piece of subject content.
     */
    @Serializable
    data class AppBskyFeedLike(
        @SerialName("subject")
        val subject: ComAtprotoRepoStrongRef,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("via")
        val via: ComAtprotoRepoStrongRef? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
