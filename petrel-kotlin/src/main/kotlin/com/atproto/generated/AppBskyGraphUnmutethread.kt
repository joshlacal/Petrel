// Lexicon: 1, ID: app.bsky.graph.unmuteThread
// Unmutes the specified thread. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphUnmutethread {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteThread"

    @Serializable
    data class Input(
        @SerialName("root")
        val root: ATProtocolURI    )

}

/**
 * Unmutes the specified thread. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteThread
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmutethread(
input: AppBskyGraphUnmutethread.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteThread"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
