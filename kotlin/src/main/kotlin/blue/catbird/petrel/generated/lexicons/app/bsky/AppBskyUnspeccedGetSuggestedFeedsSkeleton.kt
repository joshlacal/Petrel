// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedFeedsSkeleton
// Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedFeedsSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedFeedsSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsSkeletonOutput(
        @SerialName("feeds")
        val feeds: List<ATProtocolURI>    )

/**
 * Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds
 *
 * Endpoint: app.bsky.unspecced.getSuggestedFeedsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedFeedsSkeleton(
parameters: AppBskyUnspeccedGetSuggestedFeedsSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedFeedsSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedFeedsSkeleton"

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
