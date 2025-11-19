// Lexicon: 1, ID: app.bsky.feed.getListFeed
// Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetlistfeed {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getListFeed"

    @Serializable
    data class Parameters(
// Reference (AT-URI) to the list record.        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Feedviewpost>    )

    sealed class Error(val name: String, val description: String?) {
        object Unknownlist: Error("UnknownList", "")
    }

}

/**
 * Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.
 *
 * Endpoint: app.bsky.feed.getListFeed
 */
suspend fun ATProtoClient.App.Bsky.Feed.getlistfeed(
parameters: AppBskyFeedGetlistfeed.Parameters): ATProtoResponse<AppBskyFeedGetlistfeed.Output> {
    val endpoint = "app.bsky.feed.getListFeed"

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
