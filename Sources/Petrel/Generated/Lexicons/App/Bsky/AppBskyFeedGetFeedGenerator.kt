// Lexicon: 1, ID: app.bsky.feed.getFeedGenerator
// Get information about a feed generator. Implemented by AppView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedGeneratorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerator"
}

@Serializable
    data class AppBskyFeedGetFeedGeneratorParameters(
// AT-URI of the feed generator record.        @SerialName("feed")
        val feed: ATProtocolURI    )

    @Serializable
    data class AppBskyFeedGetFeedGeneratorOutput(
        @SerialName("view")
        val view: AppBskyFeedDefsGeneratorView,// Indicates whether the feed generator service has been online recently, or else seems to be inactive.        @SerialName("isOnline")
        val isOnline: Boolean,// Indicates whether the feed generator service is compatible with the record declaration.        @SerialName("isValid")
        val isValid: Boolean    )

/**
 * Get information about a feed generator. Implemented by AppView.
 *
 * Endpoint: app.bsky.feed.getFeedGenerator
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeedGenerator(
parameters: AppBskyFeedGetFeedGeneratorParameters): ATProtoResponse<AppBskyFeedGetFeedGeneratorOutput> {
    val endpoint = "app.bsky.feed.getFeedGenerator"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
