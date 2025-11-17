// Lexicon: 1, ID: com.atproto.server.updateEmail
// Update an account's email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerUpdateemail {
    const val TYPE_IDENTIFIER = "com.atproto.server.updateEmail"

    @Serializable
    data class Input(
        @SerialName("email")
        val email: String,        @SerialName("emailAuthFactor")
        val emailAuthFactor: Boolean? = null,// Requires a token from com.atproto.sever.requestEmailUpdate if the account's email has been confirmed.        @SerialName("token")
        val token: String? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Expiredtoken: Error("ExpiredToken", "")
        object Invalidtoken: Error("InvalidToken", "")
        object Tokenrequired: Error("TokenRequired", "")
    }

}

/**
 * Update an account's email.
 *
 * Endpoint: com.atproto.server.updateEmail
 */
suspend fun ATProtoClient.Com.Atproto.Server.updateemail(
input: ComAtprotoServerUpdateemail.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.updateEmail"

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
