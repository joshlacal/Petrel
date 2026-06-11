// Lexicon: 1, ID: app.bsky.graph.listitem
// Record representing an account's inclusion on a specific list. The AppView will ignore duplicate listitem records.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphListitemDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.listitem"
}

    /**
     * Record representing an account's inclusion on a specific list. The AppView will ignore duplicate listitem records.
     */
    @Serializable
    data class AppBskyGraphListitem(
/** The account which is included on the list. */        @SerialName("subject")
        val subject: DID,/** Reference (AT-URI) to the list record (app.bsky.graph.list). */        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
