// Lexicon: 1, ID: app.bsky.feed.getSuggestedFeeds
// Get a list of suggested feeds (feed generators) for the requesting account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetsuggestedfeeds {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getSuggestedFeeds"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>    )

}

/**
 * Get a list of suggested feeds (feed generators) for the requesting account.
 *
 * Endpoint: app.bsky.feed.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getsuggestedfeeds(
parameters: AppBskyFeedGetsuggestedfeeds.Parameters): ATProtoResponse<AppBskyFeedGetsuggestedfeeds.Output> {
    val endpoint = "app.bsky.feed.getSuggestedFeeds"

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
