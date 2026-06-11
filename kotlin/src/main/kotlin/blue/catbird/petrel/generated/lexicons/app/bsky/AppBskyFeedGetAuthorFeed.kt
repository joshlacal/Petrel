// Lexicon: 1, ID: app.bsky.feed.getAuthorFeed
// Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetAuthorFeedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getAuthorFeed"
}

@Serializable
    data class AppBskyFeedGetAuthorFeedParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Combinations of post/repost types to include in response.        @SerialName("filter")
        val filter: String? = null,        @SerialName("includePins")
        val includePins: Boolean? = null    )

    @Serializable
    data class AppBskyFeedGetAuthorFeedOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

sealed class AppBskyFeedGetAuthorFeedError(val name: String, val description: String?) {
        object BlockedActor: AppBskyFeedGetAuthorFeedError("BlockedActor", "")
        object BlockedByActor: AppBskyFeedGetAuthorFeedError("BlockedByActor", "")
    }

/**
 * Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
 *
 * Endpoint: app.bsky.feed.getAuthorFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getAuthorFeed(
parameters: AppBskyFeedGetAuthorFeedParameters): ATProtoResponse<AppBskyFeedGetAuthorFeedOutput> {
    val endpoint = "app.bsky.feed.getAuthorFeed"

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
