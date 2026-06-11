// Lexicon: 1, ID: com.atproto.identity.refreshIdentity
// Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityRefreshIdentityDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.refreshIdentity"
}

@Serializable
    data class ComAtprotoIdentityRefreshIdentityInput(
        @SerialName("identifier")
        val identifier: ATIdentifier    )

    typealias ComAtprotoIdentityRefreshIdentityOutput = ComAtprotoIdentityDefsIdentityInfo

sealed class ComAtprotoIdentityRefreshIdentityError(val name: String, val description: String?) {
        object HandleNotFound: ComAtprotoIdentityRefreshIdentityError("HandleNotFound", "The resolution process confirmed that the handle does not resolve to any DID.")
        object DidNotFound: ComAtprotoIdentityRefreshIdentityError("DidNotFound", "The DID resolution process confirmed that there is no current DID.")
        object DidDeactivated: ComAtprotoIdentityRefreshIdentityError("DidDeactivated", "The DID previously existed, but has been deactivated.")
    }

/**
 * Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.
 *
 * Endpoint: com.atproto.identity.refreshIdentity
 */
suspend fun ATProtoClient.Com.Atproto.Identity.refreshIdentity(
input: ComAtprotoIdentityRefreshIdentityInput): ATProtoResponse<ComAtprotoIdentityRefreshIdentityOutput> {
    val endpoint = "com.atproto.identity.refreshIdentity"

    // JSON serialization
    val body = Json.encodeToString(input)
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
