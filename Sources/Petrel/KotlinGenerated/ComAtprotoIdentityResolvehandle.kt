// Lexicon: 1, ID: com.atproto.identity.resolveHandle
// Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityResolvehandle {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveHandle"

    @Serializable
    data class Parameters(
// The handle to resolve.        @SerialName("handle")
        val handle: Handle    )

        @Serializable
    data class Output(
        @SerialName("did")
        val did: DID    )

    sealed class Error(val name: String, val description: String?) {
        object Handlenotfound: Error("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
    }

}

/**
 * Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.
 *
 * Endpoint: com.atproto.identity.resolveHandle
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolvehandle(
parameters: ComAtprotoIdentityResolvehandle.Parameters): ATProtoResponse<ComAtprotoIdentityResolvehandle.Output> {
    val endpoint = "com.atproto.identity.resolveHandle"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
