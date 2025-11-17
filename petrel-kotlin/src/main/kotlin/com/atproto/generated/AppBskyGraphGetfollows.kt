// Lexicon: 1, ID: app.bsky.graph.getFollows
// Enumerates accounts which a specified account (actor) follows.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetfollows {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getFollows"

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
        val cursor: String? = null,        @SerialName("follows")
        val follows: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Enumerates accounts which a specified account (actor) follows.
 *
 * Endpoint: app.bsky.graph.getFollows
 */
suspend fun ATProtoClient.App.Bsky.Graph.getfollows(
parameters: AppBskyGraphGetfollows.Parameters): ATProtoResponse<AppBskyGraphGetfollows.Output> {
    val endpoint = "app.bsky.graph.getFollows"

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
