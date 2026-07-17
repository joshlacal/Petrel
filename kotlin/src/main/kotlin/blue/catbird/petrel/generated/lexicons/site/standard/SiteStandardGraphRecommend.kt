// Lexicon: 1, ID: site.standard.graph.recommend
// Record declaring a recommendation of a document.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object SiteStandardGraphRecommendDefs {
    const val TYPE_IDENTIFIER = "site.standard.graph.recommend"
}

    /**
     * Record declaring a recommendation of a document.
     */
    @Serializable
    data class SiteStandardGraphRecommend(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** AT-URI reference to the document record being recommended (ex: at://did:plc:abc123/site.standard.document/xyz789). */        @SerialName("document")
        val document: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
