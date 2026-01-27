// Lexicon: 1, ID: com.atproto.identity.resolveHandle
// Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityResolveHandleDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveHandle"
}

@Serializable
    data class ComAtprotoIdentityResolveHandleParameters(
// The handle to resolve.        @SerialName("handle")
        val handle: Handle    )

    @Serializable
    data class ComAtprotoIdentityResolveHandleOutput(
        @SerialName("did")
        val did: DID    )

sealed class ComAtprotoIdentityResolveHandleError(val name: String, val description: String?) {
        object HandleNotFound: ComAtprotoIdentityResolveHandleError("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
    }

/**
 * Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
 *
 * Endpoint: com.atproto.identity.resolveHandle
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolveHandle(
parameters: ComAtprotoIdentityResolveHandleParameters): ATProtoResponse<ComAtprotoIdentityResolveHandleOutput> {
    val endpoint = "com.atproto.identity.resolveHandle"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
