// Lexicon: 1, ID: app.bsky.feed.getSuggestedFeeds
// Get a list of suggested feeds (feed generators) for the requesting account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetSuggestedFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getSuggestedFeeds"
}

@Serializable
    data class AppBskyFeedGetSuggestedFeedsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetSuggestedFeedsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of suggested feeds (feed generators) for the requesting account.
 *
 * Endpoint: app.bsky.feed.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Feed.getSuggestedFeeds(
parameters: AppBskyFeedGetSuggestedFeedsParameters): ATProtoResponse<AppBskyFeedGetSuggestedFeedsOutput> {
    val endpoint = "app.bsky.feed.getSuggestedFeeds"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
