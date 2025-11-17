// Lexicon: 1, ID: com.atproto.server.getServiceAuth
// Get a signed token on behalf of the requesting DID for the requested service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerGetserviceauth {
    const val TYPE_IDENTIFIER = "com.atproto.server.getServiceAuth"

    @Serializable
    data class Parameters(
// The DID of the service that the token will be used to authenticate with        @SerialName("aud")
        val aud: DID,// The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.        @SerialName("exp")
        val exp: Int? = null,// Lexicon (XRPC) method to bind the requested token to        @SerialName("lxm")
        val lxm: NSID? = null    )

        @Serializable
    data class Output(
        @SerialName("token")
        val token: String    )

    sealed class Error(val name: String, val description: String?) {
        object Badexpiration: Error("BadExpiration", "Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes.")
    }

}

/**
 * Get a signed token on behalf of the requesting DID for the requested service.
 *
 * Endpoint: com.atproto.server.getServiceAuth
 */
suspend fun ATProtoClient.Com.Atproto.Server.getserviceauth(
parameters: ComAtprotoServerGetserviceauth.Parameters): ATProtoResponse<ComAtprotoServerGetserviceauth.Output> {
    val endpoint = "com.atproto.server.getServiceAuth"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
