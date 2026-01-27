// Lexicon: 1, ID: app.bsky.feed.getActorLikes
// Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
