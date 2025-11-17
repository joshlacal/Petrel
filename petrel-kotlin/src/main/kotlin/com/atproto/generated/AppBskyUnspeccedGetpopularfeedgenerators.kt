// Lexicon: 1, ID: app.bsky.unspecced.getPopularFeedGenerators
// An unspecced view of globally popular feed generators.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetpopularfeedgenerators {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPopularFeedGenerators"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("query")
        val query: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefs.Generatorview>    )

}

/**
 * An unspecced view of globally popular feed generators.
 *
 * Endpoint: app.bsky.unspecced.getPopularFeedGenerators
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getpopularfeedgenerators(
parameters: AppBskyUnspeccedGetpopularfeedgenerators.Parameters): ATProtoResponse<AppBskyUnspeccedGetpopularfeedgenerators.Output> {
    val endpoint = "app.bsky.unspecced.getPopularFeedGenerators"

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
