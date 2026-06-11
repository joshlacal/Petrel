// Lexicon: 1, ID: app.bsky.feed.getActorFeeds
// Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetActorFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getActorFeeds"
}

@Serializable
    data class AppBskyFeedGetActorFeedsParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetActorFeedsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of feeds (feed generator records) created by the actor (in the actor's repo).
 *
 * Endpoint: app.bsky.feed.getActorFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getActorFeeds(
parameters: AppBskyFeedGetActorFeedsParameters): ATProtoResponse<AppBskyFeedGetActorFeedsOutput> {
    val endpoint = "app.bsky.feed.getActorFeeds"

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
