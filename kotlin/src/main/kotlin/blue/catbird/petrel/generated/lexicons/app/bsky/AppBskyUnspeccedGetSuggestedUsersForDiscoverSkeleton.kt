// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton
// Get a skeleton of suggested users for the Discover page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForDiscover
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedUsersForDiscoverSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForDiscoverSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForDiscoverSkeletonOutput(
        @SerialName("dids")
        val dids: List<DID>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recIdStr")
        val recIdStr: String? = null    )

/**
 * Get a skeleton of suggested users for the Discover page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForDiscover
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedUsersForDiscoverSkeleton(
parameters: AppBskyUnspeccedGetSuggestedUsersForDiscoverSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedUsersForDiscoverSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton"

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
