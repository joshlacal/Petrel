// Lexicon: 1, ID: app.bsky.feed.getTimeline
// Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetTimelineDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getTimeline"
}

@Serializable
    data class AppBskyFeedGetTimelineParameters(
// Variant 'algorithm' for timeline. Implementation-specific. NOTE: most feed flexibility has been moved to feed generator mechanism.        @SerialName("algorithm")
        val algorithm: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetTimelineOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

/**
 * Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
 *
 * Endpoint: app.bsky.feed.getTimeline
 */
suspend fun ATProtoClient.App.Bsky.Feed.getTimeline(
parameters: AppBskyFeedGetTimelineParameters): ATProtoResponse<AppBskyFeedGetTimelineOutput> {
    val endpoint = "app.bsky.feed.getTimeline"

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
