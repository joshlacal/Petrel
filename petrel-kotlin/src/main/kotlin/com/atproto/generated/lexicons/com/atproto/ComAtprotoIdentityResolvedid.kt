// Lexicon: 1, ID: com.atproto.identity.resolveDid
// Resolves DID to DID document. Does not bi-directionally verify handle.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityResolveDidDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveDid"
}

@Serializable
    data class ComAtprotoIdentityResolveDidParameters(
// DID to resolve.        @SerialName("did")
        val did: DID    )

    @Serializable
    data class ComAtprotoIdentityResolveDidOutput(
// The complete DID document for the identity.        @SerialName("didDoc")
        val didDoc: JsonElement    )

sealed class ComAtprotoIdentityResolveDidError(val name: String, val description: String?) {
        object DidNotFound: ComAtprotoIdentityResolveDidError("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object DidDeactivated: ComAtprotoIdentityResolveDidError("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

/**
 * Resolves DID to DID document. Does not bi-directionally verify handle.
 *
 * Endpoint: com.atproto.identity.resolveDid
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolveDid(
parameters: ComAtprotoIdentityResolveDidParameters): ATProtoResponse<ComAtprotoIdentityResolveDidOutput> {
    val endpoint = "com.atproto.identity.resolveDid"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
