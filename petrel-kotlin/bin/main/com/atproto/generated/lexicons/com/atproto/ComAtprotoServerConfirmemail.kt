// Lexicon: 1, ID: com.atproto.server.confirmEmail
// Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerConfirmEmailDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.confirmEmail"
}

@Serializable
    data class ComAtprotoServerConfirmEmailInput(
        @SerialName("email")
        val email: String,        @SerialName("token")
        val token: String    )

sealed class ComAtprotoServerConfirmEmailError(val name: String, val description: String?) {
        object AccountNotFound: ComAtprotoServerConfirmEmailError("AccountNotFound", "")
        object ExpiredToken: ComAtprotoServerConfirmEmailError("ExpiredToken", "")
        object InvalidToken: ComAtprotoServerConfirmEmailError("InvalidToken", "")
        object InvalidEmail: ComAtprotoServerConfirmEmailError("InvalidEmail", "")
    }

/**
 * Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
 *
 * Endpoint: com.atproto.server.confirmEmail
 */
suspend fun ATProtoClient.Com.Atproto.Server.confirmEmail(
input: ComAtprotoServerConfirmEmailInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.confirmEmail"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
