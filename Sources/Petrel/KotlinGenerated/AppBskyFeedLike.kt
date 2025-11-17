// Lexicon: 1, ID: app.bsky.feed.like
// Record declaring a 'like' of a piece of subject content.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedLike {
    const val TYPE_IDENTIFIER = "app.bsky.feed.like"

        /**
     * Record declaring a 'like' of a piece of subject content.
     */
    @Serializable
    data class Record(
        @SerialName("subject")
        val subject: ComAtprotoRepoStrongref,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("via")
        val via: ComAtprotoRepoStrongref? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
