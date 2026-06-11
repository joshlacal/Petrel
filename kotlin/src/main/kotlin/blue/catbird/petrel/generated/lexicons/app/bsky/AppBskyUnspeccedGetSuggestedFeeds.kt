// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedFeeds
// Get a list of suggested feeds
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedFeeds"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsParameters(
        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsOutput(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of suggested feeds
 *
 * Endpoint: app.bsky.unspecced.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedFeeds(
parameters: AppBskyUnspeccedGetSuggestedFeedsParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedFeedsOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedFeeds"

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
