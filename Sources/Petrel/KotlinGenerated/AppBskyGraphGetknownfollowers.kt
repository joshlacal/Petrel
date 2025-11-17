// Lexicon: 1, ID: app.bsky.graph.getKnownFollowers
// Enumerates accounts which follow a specified account (actor) and are followed by the viewer.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetknownfollowers {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getKnownFollowers"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("subject")
        val subject: AppBskyActorDefs.Profileview,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("followers")
        val followers: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Enumerates accounts which follow a specified account (actor) and are followed by the viewer.
 *
 * Endpoint: app.bsky.graph.getKnownFollowers
 */
suspend fun ATProtoClient.App.Bsky.Graph.getknownfollowers(
parameters: AppBskyGraphGetknownfollowers.Parameters): ATProtoResponse<AppBskyGraphGetknownfollowers.Output> {
    val endpoint = "app.bsky.graph.getKnownFollowers"

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
