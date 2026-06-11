// Lexicon: 1, ID: com.atproto.identity.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.defs"
}

    @Serializable
    data class ComAtprotoIdentityDefsIdentityInfo(
        @SerialName("did")
        val did: DID,/** The validated handle of the account; or 'handle.invalid' if the handle did not bi-directionally match the DID document. */        @SerialName("handle")
        val handle: Handle,/** The complete DID document for the identity. */        @SerialName("didDoc")
        val didDoc: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoIdentityDefsIdentityInfo"
        }
    }
