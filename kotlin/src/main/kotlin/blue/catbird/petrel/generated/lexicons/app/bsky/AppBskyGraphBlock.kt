// Lexicon: 1, ID: app.bsky.graph.block
// Record declaring a 'block' relationship against another account. NOTE: blocks are public in Bluesky; see blog posts for details.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphBlockDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.block"
}

    /**
     * Record declaring a 'block' relationship against another account. NOTE: blocks are public in Bluesky; see blog posts for details.
     */
    @Serializable
    data class AppBskyGraphBlock(
/** DID of the account to be blocked. */        @SerialName("subject")
        val subject: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
