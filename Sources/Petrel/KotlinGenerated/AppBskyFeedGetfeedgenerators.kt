// Lexicon: 1, ID: app.bsky.feed.getFeedGenerators
// Get information about a list of feed generators.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetfeedgenerators {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerators"

    @Serializable
    data class Parameters(
        @SerialName("feeds")
        val feeds: List<ATProtocolURI>    )

        @Serializable
    data class Output(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>    )

}

/**
 * Get information about a list of feed generators.
 *
 * Endpoint: app.bsky.feed.getFeedGenerators
 */
suspend fun ATProtoClient.App.Bsky.Feed.getfeedgenerators(
parameters: AppBskyFeedGetfeedgenerators.Parameters): ATProtoResponse<AppBskyFeedGetfeedgenerators.Output> {
    val endpoint = "app.bsky.feed.getFeedGenerators"

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
