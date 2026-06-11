// Lexicon: 1, ID: app.bsky.feed.repost
// Record representing a 'repost' of an existing Bluesky post.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
