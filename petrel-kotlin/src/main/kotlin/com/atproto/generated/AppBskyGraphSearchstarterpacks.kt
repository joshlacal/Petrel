// Lexicon: 1, ID: app.bsky.graph.searchStarterPacks
// Find starter packs matching search criteria. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphSearchstarterpacks {
    const val TYPE_IDENTIFIER = "app.bsky.graph.searchStarterPacks"

    @Serializable
    data class Parameters(
// Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefs.Starterpackviewbasic>    )

}

/**
 * Find starter packs matching search criteria. Does not require auth.
 *
 * Endpoint: app.bsky.graph.searchStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.searchstarterpacks(
parameters: AppBskyGraphSearchstarterpacks.Parameters): ATProtoResponse<AppBskyGraphSearchstarterpacks.Output> {
    val endpoint = "app.bsky.graph.searchStarterPacks"

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
