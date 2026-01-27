// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedFeeds
// Get a list of suggested feeds
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedFeedsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedFeeds"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsParameters(
        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsOutput(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get a list of suggested feeds
 *
 * Endpoint: app.bsky.unspecced.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedFeeds(
parameters: AppBskyUnspeccedGetSuggestedFeedsParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedFeedsOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedFeeds"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
