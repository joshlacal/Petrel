// Lexicon: 1, ID: com.atproto.identity.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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
