// Lexicon: 1, ID: com.atproto.server.getSession
// Get information about the current auth session. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerGetSessionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.getSession"
}

    @Serializable
    data class ComAtprotoServerGetSessionOutput(
        @SerialName("handle")
        val handle: Handle,        @SerialName("did")
        val did: DID,        @SerialName("email")
        val email: String? = null,        @SerialName("emailConfirmed")
        val emailConfirmed: Boolean? = null,        @SerialName("emailAuthFactor")
        val emailAuthFactor: Boolean? = null,        @SerialName("didDoc")
        val didDoc: JsonElement? = null,        @SerialName("active")
        val active: Boolean? = null,// If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.        @SerialName("status")
        val status: String? = null    )

/**
 * Get information about the current auth session. Requires auth.
 *
 * Endpoint: com.atproto.server.getSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.getSession(
): ATProtoResponse<ComAtprotoServerGetSessionOutput> {
    val endpoint = "com.atproto.server.getSession"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
