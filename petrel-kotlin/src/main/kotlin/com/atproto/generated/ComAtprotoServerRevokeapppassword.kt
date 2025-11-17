// Lexicon: 1, ID: com.atproto.server.revokeAppPassword
// Revoke an App Password by name.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerRevokeapppassword {
    const val TYPE_IDENTIFIER = "com.atproto.server.revokeAppPassword"

    @Serializable
    data class Input(
        @SerialName("name")
        val name: String    )

}

/**
 * Revoke an App Password by name.
 *
 * Endpoint: com.atproto.server.revokeAppPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.revokeapppassword(
input: ComAtprotoServerRevokeapppassword.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.revokeAppPassword"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
