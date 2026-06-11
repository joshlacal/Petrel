// Lexicon: 1, ID: app.bsky.graph.follow
// Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphFollowDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.follow"
}

    /**
     * Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
     */
    @Serializable
    data class AppBskyGraphFollow(
        @SerialName("subject")
        val subject: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("via")
        val via: ComAtprotoRepoStrongRef? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
