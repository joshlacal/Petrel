// Lexicon: 1, ID: app.bsky.feed.getSuggestedFeeds
// Get a list of suggested feeds (feed generators) for the requesting account.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetSuggestedFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getSuggestedFeeds"
}

@Serializable
    data class AppBskyFeedGetSuggestedFeedsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetSuggestedFeedsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of suggested feeds (feed generators) for the requesting account.
 *
 * Endpoint: app.bsky.feed.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getSuggestedFeeds(
parameters: AppBskyFeedGetSuggestedFeedsParameters): ATProtoResponse<AppBskyFeedGetSuggestedFeedsOutput> {
    val endpoint = "app.bsky.feed.getSuggestedFeeds"

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
