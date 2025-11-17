// Lexicon: 1, ID: app.bsky.graph.getListBlocks
// Get mod lists that the requesting account (actor) is blocking. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetlistblocks {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListBlocks"

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
 * Get mod lists that the requesting account (actor) is blocking. Requires auth.
 *
 * Endpoint: app.bsky.graph.getListBlocks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getlistblocks(
parameters: AppBskyGraphGetlistblocks.Parameters): ATProtoResponse<AppBskyGraphGetlistblocks.Output> {
    val endpoint = "app.bsky.graph.getListBlocks"

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
