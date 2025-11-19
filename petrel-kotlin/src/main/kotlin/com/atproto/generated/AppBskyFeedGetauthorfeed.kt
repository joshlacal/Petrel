// Lexicon: 1, ID: app.bsky.feed.getAuthorFeed
// Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetauthorfeed {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getAuthorFeed"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// Combinations of post/repost types to include in response.        @SerialName("filter")
        val filter: String? = null,        @SerialName("includePins")
        val includePins: Boolean? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Feedviewpost>    )

    sealed class Error(val name: String, val description: String?) {
        object Blockedactor: Error("BlockedActor", "")
        object Blockedbyactor: Error("BlockedByActor", "")
    }

}

/**
 * Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.
 *
 * Endpoint: app.bsky.feed.getAuthorFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getauthorfeed(
parameters: AppBskyFeedGetauthorfeed.Parameters): ATProtoResponse<AppBskyFeedGetauthorfeed.Output> {
    val endpoint = "app.bsky.feed.getAuthorFeed"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
