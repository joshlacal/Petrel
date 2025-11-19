// Lexicon: 1, ID: app.bsky.graph.getMutes
// Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetmutes {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getMutes"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("mutes")
        val mutes: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
 *
 * Endpoint: app.bsky.graph.getMutes
 */
suspend fun ATProtoClient.App.Bsky.Graph.getmutes(
parameters: AppBskyGraphGetmutes.Parameters): ATProtoResponse<AppBskyGraphGetmutes.Output> {
    val endpoint = "app.bsky.graph.getMutes"

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
