// Lexicon: 1, ID: com.atproto.server.requestPasswordReset
// Initiate a user account password reset via email.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerRequestPasswordResetDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestPasswordReset"
}

@Serializable
    data class ComAtprotoServerRequestPasswordResetInput(
        @SerialName("email")
        val email: String    )

/**
 * Initiate a user account password reset via email.
 *
 * Endpoint: com.atproto.server.requestPasswordReset
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestPasswordReset(
input: ComAtprotoServerRequestPasswordResetInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestPasswordReset"

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
