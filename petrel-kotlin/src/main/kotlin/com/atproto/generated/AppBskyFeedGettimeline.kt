// Lexicon: 1, ID: app.bsky.feed.getTimeline
// Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGettimeline {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getTimeline"

    @Serializable
    data class Parameters(
// Variant 'algorithm' for timeline. Implementation-specific. NOTE: most feed flexibility has been moved to feed generator mechanism.        @SerialName("algorithm")
        val algorithm: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Feedviewpost>    )

}

/**
 * Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
 *
 * Endpoint: app.bsky.feed.getTimeline
 */
suspend fun ATProtoClient.App.Bsky.Feed.gettimeline(
parameters: AppBskyFeedGettimeline.Parameters): ATProtoResponse<AppBskyFeedGettimeline.Output> {
    val endpoint = "app.bsky.feed.getTimeline"

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
