// Lexicon: 1, ID: app.bsky.graph.getActorStarterPacks
// Get a list of starter packs created by the actor.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetactorstarterpacks {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getActorStarterPacks"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefs.Starterpackviewbasic>    )

}

/**
 * Get a list of starter packs created by the actor.
 *
 * Endpoint: app.bsky.graph.getActorStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getactorstarterpacks(
parameters: AppBskyGraphGetactorstarterpacks.Parameters): ATProtoResponse<AppBskyGraphGetactorstarterpacks.Output> {
    val endpoint = "app.bsky.graph.getActorStarterPacks"

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
