// Lexicon: 1, ID: app.bsky.feed.like
// Record declaring a 'like' of a piece of subject content.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
