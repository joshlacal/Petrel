// Lexicon: 1, ID: app.bsky.feed.getTimeline
// Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetTimelineDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getTimeline"
}

@Serializable
    data class AppBskyFeedGetTimelineParameters(
// Variant 'algorithm' for timeline. Implementation-specific. NOTE: most feed flexibility has been moved to feed generator mechanism.        @SerialName("algorithm")
        val algorithm: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetTimelineOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsFeedViewPost>    )

/**
 * Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.
 *
 * Endpoint: app.bsky.feed.getTimeline
 */
suspend fun ATProtoClient.App.Bsky.Feed.getTimeline(
parameters: AppBskyFeedGetTimelineParameters): ATProtoResponse<AppBskyFeedGetTimelineOutput> {
    val endpoint = "app.bsky.feed.getTimeline"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
