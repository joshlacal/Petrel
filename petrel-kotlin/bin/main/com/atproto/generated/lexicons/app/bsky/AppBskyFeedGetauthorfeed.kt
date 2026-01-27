// Lexicon: 1, ID: app.bsky.feed.getAuthorFeed
// Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
