// Lexicon: 1, ID: app.bsky.feed.getListFeed
// Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetListFeedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getListFeed"
}

@Serializable
    data class AppBskyFeedGetListFeedParameters(
// Reference (AT-URI) to the list record.        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetListFeedOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

sealed class AppBskyFeedGetListFeedError(val name: String, val description: String?) {
        object UnknownList: AppBskyFeedGetListFeedError("UnknownList", "")
    }

/**
 * Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
 *
 * Endpoint: app.bsky.feed.getListFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getListFeed(
parameters: AppBskyFeedGetListFeedParameters): ATProtoResponse<AppBskyFeedGetListFeedOutput> {
    val endpoint = "app.bsky.feed.getListFeed"

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
