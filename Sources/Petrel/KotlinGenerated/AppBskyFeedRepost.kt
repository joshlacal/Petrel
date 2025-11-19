// Lexicon: 1, ID: app.bsky.feed.repost
// Record representing a 'repost' of an existing Bluesky post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedRepost {
    const val TYPE_IDENTIFIER = "app.bsky.feed.repost"

        /**
     * Record representing a 'repost' of an existing Bluesky post.
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
