// Lexicon: 1, ID: com.atproto.server.getServiceAuth
// Get a signed token on behalf of the requesting DID for the requested service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoServerGetServiceAuthDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.getServiceAuth"
}

@Serializable
    data class ComAtprotoServerGetServiceAuthParameters(
// The DID of the service that the token will be used to authenticate with        @SerialName("aud")
        val aud: DID,// The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.        @SerialName("exp")
        val exp: Int? = null,// Lexicon (XRPC) method to bind the requested token to        @SerialName("lxm")
        val lxm: NSID? = null    )

    @Serializable
    data class ComAtprotoServerGetServiceAuthOutput(
        @SerialName("token")
        val token: String    )

sealed class ComAtprotoServerGetServiceAuthError(val name: String, val description: String?) {
        object BadExpiration: ComAtprotoServerGetServiceAuthError("BadExpiration", "Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes.")
    }

/**
 * Get a signed token on behalf of the requesting DID for the requested service.
 *
 * Endpoint: com.atproto.server.getServiceAuth
 */
suspend fun ATProtoClient.Com.Atproto.Server.getServiceAuth(
parameters: ComAtprotoServerGetServiceAuthParameters): ATProtoResponse<ComAtprotoServerGetServiceAuthOutput> {
    val endpoint = "com.atproto.server.getServiceAuth"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
