// Lexicon: 1, ID: com.atproto.server.requestPasswordReset
// Initiate a user account password reset via email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerRequestpasswordreset {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestPasswordReset"

    @Serializable
    data class Input(
        @SerialName("email")
        val email: String    )

}

/**
 * Initiate a user account password reset via email.
 *
 * Endpoint: com.atproto.server.requestPasswordReset
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestpasswordreset(
input: ComAtprotoServerRequestpasswordreset.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestPasswordReset"

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
