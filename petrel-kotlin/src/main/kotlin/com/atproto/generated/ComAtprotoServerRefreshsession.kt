// Lexicon: 1, ID: com.atproto.server.refreshSession
// Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerRefreshsession {
    const val TYPE_IDENTIFIER = "com.atproto.server.refreshSession"

        @Serializable
    data class Output(
        @SerialName("accessJwt")
        val accessJwt: String,        @SerialName("refreshJwt")
        val refreshJwt: String,        @SerialName("handle")
        val handle: Handle,        @SerialName("did")
        val did: DID,        @SerialName("didDoc")
        val didDoc: JsonElement? = null,        @SerialName("active")
        val active: Boolean? = null,// Hosting status of the account. If not specified, then assume 'active'.        @SerialName("status")
        val status: String? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Accounttakedown: Error("AccountTakedown", "")
    }

}

/**
 * Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
 *
 * Endpoint: com.atproto.server.refreshSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.refreshsession(
): ATProtoResponse<ComAtprotoServerRefreshsession.Output> {
    val endpoint = "com.atproto.server.refreshSession"

    val body: String? = null
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
