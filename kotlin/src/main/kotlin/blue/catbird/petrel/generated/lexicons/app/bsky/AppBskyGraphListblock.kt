// Lexicon: 1, ID: app.bsky.graph.listblock
// Record representing a block relationship against an entire an entire list of accounts (actors).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphListblockDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.listblock"
}

    /**
     * Record representing a block relationship against an entire an entire list of accounts (actors).
     */
    @Serializable
    data class AppBskyGraphListblock(
/** Reference (AT-URI) to the mod list record. */        @SerialName("subject")
        val subject: ATProtocolURI,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
