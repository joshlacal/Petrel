// Lexicon: 1, ID: com.atproto.server.resetPassword
// Reset a user account password using a token.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerResetPasswordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.resetPassword"
}

@Serializable
    data class ComAtprotoServerResetPasswordInput(
        @SerialName("token")
        val token: String,        @SerialName("password")
        val password: String    )

sealed class ComAtprotoServerResetPasswordError(val name: String, val description: String?) {
        object ExpiredToken: ComAtprotoServerResetPasswordError("ExpiredToken", "")
        object InvalidToken: ComAtprotoServerResetPasswordError("InvalidToken", "")
    }

/**
 * Reset a user account password using a token.
 *
 * Endpoint: com.atproto.server.resetPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.resetPassword(
input: ComAtprotoServerResetPasswordInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.resetPassword"

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
