// Lexicon: 1, ID: app.bsky.graph.unmuteActor
// Unmutes the specified account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphUnmuteactor {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteActor"

    @Serializable
    data class Input(
        @SerialName("actor")
        val actor: ATIdentifier    )

}

/**
 * Unmutes the specified account. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmuteactor(
input: AppBskyGraphUnmuteactor.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteActor"

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
