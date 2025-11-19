// Lexicon: 1, ID: com.atproto.identity.resolveDid
// Resolves DID to DID document. Does not bi-directionally verify handle.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityResolvedid {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveDid"

    @Serializable
    data class Parameters(
// DID to resolve.        @SerialName("did")
        val did: DID    )

        @Serializable
    data class Output(
// The complete DID document for the identity.        @SerialName("didDoc")
        val didDoc: JsonElement    )

    sealed class Error(val name: String, val description: String?) {
        object Didnotfound: Error("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object Diddeactivated: Error("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

}

/**
 * Resolves DID to DID document. Does not bi-directionally verify handle.
 *
 * Endpoint: com.atproto.identity.resolveDid
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolvedid(
parameters: ComAtprotoIdentityResolvedid.Parameters): ATProtoResponse<ComAtprotoIdentityResolvedid.Output> {
    val endpoint = "com.atproto.identity.resolveDid"

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
