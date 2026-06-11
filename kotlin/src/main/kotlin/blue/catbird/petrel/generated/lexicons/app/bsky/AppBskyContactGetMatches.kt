// Lexicon: 1, ID: app.bsky.contact.getMatches
// Returns the matched contacts (contacts that were mutually imported). Excludes dismissed matches. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyContactGetMatchesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.getMatches"
}

@Serializable
    data class AppBskyContactGetMatchesParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyContactGetMatchesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("matches")
        val matches: List<AppBskyActorDefsProfileView>    )

sealed class AppBskyContactGetMatchesError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactGetMatchesError("InvalidDid", "")
        object InvalidLimit: AppBskyContactGetMatchesError("InvalidLimit", "")
        object InvalidCursor: AppBskyContactGetMatchesError("InvalidCursor", "")
        object InternalError: AppBskyContactGetMatchesError("InternalError", "")
    }

/**
 * Returns the matched contacts (contacts that were mutually imported). Excludes dismissed matches. Requires authentication.
 *
 * Endpoint: app.bsky.contact.getMatches
 */
suspend fun ATProtoClient.App.Bsky.Contact.getMatches(
parameters: AppBskyContactGetMatchesParameters): ATProtoResponse<AppBskyContactGetMatchesOutput> {
    val endpoint = "app.bsky.contact.getMatches"

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
