// Lexicon: 1, ID: com.atproto.temp.revokeAccountCredentials
// Revoke sessions, password, and app passwords associated with account. May be resolved by a password reset.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempRevokeAccountCredentialsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.revokeAccountCredentials"
}

@Serializable
    data class ComAtprotoTempRevokeAccountCredentialsInput(
        @SerialName("account")
        val account: ATIdentifier    )

/**
 * Revoke sessions, password, and app passwords associated with account. May be resolved by a password reset.
 *
 * Endpoint: com.atproto.temp.revokeAccountCredentials
 */
suspend fun ATProtoClient.Com.Atproto.Temp.revokeAccountCredentials(
input: ComAtprotoTempRevokeAccountCredentialsInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.temp.revokeAccountCredentials"

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
