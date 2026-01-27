// Lexicon: 1, ID: com.atproto.server.deleteAccount
// Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerDeleteAccountDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.deleteAccount"
}

@Serializable
    data class ComAtprotoServerDeleteAccountInput(
        @SerialName("did")
        val did: DID,        @SerialName("password")
        val password: String,        @SerialName("token")
        val token: String    )

sealed class ComAtprotoServerDeleteAccountError(val name: String, val description: String?) {
        object ExpiredToken: ComAtprotoServerDeleteAccountError("ExpiredToken", "")
        object InvalidToken: ComAtprotoServerDeleteAccountError("InvalidToken", "")
    }

/**
 * Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.
 *
 * Endpoint: com.atproto.server.deleteAccount
 */
suspend fun ATProtoClient.Com.Atproto.Server.deleteAccount(
input: ComAtprotoServerDeleteAccountInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deleteAccount"

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
