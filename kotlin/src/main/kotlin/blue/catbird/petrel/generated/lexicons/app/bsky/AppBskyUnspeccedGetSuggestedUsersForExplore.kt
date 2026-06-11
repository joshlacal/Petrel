// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsersForExplore
// Get a list of suggested users for the Explore page
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedUsersForExploreDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsersForExplore"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForExploreParameters(
// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForExploreOutput(
        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileView>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recIdStr")
        val recIdStr: String? = null    )

/**
 * Get a list of suggested users for the Explore page
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsersForExplore
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedUsersForExplore(
parameters: AppBskyUnspeccedGetSuggestedUsersForExploreParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedUsersForExploreOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsersForExplore"

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
