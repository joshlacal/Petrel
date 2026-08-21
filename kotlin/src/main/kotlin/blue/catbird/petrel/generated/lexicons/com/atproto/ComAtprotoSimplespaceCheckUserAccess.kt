// Lexicon: 1, ID: com.atproto.simplespace.checkUserAccess
// Ask a space's managing app whether to authorize a requesting user for a space credential. Served by the managingApp (not the PDS), called by the space authority at mint time when policy is 'managing-app'. Authenticated with service auth from the authority.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceCheckUserAccessDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.checkUserAccess"
}

@Serializable
    data class ComAtprotoSimplespaceCheckUserAccessParameters(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The DID of the requesting user.        @SerialName("user")
        val user: DID,// The attested client_id, if a client attestation was presented.        @SerialName("clientId")
        val clientId: String? = null    )

    @Serializable
    data class ComAtprotoSimplespaceCheckUserAccessOutput(
// Whether the managing app authorizes the request.        @SerialName("authorized")
        val authorized: Boolean    )

/**
 * Ask a space's managing app whether to authorize a requesting user for a space credential. Served by the managingApp (not the PDS), called by the space authority at mint time when policy is 'managing-app'. Authenticated with service auth from the authority.
 *
 * Endpoint: com.atproto.simplespace.checkUserAccess
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.checkUserAccess(
parameters: ComAtprotoSimplespaceCheckUserAccessParameters): ATProtoResponse<ComAtprotoSimplespaceCheckUserAccessOutput> {
    val endpoint = "com.atproto.simplespace.checkUserAccess"

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
