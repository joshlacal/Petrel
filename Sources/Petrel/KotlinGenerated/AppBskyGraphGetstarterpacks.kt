// Lexicon: 1, ID: app.bsky.graph.getStarterPacks
// Get views for a list of starter packs.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetstarterpacks {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPacks"

    @Serializable
    data class Parameters(
        @SerialName("uris")
        val uris: List<ATProtocolURI>    )

        @Serializable
    data class Output(
        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefs.Starterpackviewbasic>    )

}

/**
 * Get views for a list of starter packs.
 *
 * Endpoint: app.bsky.graph.getStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getstarterpacks(
parameters: AppBskyGraphGetstarterpacks.Parameters): ATProtoResponse<AppBskyGraphGetstarterpacks.Output> {
    val endpoint = "app.bsky.graph.getStarterPacks"

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
