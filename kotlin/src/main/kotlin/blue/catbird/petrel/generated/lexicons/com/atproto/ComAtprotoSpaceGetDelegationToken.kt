// Lexicon: 1, ID: com.atproto.space.getDelegationToken
// Mint a delegation token for a space, proving the requesting app is acting on the user's behalf. Exchanged with the space authority for a space credential. Served by the requesting user's PDS. Requires OAuth auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceGetDelegationTokenDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.getDelegationToken"
}

@Serializable
    data class ComAtprotoSpaceGetDelegationTokenParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef    )

    @Serializable
    data class ComAtprotoSpaceGetDelegationTokenOutput(
// A signed JWT delegation token.        @SerialName("token")
        val token: String    )

/**
 * Mint a delegation token for a space, proving the requesting app is acting on the user's behalf. Exchanged with the space authority for a space credential. Served by the requesting user's PDS. Requires OAuth auth.
 *
 * Endpoint: com.atproto.space.getDelegationToken
 */
suspend fun ATProtoClient.Com.Atproto.Space.getDelegationToken(
parameters: ComAtprotoSpaceGetDelegationTokenParameters): ATProtoResponse<ComAtprotoSpaceGetDelegationTokenOutput> {
    val endpoint = "com.atproto.space.getDelegationToken"

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
