// Lexicon: 1, ID: app.bsky.feed.getFeed
// Get a hydrated feed from an actor's selected feed generator. Implemented by App View.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetfeed {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeed"

    @Serializable
    data class Parameters(
        @SerialName("feed")
        val feed: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Feedviewpost>    )

    sealed class Error(val name: String, val description: String?) {
        object Unknownfeed: Error("UnknownFeed", "")
    }

}

/**
 * Get a hydrated feed from an actor's selected feed generator. Implemented by App View.
 *
 * Endpoint: app.bsky.feed.getFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getfeed(
parameters: AppBskyFeedGetfeed.Parameters): ATProtoResponse<AppBskyFeedGetfeed.Output> {
    val endpoint = "app.bsky.feed.getFeed"

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
