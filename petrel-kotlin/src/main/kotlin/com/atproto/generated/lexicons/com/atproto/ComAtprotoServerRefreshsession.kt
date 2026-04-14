// Lexicon: 1, ID: com.atproto.server.refreshSession
// Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerRefreshSessionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.refreshSession"
}

    @Serializable
    data class ComAtprotoServerRefreshSessionOutput(
        @SerialName("accessJwt")
        val accessJwt: String,        @SerialName("refreshJwt")
        val refreshJwt: String,        @SerialName("handle")
        val handle: Handle,        @SerialName("did")
        val did: DID,        @SerialName("didDoc")
        val didDoc: JsonElement? = null,        @SerialName("email")
        val email: String? = null,        @SerialName("emailConfirmed")
        val emailConfirmed: Boolean? = null,        @SerialName("emailAuthFactor")
        val emailAuthFactor: Boolean? = null,        @SerialName("active")
        val active: Boolean? = null,// Hosting status of the account. If not specified, then assume 'active'.        @SerialName("status")
        val status: String? = null    )

sealed class ComAtprotoServerRefreshSessionError(val name: String, val description: String?) {
        object AccountTakedown: ComAtprotoServerRefreshSessionError("AccountTakedown", "")
        object InvalidToken: ComAtprotoServerRefreshSessionError("InvalidToken", "")
        object ExpiredToken: ComAtprotoServerRefreshSessionError("ExpiredToken", "")
    }

/**
 * Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
 *
 * Endpoint: com.atproto.server.refreshSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.refreshSession(
): ATProtoResponse<ComAtprotoServerRefreshSessionOutput> {
    val endpoint = "com.atproto.server.refreshSession"

    val body: String? = null
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
