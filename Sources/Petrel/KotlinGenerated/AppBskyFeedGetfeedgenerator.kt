// Lexicon: 1, ID: app.bsky.feed.getFeedGenerator
// Get information about a feed generator. Implemented by AppView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetfeedgenerator {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerator"

    @Serializable
    data class Parameters(
// AT-URI of the feed generator record.        @SerialName("feed")
        val feed: ATProtocolURI    )

        @Serializable
    data class Output(
        @SerialName("view")
        val view: AppBskyFeedDefs.Generatorview,// Indicates whether the feed generator service has been online recently, or else seems to be inactive.        @SerialName("isOnline")
        val isOnline: Boolean,// Indicates whether the feed generator service is compatible with the record declaration.        @SerialName("isValid")
        val isValid: Boolean    )

}

/**
 * Get information about a feed generator. Implemented by AppView.
 *
 * Endpoint: app.bsky.feed.getFeedGenerator
 */
suspend fun ATProtoClient.App.Bsky.Feed.getfeedgenerator(
parameters: AppBskyFeedGetfeedgenerator.Parameters): ATProtoResponse<AppBskyFeedGetfeedgenerator.Output> {
    val endpoint = "app.bsky.feed.getFeedGenerator"

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
