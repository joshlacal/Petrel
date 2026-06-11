// Lexicon: 1, ID: app.bsky.feed.getFeedGenerators
// Get information about a list of feed generators.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedGeneratorsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerators"
}

@Serializable
    data class AppBskyFeedGetFeedGeneratorsParameters(
        @SerialName("feeds")
        val feeds: List<ATProtocolURI>    )

    @Serializable
    data class AppBskyFeedGetFeedGeneratorsOutput(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get information about a list of feed generators.
 *
 * Endpoint: app.bsky.feed.getFeedGenerators
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeedGenerators(
parameters: AppBskyFeedGetFeedGeneratorsParameters): ATProtoResponse<AppBskyFeedGetFeedGeneratorsOutput> {
    val endpoint = "app.bsky.feed.getFeedGenerators"

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
