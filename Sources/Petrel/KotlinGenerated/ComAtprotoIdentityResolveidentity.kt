// Lexicon: 1, ID: com.atproto.identity.resolveIdentity
// Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityResolveidentity {
    const val TYPE_IDENTIFIER = "com.atproto.identity.resolveIdentity"

    @Serializable
    data class Parameters(
// Handle or DID to resolve.        @SerialName("identifier")
        val identifier: ATIdentifier    )

        typealias Output = ComAtprotoIdentityDefs.Identityinfo

    sealed class Error(val name: String, val description: String?) {
        object Handlenotfound: Error("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
        object Didnotfound: Error("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object Diddeactivated: Error("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

}

/**
 * Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).
 *
 * Endpoint: com.atproto.identity.resolveIdentity
 */
suspend fun ATProtoClient.Com.Atproto.Identity.resolveidentity(
parameters: ComAtprotoIdentityResolveidentity.Parameters): ATProtoResponse<ComAtprotoIdentityResolveidentity.Output> {
    val endpoint = "com.atproto.identity.resolveIdentity"

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
