// Lexicon: 1, ID: app.bsky.feed.getActorLikes
// Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetActorLikesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getActorLikes"
}

@Serializable
    data class AppBskyFeedGetActorLikesParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetActorLikesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

sealed class AppBskyFeedGetActorLikesError(val name: String, val description: String?) {
        object BlockedActor: AppBskyFeedGetActorLikesError("BlockedActor", "")
        object BlockedByActor: AppBskyFeedGetActorLikesError("BlockedByActor", "")
    }

/**
 * Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
 *
 * Endpoint: app.bsky.feed.getActorLikes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getActorLikes(
parameters: AppBskyFeedGetActorLikesParameters): ATProtoResponse<AppBskyFeedGetActorLikesOutput> {
    val endpoint = "app.bsky.feed.getActorLikes"

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
