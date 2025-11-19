// Lexicon: 1, ID: app.bsky.graph.getBlocks
// Enumerates which accounts the requesting account is currently blocking. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetblocks {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getBlocks"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blocks")
        val blocks: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Enumerates which accounts the requesting account is currently blocking. Requires auth.
 *
 * Endpoint: app.bsky.graph.getBlocks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getblocks(
parameters: AppBskyGraphGetblocks.Parameters): ATProtoResponse<AppBskyGraphGetblocks.Output> {
    val endpoint = "app.bsky.graph.getBlocks"

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
