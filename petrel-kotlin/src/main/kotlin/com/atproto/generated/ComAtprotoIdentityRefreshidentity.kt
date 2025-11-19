// Lexicon: 1, ID: com.atproto.identity.refreshIdentity
// Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentityRefreshidentity {
    const val TYPE_IDENTIFIER = "com.atproto.identity.refreshIdentity"

    @Serializable
    data class Input(
        @SerialName("identifier")
        val identifier: ATIdentifier    )

        typealias Output = ComAtprotoIdentityDefs.Identityinfo

    sealed class Error(val name: String, val description: String?) {
        object Handlenotfound: Error("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
        object Didnotfound: Error("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object Diddeactivated: Error("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

}

/**
 * Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
 *
 * Endpoint: com.atproto.identity.refreshIdentity
 */
suspend fun ATProtoClient.Com.Atproto.Identity.refreshidentity(
input: ComAtprotoIdentityRefreshidentity.Input): ATProtoResponse<ComAtprotoIdentityRefreshidentity.Output> {
    val endpoint = "com.atproto.identity.refreshIdentity"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
