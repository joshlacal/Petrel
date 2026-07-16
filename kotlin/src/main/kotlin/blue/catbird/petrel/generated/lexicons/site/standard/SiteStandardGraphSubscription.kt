// Lexicon: 1, ID: site.standard.graph.subscription
// Record declaring a subscription to a publication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardGraphSubscriptionDefs {
    const val TYPE_IDENTIFIER = "site.standard.graph.subscription"
}

    /**
     * Record declaring a subscription to a publication.
     */
    @Serializable
    data class SiteStandardGraphSubscription(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate? = null,/** AT-URI reference to the publication record being subscribed to (ex: at://did:plc:abc123/site.standard.publication/xyz789). */        @SerialName("publication")
        val publication: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
