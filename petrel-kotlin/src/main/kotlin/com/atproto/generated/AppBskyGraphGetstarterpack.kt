// Lexicon: 1, ID: app.bsky.graph.getStarterPack
// Gets a view of a starter pack.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetstarterpack {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPack"

    @Serializable
    data class Parameters(
// Reference (AT-URI) of the starter pack record.        @SerialName("starterPack")
        val starterPack: ATProtocolURI    )

        @Serializable
    data class Output(
        @SerialName("starterPack")
        val starterPack: AppBskyGraphDefs.Starterpackview    )

}

/**
 * Gets a view of a starter pack.
 *
 * Endpoint: app.bsky.graph.getStarterPack
 */
suspend fun ATProtoClient.App.Bsky.Graph.getstarterpack(
parameters: AppBskyGraphGetstarterpack.Parameters): ATProtoResponse<AppBskyGraphGetstarterpack.Output> {
    val endpoint = "app.bsky.graph.getStarterPack"

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
