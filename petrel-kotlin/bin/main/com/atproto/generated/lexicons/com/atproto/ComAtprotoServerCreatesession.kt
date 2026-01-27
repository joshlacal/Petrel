// Lexicon: 1, ID: com.atproto.server.createSession
// Create an authentication session.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerCreateSessionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.createSession"
}

@Serializable
    data class ComAtprotoServerCreateSessionInput(
// Handle or other identifier supported by the server for the authenticating user.        @SerialName("identifier")
        val identifier: String,        @SerialName("password")
        val password: String,        @SerialName("authFactorToken")
        val authFactorToken: String? = null,// When true, instead of throwing error for takendown accounts, a valid response with a narrow scoped token will be returned        @SerialName("allowTakendown")
        val allowTakendown: Boolean? = null    )

    @Serializable
    data class ComAtprotoServerCreateSessionOutput(
        @SerialName("accessJwt")
        val accessJwt: String,        @SerialName("refreshJwt")
        val refreshJwt: String,        @SerialName("handle")
        val handle: Handle,        @SerialName("did")
        val did: DID,        @SerialName("didDoc")
        val didDoc: JsonElement? = null,        @SerialName("email")
        val email: String? = null,        @SerialName("emailConfirmed")
        val emailConfirmed: Boolean? = null,        @SerialName("emailAuthFactor")
        val emailAuthFactor: Boolean? = null,        @SerialName("active")
        val active: Boolean? = null,// If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.        @SerialName("status")
        val status: String? = null    )

sealed class ComAtprotoServerCreateSessionError(val name: String, val description: String?) {
        object AccountTakedown: ComAtprotoServerCreateSessionError("AccountTakedown", "")
        object AuthFactorTokenRequired: ComAtprotoServerCreateSessionError("AuthFactorTokenRequired", "")
    }

/**
 * Create an authentication session.
 *
 * Endpoint: com.atproto.server.createSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.createSession(
input: ComAtprotoServerCreateSessionInput): ATProtoResponse<ComAtprotoServerCreateSessionOutput> {
    val endpoint = "com.atproto.server.createSession"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
