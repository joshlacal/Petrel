// Lexicon: 1, ID: com.atproto.server.resetPassword
// Reset a user account password using a token.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerResetpassword {
    const val TYPE_IDENTIFIER = "com.atproto.server.resetPassword"

    @Serializable
    data class Input(
        @SerialName("token")
        val token: String,        @SerialName("password")
        val password: String    )

    sealed class Error(val name: String, val description: String?) {
        object Expiredtoken: Error("ExpiredToken", "")
        object Invalidtoken: Error("InvalidToken", "")
    }

}

/**
 * Reset a user account password using a token.
 *
 * Endpoint: com.atproto.server.resetPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.resetpassword(
input: ComAtprotoServerResetpassword.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.resetPassword"

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
