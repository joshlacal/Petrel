// Lexicon: 1, ID: app.bsky.graph.getListMutes
// Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetlistmutes {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListMutes"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefs.Listview>    )

}

/**
 * Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.
 *
 * Endpoint: app.bsky.graph.getListMutes
 */
suspend fun ATProtoClient.App.Bsky.Graph.getlistmutes(
parameters: AppBskyGraphGetlistmutes.Parameters): ATProtoResponse<AppBskyGraphGetlistmutes.Output> {
    val endpoint = "app.bsky.graph.getListMutes"

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
