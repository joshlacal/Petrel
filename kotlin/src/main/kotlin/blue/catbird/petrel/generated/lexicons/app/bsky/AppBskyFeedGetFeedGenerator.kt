// Lexicon: 1, ID: app.bsky.feed.getFeedGenerator
// Get information about a feed generator. Implemented by AppView.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedGeneratorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerator"
}

@Serializable
    data class AppBskyFeedGetFeedGeneratorParameters(
// AT-URI of the feed generator record.        @SerialName("feed")
        val feed: ATProtocolURI    )

    @Serializable
    data class AppBskyFeedGetFeedGeneratorOutput(
        @SerialName("view")
        val view: AppBskyFeedDefsGeneratorView,// Indicates whether the feed generator service has been online recently, or else seems to be inactive.        @SerialName("isOnline")
        val isOnline: Boolean,// Indicates whether the feed generator service is compatible with the record declaration.        @SerialName("isValid")
        val isValid: Boolean    )

/**
 * Get information about a feed generator. Implemented by AppView.
 *
 * Endpoint: app.bsky.feed.getFeedGenerator
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeedGenerator(
parameters: AppBskyFeedGetFeedGeneratorParameters): ATProtoResponse<AppBskyFeedGetFeedGeneratorOutput> {
    val endpoint = "app.bsky.feed.getFeedGenerator"

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
