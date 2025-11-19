// Lexicon: 1, ID: com.atproto.server.confirmEmail
// Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerConfirmemail {
    const val TYPE_IDENTIFIER = "com.atproto.server.confirmEmail"

    @Serializable
    data class Input(
        @SerialName("email")
        val email: String,        @SerialName("token")
        val token: String    )

    sealed class Error(val name: String, val description: String?) {
        object Accountnotfound: Error("AccountNotFound", "")
        object Expiredtoken: Error("ExpiredToken", "")
        object Invalidtoken: Error("InvalidToken", "")
        object Invalidemail: Error("InvalidEmail", "")
    }

}

/**
 * Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
 *
 * Endpoint: com.atproto.server.confirmEmail
 */
suspend fun ATProtoClient.Com.Atproto.Server.confirmemail(
input: ComAtprotoServerConfirmemail.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.confirmEmail"

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
