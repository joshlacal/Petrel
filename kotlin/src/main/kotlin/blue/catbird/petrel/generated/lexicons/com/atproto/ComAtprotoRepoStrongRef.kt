// Lexicon: 1, ID: com.atproto.repo.strongRef
// A URI with a content-hash fingerprint.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoRepoStrongRefDefs {
    const val TYPE_IDENTIFIER = "com.atproto.repo.strongRef"
}

@Serializable
data class ComAtprotoRepoStrongRef(
    @SerialName("uri")
    val uri: ATProtocolURI,    @SerialName("cid")
    val cid: CID)
