// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedFeeds
// Get a list of suggested feeds
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestedfeeds {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedFeeds"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>    )

}

/**
 * Get a list of suggested feeds
 *
 * Endpoint: app.bsky.unspecced.getSuggestedFeeds
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestedfeeds(
parameters: AppBskyUnspeccedGetsuggestedfeeds.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestedfeeds.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestedFeeds"

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
