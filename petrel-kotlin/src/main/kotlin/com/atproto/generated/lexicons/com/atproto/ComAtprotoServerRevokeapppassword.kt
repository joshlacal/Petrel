// Lexicon: 1, ID: com.atproto.server.revokeAppPassword
// Revoke an App Password by name.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerRevokeAppPasswordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.revokeAppPassword"
}

@Serializable
    data class ComAtprotoServerRevokeAppPasswordInput(
        @SerialName("name")
        val name: String    )

/**
 * Revoke an App Password by name.
 *
 * Endpoint: com.atproto.server.revokeAppPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.revokeAppPassword(
input: ComAtprotoServerRevokeAppPasswordInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.revokeAppPassword"

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
