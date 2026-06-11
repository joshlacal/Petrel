// Lexicon: 1, ID: com.atproto.server.getServiceAuth
// Get a signed token on behalf of the requesting DID for the requested service.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerGetServiceAuthDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.getServiceAuth"
}

@Serializable
    data class ComAtprotoServerGetServiceAuthParameters(
// The DID or `did#serviceId` reference of the service that the token will be used to authenticate with.        @SerialName("aud")
        val aud: String,// The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.        @SerialName("exp")
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

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
